import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/app_cached_image.dart';
import '../../../core/models/message.dart';
import '../../../core/models/message_reaction.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/block_providers.dart';
import '../../../core/providers/message_providers.dart';
import '../../../core/services/block_service.dart';
import '../../../core/services/message_service.dart';
import '../../../core/app_theme.dart';
import '../../../core/theme_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String otherUserAvatar;
  final String otherUserId;
  final bool isRequest;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    required this.otherUserAvatar,
    this.otherUserId = '',
    this.isRequest = false,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  late bool _isRequest;

  // Capture container so we can invalidate providers safely in dispose()
  ProviderContainer? _container;

  // Typing indicator
  RealtimeChannel? _typingChannel;
  bool _otherIsTyping = false;
  Timer? _typingDebounce;
  Timer? _typingTimeout;

  /// The message the user is replying to (shown as preview above input).
  Message? _replyingTo;

  /// Locally optimistic-deleted message IDs (hide immediately on delete).
  Set<String> _deletedIds = {};

  /// Locally cached reactions map (messageId → reactions).
  Map<String, List<MessageReaction>> _reactions = {};

  /// Optimistic pending messages (local-only until confirmed via stream).
  final List<Message> _pendingMessages = [];

  @override
  void initState() {
    super.initState();
    _isRequest = widget.isRequest;
    _markRead();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Capture once — safe here unlike initState
    if (_container == null) {
      _container = ProviderScope.containerOf(context);
      _setupTypingChannel();
    }
  }

  @override
  void dispose() {
    _typingChannel?.unsubscribe();
    _typingDebounce?.cancel();
    _typingTimeout?.cancel();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _scrollController.dispose();
    // Safe: _container is a ProviderContainer, not ref
    _container?.invalidate(conversationsProvider);
    _container?.invalidate(requestConversationsProvider);
    super.dispose();
  }

  Future<void> _unblockUser() async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null || widget.otherUserId.isEmpty) return;
    final client = ref.read(supabaseProvider);
    await BlockService(client).unblockUser(currentUserId, widget.otherUserId);
    ref.invalidate(isBlockingProvider(widget.otherUserId));
  }

  void _setupTypingChannel() {
    if (widget.conversationId.isEmpty) return;
    final client = _container!.read(supabaseProvider);
    final userId = _container!.read(currentUserIdProvider);

    _typingChannel = client.channel('typing:${widget.conversationId}')
      ..onBroadcast(
        event: 'typing',
        callback: (payload) {
          final senderId = payload['user_id'] as String?;
          if (senderId == null || senderId == userId) return;
          if (!mounted) return;
          setState(() => _otherIsTyping = true);
          _typingTimeout?.cancel();
          _typingTimeout = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _otherIsTyping = false);
          });
        },
      )
      ..subscribe();
  }

  void _onControllerChanged() {
    if (_controller.text.isEmpty) return;
    _typingDebounce?.cancel();
    _typingDebounce = Timer(
      const Duration(milliseconds: 500),
      _broadcastTyping,
    );
  }

  void _broadcastTyping() {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    _typingChannel?.sendBroadcastMessage(
      event: 'typing',
      payload: {'user_id': userId},
    );
  }

  void _markRead() {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final client = ref.read(supabaseProvider);
    MessageService(client).markMessagesAsRead(widget.conversationId, userId);
  }

  Future<void> _loadReactions(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    try {
      final client = ref.read(supabaseProvider);
      final result = await MessageService(client).fetchReactions(messageIds);
      if (mounted) setState(() => _reactions = result);
    } catch (_) {
      // Reactions are non-critical — fail silently rather than crashing chat
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final replyId = _replyingTo?.id;

    setState(() {
      _sending = true;
      _replyingTo = null;
    });
    _controller.clear();
    HapticFeedback.lightImpact();

    // Create optimistic pending message with temp ID
    final tempId = 'pending_${DateTime.now().microsecondsSinceEpoch}';
    final pending = Message(
      id: tempId,
      conversationId: widget.conversationId,
      senderId: userId,
      content: text,
      createdAt: DateTime.now(),
      replyToId: replyId,
      isPending: true,
    );

    setState(() => _pendingMessages.add(pending));
    _scrollToBottom();

    try {
      final client = ref.read(supabaseProvider);
      // If this is a request conversation, accept it before sending the reply
      if (_isRequest) {
        await MessageService(client).acceptConversation(widget.conversationId);
        if (mounted) setState(() => _isRequest = false);
      }
      await MessageService(client).sendMessage(
        widget.conversationId,
        userId,
        text,
        replyToId: replyId,
      );
      // Real message will arrive via stream → pending removed in _reconcilePending
      if (mounted) setState(() => _sending = false);
    } catch (_) {
      // Mark as failed — user can tap to retry
      if (mounted) {
        setState(() {
          _sending = false;
          final idx = _pendingMessages.indexWhere((m) => m.id == tempId);
          if (idx != -1) {
            _pendingMessages[idx] = _pendingMessages[idx].copyWith(hasFailed: true);
          }
        });
      }
    }
  }

  /// Retry a failed pending message.
  Future<void> _retrySend(Message failed) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    // Reset to pending
    setState(() {
      final idx = _pendingMessages.indexWhere((m) => m.id == failed.id);
      if (idx != -1) {
        _pendingMessages[idx] = _pendingMessages[idx].copyWith(hasFailed: false);
      }
    });

    try {
      final client = ref.read(supabaseProvider);
      await MessageService(client).sendMessage(
        widget.conversationId,
        userId,
        failed.content,
        replyToId: failed.replyToId,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          final idx = _pendingMessages.indexWhere((m) => m.id == failed.id);
          if (idx != -1) {
            _pendingMessages[idx] = _pendingMessages[idx].copyWith(hasFailed: true);
          }
        });
      }
    }
  }

  /// Remove pending messages that match real streamed messages.
  void _reconcilePending(List<Message> streamed) {
    if (_pendingMessages.isEmpty) return;
    // Work on a mutable copy so each real message can only match one pending
    // message — prevents two identical rapid sends both resolving to the same
    // streamed message and leaving a ghost bubble.
    final available = streamed.toList();
    final toRemove = <String>[];
    for (final p in _pendingMessages) {
      if (p.hasFailed) continue;
      final idx = available.indexWhere((s) =>
          s.senderId == p.senderId &&
          s.content == p.content &&
          s.createdAt != null &&
          p.createdAt != null &&
          s.createdAt!.difference(p.createdAt!).inSeconds.abs() < 10);
      if (idx != -1) {
        toRemove.add(p.id);
        available.removeAt(idx); // consumed — can't match another pending
      }
    }
    if (toRemove.isNotEmpty) {
      setState(() => _pendingMessages.removeWhere((m) => toRemove.contains(m.id)));
    }
  }

  /// With reverse: true, scroll position 0 IS the bottom.
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  // ── Action handlers ──────────────────────────────────────────────────────

  void _onCopy(Message msg) {
    Clipboard.setData(ClipboardData(text: msg.content));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _onUnsend(Message msg) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final client = ref.read(supabaseProvider);
    final deleted = await MessageService(client).unsendMessage(msg.id, userId);
    if (!mounted) return;
    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message already read — cannot unsend'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onDeleteForMe(Message msg) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final client = ref.read(supabaseProvider);
    // Optimistic
    setState(() => _deletedIds = {..._deletedIds, msg.id});
    await MessageService(client).deleteMessageForMe(msg.id, userId);
  }

  void _onReply(Message msg) {
    setState(() => _replyingTo = msg);
    HapticFeedback.lightImpact();
  }

  Future<void> _onReact(Message msg, String emoji) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final client = ref.read(supabaseProvider);

    // Check if already reacted with this emoji → toggle off
    final existing = _reactions[msg.id] ?? [];
    final alreadyReacted =
        existing.any((r) => r.userId == userId && r.emoji == emoji);

    if (alreadyReacted) {
      // Optimistic remove
      setState(() {
        _reactions = {
          ..._reactions,
          msg.id: existing
              .where((r) => !(r.userId == userId && r.emoji == emoji))
              .toList(),
        };
      });
      try {
        await MessageService(client).removeReaction(msg.id, userId, emoji);
      } catch (_) {
        // Revert optimistic remove on failure
        if (mounted) setState(() => _reactions = {..._reactions, msg.id: existing});
      }
    } else {
      // Optimistic add
      final optimistic = MessageReaction(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        messageId: msg.id,
        userId: userId,
        emoji: emoji,
        createdAt: DateTime.now(),
      );
      setState(() {
        _reactions = {
          ..._reactions,
          msg.id: [...existing, optimistic],
        };
      });
      try {
        await MessageService(client).addReaction(msg.id, userId, emoji);
      } catch (_) {
        // Revert optimistic add on failure
        if (mounted) setState(() => _reactions = {..._reactions, msg.id: existing});
      }
    }

    // Refresh from server
    final allIds = _reactions.keys.toList();
    if (allIds.isNotEmpty) _loadReactions(allIds);
  }

  void _showMessageActions(Message msg, bool isMine) {
    HapticFeedback.mediumImpact();
    final colors = ref.read(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MessageActionsSheet(
        message: msg,
        isMine: isMine,
        colors: colors,
        isDark: isDark,
        onCopy: () { Navigator.pop(ctx); _onCopy(msg); },
        onReply: isMine ? null : () { Navigator.pop(ctx); _onReply(msg); },
        onUnsend: isMine && !msg.isRead ? () { Navigator.pop(ctx); _onUnsend(msg); } : null,
        onDeleteForMe: () { Navigator.pop(ctx); _onDeleteForMe(msg); },
        onReact: isMine
            ? null
            : (emoji) { Navigator.pop(ctx); _onReact(msg, emoji); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = ref.watch(currentUserIdProvider);
    final messagesAsync =
        ref.watch(messagesStreamProvider(widget.conversationId));
    final isBlockedByMe = widget.otherUserId.isNotEmpty &&
        (ref.watch(isBlockedByProvider(widget.otherUserId)).value ?? false);
    final isOtherOnline = !isBlockedByMe &&
        widget.otherUserId.isNotEmpty &&
        (ref.watch(onlineUsersProvider).value
                ?.any((u) => u.id == widget.otherUserId) ??
            false);
    final iAmBlocking = widget.otherUserId.isNotEmpty &&
        (ref.watch(isBlockingProvider(widget.otherUserId)).value ?? false);

    ref.listen(messagesStreamProvider(widget.conversationId), (prev, next) {
      if (next.hasValue) {
        _markRead();
        _reconcilePending(next.value!);
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom());
        // Refresh reactions when messages update
        final ids = next.value!.map((m) => m.id).toList();
        _loadReactions(ids);
      }
    });

    // Build merged list: streamed + pending (non-failed pending at end)
    final streamedMessages = messagesAsync.value ?? [];
    final allMessages = [...streamedMessages, ..._pendingMessages];
    final messageMap = {for (final m in allMessages) m.id: m};

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkScaffold : AppColors.lightScaffold,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          _ChatHeader(
            name: widget.otherUserName,
            avatarUrl: widget.otherUserAvatar,
            otherUserId: widget.otherUserId,
            isOtherOnline: isOtherOnline,
            isBlockedByMe: isBlockedByMe,
            colors: colors,
            isDark: isDark,
          ),

          // ── Messages ────────────────────────────────────────────────
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Text(
                  'Failed to load messages',
                  style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38),
                ),
              ),
              data: (messages) {
                // Merge streamed + pending, filter out soft-deleted
                final merged = [...messages, ..._pendingMessages];
                final visible = merged
                    .where((m) => !_deletedIds.contains(m.id))
                    .toList();

                if (visible.isEmpty) {
                  return _EmptyChat(
                    name: widget.otherUserName,
                    avatarUrl: widget.otherUserAvatar,
                    colors: colors,
                    isDark: isDark,
                  );
                }

                // Sort descending (newest first) so reverse:true puts
                // newest at the visible bottom.
                final sorted = [...visible]..sort((a, b) =>
                    (b.createdAt ?? DateTime(0))
                        .compareTo(a.createdAt ?? DateTime(0)));

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final msg = sorted[index];
                    final isMine = msg.senderId == currentUserId;

                    // Grouping
                    final isBottom = index == 0 ||
                        sorted[index - 1].senderId != msg.senderId;
                    final isTop = index == sorted.length - 1 ||
                        sorted[index + 1].senderId != msg.senderId;

                    // Date separator
                    final showDate = index == sorted.length - 1 ||
                        _differentDay(
                            msg.createdAt, sorted[index + 1].createdAt);

                    // Resolve reply-to message
                    final replyMsg = msg.replyToId != null
                        ? messageMap[msg.replyToId]
                        : null;

                    // Reactions for this message
                    final msgReactions = _reactions[msg.id] ?? [];

                    final bubble = _Bubble(
                      message: msg,
                      isMine: isMine,
                      isTop: isTop,
                      isBottom: isBottom,
                      colors: colors,
                      isDark: isDark,
                      avatarUrl: widget.otherUserAvatar,
                      isBlockedByOther: isBlockedByMe,
                      replyMessage: replyMsg,
                      hasDeletedReply:
                          msg.replyToId != null && replyMsg == null,
                      reactions: msgReactions,
                      currentUserId: currentUserId,
                      onReactionTap: (emoji) => _onReact(msg, emoji),
                      onRetry: msg.hasFailed ? () => _retrySend(msg) : null,
                    );

                    // Both mine and incoming are swipeable to reply
                    final wrappedBubble = _SwipeToReply(
                      isMine: isMine,
                      colors: colors,
                      onReply: () => _onReply(msg),
                      child: bubble,
                    );

                    return Column(
                      children: [
                        if (showDate)
                          _DateChip(date: msg.createdAt, isDark: isDark),
                        Padding(
                          padding: EdgeInsets.only(top: isTop ? 10 : 2),
                          child: GestureDetector(
                            onLongPress: () =>
                                _showMessageActions(msg, isMine),
                            child: wrappedBubble,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // ── Typing indicator ────────────────────────────────────────
          if (_otherIsTyping && !isBlockedByMe && !iAmBlocking)
            _TypingIndicator(isDark: isDark, colors: colors),

          // ── Request banner ──────────────────────────────────────────
          if (_isRequest && !isBlockedByMe && !iAmBlocking)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.primary.withValues(alpha: 0.08)
                    : colors.primary.withValues(alpha: 0.06),
                border: Border(
                  top: BorderSide(
                    color: colors.primary.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 15, color: colors.primary.withValues(alpha: 0.7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Replying will move this to your main inbox',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white54
                            : Colors.black45,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Reply preview ───────────────────────────────────────────
          if (_replyingTo != null && !isBlockedByMe && !iAmBlocking)
            _ReplyPreview(
              message: _replyingTo!,
              colors: colors,
              isDark: isDark,
              onCancel: () => setState(() => _replyingTo = null),
            ),

          // ── Input / blocked banners ──────────────────────────────────
          if (isBlockedByMe)
            // Other user blocked me
            Container(
              padding: EdgeInsets.fromLTRB(
                  20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block_rounded,
                      size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Text(
                    'You are blocked',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
          else if (iAmBlocking)
            // I blocked them
            Container(
              padding: EdgeInsets.fromLTRB(
                  20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block_rounded,
                      size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Text(
                    'You have blocked this person',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _unblockUser();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: isDark ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Unblock',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            _InputBar(
              controller: _controller,
              sending: _sending,
              colors: colors,
              isDark: isDark,
              onSend: _send,
            ),
        ],
      ),
    );
  }

  bool _differentDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return true;
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Header
// ═══════════════════════════════════════════════════════════════════════════════

class _ChatHeader extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final String otherUserId;
  final bool isOtherOnline;
  final bool isBlockedByMe;
  final AppColorScheme colors;
  final bool isDark;

  const _ChatHeader({
    required this.name,
    required this.avatarUrl,
    required this.colors,
    required this.isDark,
    this.otherUserId = '',
    this.isOtherOnline = false,
    this.isBlockedByMe = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.95),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 14, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 22,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),

                  // Tappable avatar + name → profile
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: otherUserId.isNotEmpty
                          ? () {
                              HapticFeedback.lightImpact();
                              context.push('/user/$otherUserId');
                            }
                          : null,
                      child: Row(
                        children: [
                          // Avatar — blank circle when blocked
                          if (isBlockedByMe)
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06),
                              ),
                              child: Icon(Icons.person_rounded,
                                  size: 20,
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.black26),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [colors.primary, colors.accent],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(1.5),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkScaffold
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: ClipOval(
                                  child: AppCachedImage(
                                    imageUrl: avatarUrl,
                                    width: 34,
                                    height: 34,
                                    errorWidget: Container(
                                      width: 34,
                                      height: 34,
                                      color:
                                          colors.primary.withValues(alpha: 0.15),
                                      child: Icon(Icons.person_rounded,
                                          size: 18, color: colors.primary),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 1),
                                if (isOtherOnline)
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: colors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Active now',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.white38
                                              : Colors.black38,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Empty state
// ═══════════════════════════════════════════════════════════════════════════════

class _EmptyChat extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final AppColorScheme colors;
  final bool isDark;

  const _EmptyChat({
    required this.name,
    required this.avatarUrl,
    required this.colors,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary, colors.accent],
              ),
              shape: BoxShape.circle,
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkScaffold : Colors.white,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: AppCachedImage(
                  imageUrl: avatarUrl,
                  width: 60,
                  height: 60,
                  errorWidget: Container(
                    width: 60,
                    height: 60,
                    color: colors.primary.withValues(alpha: 0.15),
                    child: Icon(Icons.person_rounded,
                        size: 30, color: colors.primary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Say hello!',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Date chip
// ═══════════════════════════════════════════════════════════════════════════════

class _DateChip extends StatelessWidget {
  final DateTime? date;
  final bool isDark;

  const _DateChip({required this.date, required this.isDark});

  String _label() {
    if (date == null) return '';
    final now = DateTime.now();
    final d = date!;
    if (now.year == d.year && now.month == d.month && now.day == d.day) {
      return 'Today';
    }
    final y = now.subtract(const Duration(days: 1));
    if (y.year == d.year && y.month == d.month && y.day == d.day) {
      return 'Yesterday';
    }
    const m = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${m[d.month]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _label(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Bubble
// ═══════════════════════════════════════════════════════════════════════════════

class _Bubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final bool isTop;
  final bool isBottom;
  final AppColorScheme colors;
  final bool isDark;
  final String avatarUrl;
  final bool isBlockedByOther;
  final Message? replyMessage;
  final bool hasDeletedReply;
  final List<MessageReaction> reactions;
  final String? currentUserId;
  final void Function(String emoji)? onReactionTap;
  final VoidCallback? onRetry;

  const _Bubble({
    required this.message,
    required this.isMine,
    required this.isTop,
    required this.isBottom,
    required this.colors,
    required this.isDark,
    required this.avatarUrl,
    this.isBlockedByOther = false,
    this.replyMessage,
    this.hasDeletedReply = false,
    this.reactions = const [],
    this.currentUserId,
    this.onReactionTap,
    this.onRetry,
  });

  String _time(DateTime? d) {
    if (d == null) return '';
    final h = d.hour;
    final m = d.minute.toString().padLeft(2, '0');
    final p = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $p';
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);

    const double avatarSize = 28;
    const double avatarGap = 8;

    // ── Group reactions by emoji ──
    final reactionCounts = <String, int>{};
    final reactionHasMine = <String, bool>{};
    for (final r in reactions) {
      reactionCounts[r.emoji] = (reactionCounts[r.emoji] ?? 0) + 1;
      if (r.userId == currentUserId) reactionHasMine[r.emoji] = true;
    }

    final hasReactions = reactionCounts.isNotEmpty;
    final hasReply = replyMessage != null || hasDeletedReply;

    // ── Timestamp text ──
    final timeText = _time(message.createdAt);

    return Padding(
      // Extra bottom space when reactions are present so they don't
      // collide with the next bubble.
      padding: EdgeInsets.only(bottom: hasReactions ? 14 : 0),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Incoming avatar ──
          if (!isMine) ...[
            if (isBottom)
              isBlockedByOther
                  ? Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                    )
                  : Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: AppCachedImage(
                    imageUrl: avatarUrl,
                    width: avatarSize,
                    height: avatarSize,
                    errorWidget: Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person_rounded,
                          size: 14, color: colors.primary),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: avatarSize),
            const SizedBox(width: avatarGap),
          ],

          if (isMine) const SizedBox(width: 56),

          // ── Bubble body ──
          Flexible(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Main bubble container
                Container(
                  padding: EdgeInsets.fromLTRB(
                    14,
                    hasReply ? 6 : 10,
                    14,
                    8,
                  ),
                  decoration: BoxDecoration(
                    // ── Sent bubble: rich gradient ──
                    gradient: isMine
                        ? LinearGradient(
                            colors: [
                              colors.primary,
                              Color.lerp(
                                  colors.primary, colors.accent, 0.7)!,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    // ── Received bubble: subtle surface ──
                    color: isMine
                        ? null
                        : isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.white,
                    borderRadius: radius,
                    // ── Subtle border on received bubbles ──
                    border: isMine
                        ? null
                        : Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                    boxShadow: [
                      // Sent: colored glow
                      if (isMine)
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      // Received: soft shadow
                      if (!isMine && !isDark)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      if (!isMine && isDark)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Reply reference ──
                      if (hasReply)
                        _ReplyReference(
                          replyMessage: replyMessage,
                          isMine: isMine,
                          isDark: isDark,
                          colors: colors,
                        ),

                      // ── Content + inline timestamp ──
                      // Wrap content and timestamp together so the time
                      // sits at the trailing edge of the last text line.
                      Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: 6,
                        children: [
                          Text(
                            message.content,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              letterSpacing: -0.1,
                              color: isMine
                                  ? Colors.white
                                  : isDark
                                      ? Colors.white.withValues(alpha: 0.92)
                                      : AppColors.darkSurface,
                            ),
                          ),
                          // Inline timestamp + optional read indicator
                          Padding(
                            padding: const EdgeInsets.only(bottom: 1),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  timeText,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: isMine
                                        ? Colors.white.withValues(alpha: 0.55)
                                        : isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.25)
                                            : Colors.black.withValues(
                                                alpha: 0.28),
                                  ),
                                ),
                                if (isMine) ...[
                                  const SizedBox(width: 3),
                                  if (message.isPending && message.hasFailed)
                                    GestureDetector(
                                      onTap: onRetry,
                                      child: const Icon(
                                        Icons.access_time_rounded,
                                        size: 12,
                                        color: Colors.redAccent,
                                      ),
                                    )
                                  else if (message.isPending)
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 12,
                                      color: Colors.white.withValues(alpha: 0.45),
                                    )
                                  else if (message.isRead)
                                    SizedBox(
                                      width: 16,
                                      height: 13,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Icon(
                                            Icons.done_all_rounded,
                                            size: 14,
                                            color: isDark
                                                ? Colors.white.withValues(alpha: 0.5)
                                                : Colors.black.withValues(alpha: 0.4),
                                          ),
                                          Icon(
                                            Icons.done_all_rounded,
                                            size: 13,
                                            color: colors.primary,
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.done_rounded,
                                      size: 13,
                                      color: Colors.white.withValues(alpha: 0.45),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Reaction pills (floating below bubble) ──
                if (hasReactions)
                  Positioned(
                    bottom: -12,
                    left: isMine ? null : 8,
                    right: isMine ? 8 : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Wrap(
                            spacing: 2,
                            children:
                                reactionCounts.entries.map((entry) {
                              final mine =
                                  reactionHasMine[entry.key] == true;
                              return GestureDetector(
                                onTap: () =>
                                    onReactionTap?.call(entry.key),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: mine
                                      ? BoxDecoration(
                                          color: colors.primary
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        )
                                      : null,
                                  child: Text(
                                    entry.value > 1
                                        ? '${entry.key} ${entry.value}'
                                        : entry.key,
                                    style: const TextStyle(
                                        fontSize: 13, height: 1.3),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          if (!isMine) const SizedBox(width: 56),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Reply reference (inside bubble)
// ═══════════════════════════════════════════════════════════════════════════════

class _ReplyReference extends StatelessWidget {
  final Message? replyMessage;
  final bool isMine;
  final bool isDark;
  final AppColorScheme colors;

  const _ReplyReference({
    required this.replyMessage,
    required this.isMine,
    required this.isDark,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final text = replyMessage?.content ?? 'Message deleted';
    final isDeleted = replyMessage == null;

    final accentColor = isMine
        ? Colors.white.withValues(alpha: 0.45)
        : colors.primary.withValues(alpha: 0.5);

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.black.withValues(alpha: 0.12)
            : isDark
                ? Colors.white.withValues(alpha: 0.05)
                : colors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Colored accent bar
          Container(
            width: 3,
            height: 28,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Reply',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isMine
                        ? Colors.white.withValues(alpha: 0.6)
                        : colors.primary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontStyle:
                        isDeleted ? FontStyle.italic : FontStyle.normal,
                    color: isMine
                        ? Colors.white.withValues(alpha: 0.65)
                        : isDark
                            ? Colors.white.withValues(alpha: 0.45)
                            : Colors.black.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Reply preview (above input bar)
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
//  Typing indicator
// ═══════════════════════════════════════════════════════════════════════════════

class _TypingIndicator extends StatefulWidget {
  final bool isDark;
  final AppColorScheme colors;

  const _TypingIndicator({required this.isDark, required this.colors});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) {
              return Row(
                children: List.generate(3, (i) {
                  // Each dot lags by 0.2 of the cycle
                  final offset = i * 0.25;
                  final t = (_anim.value + offset) % 1.0;
                  // Bounce: up in first half, down in second
                  final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2)
                      .clamp(0.3, 1.0);
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? Colors.white54
                              : Colors.black38,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(width: 6),
          Text(
            'typing',
            style: TextStyle(
              fontSize: 12,
              color: widget.isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  final Message message;
  final AppColorScheme colors;
  final bool isDark;
  final VoidCallback onCancel;

  const _ReplyPreview({
    required this.message,
    required this.colors,
    required this.isDark,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
          left: BorderSide(
            color: colors.primary,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded,
              size: 18, color: colors.primary.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Reply',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
                Text(
                  message.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onCancel,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Message actions bottom sheet
// ═══════════════════════════════════════════════════════════════════════════════

const _reactionEmoji = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

class _MessageActionsSheet extends StatelessWidget {
  final Message message;
  final bool isMine;
  final AppColorScheme colors;
  final bool isDark;
  final VoidCallback onCopy;
  final VoidCallback? onReply;
  final VoidCallback? onUnsend;
  final VoidCallback onDeleteForMe;
  final void Function(String emoji)? onReact;

  const _MessageActionsSheet({
    required this.message,
    required this.isMine,
    required this.colors,
    required this.isDark,
    required this.onCopy,
    this.onReply,
    this.onUnsend,
    required this.onDeleteForMe,
    this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurface
                : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // ── Emoji reactions row (only for other's messages) ──
                if (onReact != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _reactionEmoji.map((emoji) {
                        return GestureDetector(
                          onTap: () => onReact!(emoji),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(emoji,
                                style: const TextStyle(fontSize: 22)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                if (onReact != null)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.06),
                  ),

                // ── Action tiles ──
                if (onReply != null)
                  _ActionTile(
                    icon: Icons.reply_rounded,
                    label: 'Reply',
                    colors: colors,
                    isDark: isDark,
                    onTap: onReply!,
                  ),
                _ActionTile(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  colors: colors,
                  isDark: isDark,
                  onTap: onCopy,
                ),
                _ActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete for me',
                  colors: colors,
                  isDark: isDark,
                  onTap: onDeleteForMe,
                ),
                if (onUnsend != null)
                  _ActionTile(
                    icon: Icons.undo_rounded,
                    label: 'Unsend',
                    colors: colors,
                    isDark: isDark,
                    onTap: onUnsend!,
                    isDestructive: true,
                  ),

                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppColorScheme colors;
  final bool isDark;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.colors,
    required this.isDark,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? Colors.redAccent
        : (isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87);

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Input bar
// ═══════════════════════════════════════════════════════════════════════════════

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final AppColorScheme colors;
  final bool isDark;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.colors,
    required this.isDark,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.95),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: controller,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: null,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyle(
                            fontSize: 14.5,
                            color: isDark ? Colors.white30 : Colors.black26,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                        ),
                        onSubmitted: (_) => onSend(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: sending ? null : onSend,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.primary, colors.accent],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: sending
                          ? const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

// ── Swipe-to-reply widget ─────────────────────────────────────────────────────
// Limits drag to [_maxDrag] px and snaps back. Triggers reply at [_triggerAt].

class _SwipeToReply extends StatefulWidget {
  final Widget child;
  final bool isMine;
  final AppColorScheme colors;
  final VoidCallback onReply;

  const _SwipeToReply({
    required this.child,
    required this.isMine,
    required this.colors,
    required this.onReply,
  });

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply>
    with SingleTickerProviderStateMixin {
  double _offset = 0;
  bool _triggered = false;
  late AnimationController _snapController;
  late Animation<double> _snapAnim;

  // Max pixels the bubble can slide
  static const double _maxDrag = 60.0;
  // Drag distance needed to trigger the reply
  static const double _triggerAt = 42.0;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final dx = d.delta.dx;
    // Mine swipes left (negative); incoming swipes right (positive)
    if (widget.isMine && dx > 0) return;
    if (!widget.isMine && dx < 0) return;

    setState(() {
      _offset = widget.isMine
          ? (_offset + dx).clamp(-_maxDrag, 0.0)
          : (_offset + dx).clamp(0.0, _maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails _) {
    if (_offset.abs() >= _triggerAt && !_triggered) {
      _triggered = true;
      HapticFeedback.lightImpact();
      widget.onReply();
    }
    // Snap back to rest
    _snapAnim = Tween<double>(begin: _offset, end: 0.0).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOut),
    )..addListener(() => setState(() => _offset = _snapAnim.value));
    _snapController.forward(from: 0.0).then((_) => _triggered = false);
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_offset.abs() / _maxDrag).clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Reply icon fades + scales in behind the bubble as it slides
          Positioned.fill(
            child: Align(
              alignment: widget.isMine
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(
                  right: widget.isMine ? 10 : 0,
                  left: widget.isMine ? 0 : 10,
                ),
                child: Opacity(
                  opacity: progress,
                  child: Transform.scale(
                    scale: 0.5 + 0.5 * progress,
                    child: Icon(
                      Icons.reply_rounded,
                      color: widget.colors.primary,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // The bubble itself
          Transform.translate(
            offset: Offset(_offset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
