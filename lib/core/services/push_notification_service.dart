import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Required by firebase_messaging. When the app is background/terminated,
  // the system tray shows the push on its own.
  debugPrint('bg fcm: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService(this._client);

  final SupabaseClient _client;

  final _fcm = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'likewise_default',
    'Likewise',
    description: 'General notifications',
    importance: Importance.high,
  );

  bool _initialized = false;

  /// Call once from `main.dart` after `Firebase.initializeApp()`.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
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

  void _onForegroundMessage(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    _local.show(
      message.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: message.data.isEmpty ? null : message.data.toString(),
    );
  }
}
