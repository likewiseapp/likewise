import 'dart:io';
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Channels ──────────────────────────────────────────────────────────────
// Defined at top-level so the background handler (separate isolate) can
// reference them too.

const AndroidNotificationChannel _defaultChannel = AndroidNotificationChannel(
  'likewise_default',
  'Likewise',
  description: 'General notifications',
  importance: Importance.high,
);

const AndroidNotificationChannel _messagesChannel = AndroidNotificationChannel(
  'likewise_messages',
  'Messages',
  description: 'New messages from your chats',
  importance: Importance.max,
);

// ── Background handler ────────────────────────────────────────────────────
// Runs in a dedicated isolate when the app is terminated/backgrounded.
// We re-initialize FlutterLocalNotificationsPlugin here because the main
// isolate's instance isn't available.

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  final local = FlutterLocalNotificationsPlugin();
  await local.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
    ),
  );
  if (Platform.isAndroid) {
    final android = local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_messagesChannel);
  }
  await _showRichMessageNotification(local, message);
}

/// Shared renderer used by both the foreground listener and the background
/// handler. For message pushes this builds an Android MessagingStyle
/// notification — chat-bubble layout, sender avatar as the Person icon,
/// conversation title across the top. For everything else it falls back to
/// a standard BigTextStyle card.
Future<void> _showRichMessageNotification(
  FlutterLocalNotificationsPlugin local,
  RemoteMessage message,
) async {
  final data = message.data;
  final isMessage = data['type'] == 'message';

  // Title / body come from `data` (data-only push) but fall back to the
  // top-level notification fields for backwards compatibility.
  final title =
      (data['title'] as String?) ?? message.notification?.title ?? '';
  final body =
      (data['body'] as String?) ?? message.notification?.body ?? '';
  if (title.isEmpty && body.isEmpty) return;

  // Strip the 💬 emoji prefix — MessagingStyle has its own visual affordances
  // (Person avatar, conversation title) and the emoji clutters them.
  final senderName = (data['sender_name'] as String?) ??
      title.replaceFirst(RegExp(r'^💬\s*'), '');
  final senderId = data['sender_id'] as String?;

  final avatarBytes = await _downloadAvatarBytes(data['avatar_url'] as String?);
  final largeIcon =
      avatarBytes != null ? ByteArrayAndroidBitmap(avatarBytes) : null;
  final personIcon =
      avatarBytes != null ? ByteArrayAndroidIcon(avatarBytes) : null;

  final channel = isMessage ? _messagesChannel : _defaultChannel;

  StyleInformation styleInformation;
  AndroidNotificationCategory? category;

  if (isMessage) {
    // Parse the message timestamp from the server, fall back to now.
    DateTime messageTime;
    try {
      messageTime =
          DateTime.tryParse(data['sent_at'] as String? ?? '')?.toLocal() ??
              DateTime.now();
    } catch (_) {
      messageTime = DateTime.now();
    }

    final sender = Person(
      name: senderName,
      key: senderId,
      icon: personIcon,
      important: true,
    );

    styleInformation = MessagingStyleInformation(
      const Person(name: 'You', key: 'me'),
      conversationTitle: senderName,
      groupConversation: false,
      messages: [
        Message(body, messageTime, sender),
      ],
    );
    category = AndroidNotificationCategory.message;
  } else {
    styleInformation = BigTextStyleInformation(body, contentTitle: title);
  }

  await local.show(
    message.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: Priority.max,
        icon: 'ic_notification',
        color: const Color(0xFF6C63FF),
        largeIcon: largeIcon,
        tag: data['conversation_id'] as String?,
        category: category,
        subText: isMessage ? 'Likewise' : null,
        ticker: isMessage ? 'New message from $senderName' : null,
        styleInformation: styleInformation,
        visibility: NotificationVisibility.private,
      ),
    ),
    payload: data.isEmpty ? null : data.toString(),
  );
}

/// Fetches the sender avatar as raw bytes so we can wrap it in both a
/// Bitmap (for largeIcon) and an Icon (for MessagingStyle.Person).
/// Fails silently — a missing avatar is not worth blocking the notification.
Future<Uint8List?> _downloadAvatarBytes(String? url) async {
  if (url == null || url.isEmpty) return null;
  try {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final resp = await http.get(uri).timeout(const Duration(seconds: 4));
    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;
    return resp.bodyBytes;
  } catch (_) {
    return null;
  }
}

// ── Service ───────────────────────────────────────────────────────────────

class PushNotificationService {
  PushNotificationService(this._client);

  final SupabaseClient _client;

  final _fcm = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Call once from `main.dart` after `Firebase.initializeApp()`.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
    );

    if (Platform.isAndroid) {
      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_defaultChannel);
      await android?.createNotificationChannel(_messagesChannel);
    }

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    _fcm.onTokenRefresh.listen(_persistToken);
  }

  /// Call on sign-in success — registers this device's FCM token against
  /// the authenticated user.
  Future<void> registerDevice() async {
    final token = await _fcm.getToken();
    if (token == null) return;
    await _persistToken(token);
  }

  /// Call on sign-out — removes this device's token so we stop pushing to it.
  Future<void> unregisterDevice() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _client.from('user_devices').delete().eq('fcm_token', token);
      }
      await _fcm.deleteToken();
    } catch (e) {
      debugPrint('unregisterDevice: $e');
    }
  }

  Future<void> _persistToken(String token) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client.from('user_devices').upsert(
        {
          'user_id': user.id,
          'fcm_token': token,
          'device_type': Platform.isIOS ? 'ios' : 'android',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'fcm_token',
      );
    } catch (e) {
      debugPrint('persistToken: $e');
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) =>
      _showRichMessageNotification(_local, message);
}
