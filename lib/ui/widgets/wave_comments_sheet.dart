import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/wave_comment.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/wave_providers.dart';
import '../../core/theme_provider.dart';
import 'app_cached_image.dart';

/// Full-height comments sheet for a wave. Shown via
/// [showWaveCommentsSheet].
Future<void> showWaveCommentsSheet(
  BuildContext context, {
  required String waveId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => _WaveCommentsSheet(waveId: waveId),
  );
}

class _WaveCommentsSheet extends ConsumerStatefulWidget {
  final String waveId;
  const _WaveCommentsSheet({required this.waveId});

  @override
  ConsumerState<_WaveCommentsSheet> createState() => _WaveCommentsSheetState();
}

class _WaveCommentsSheetState extends ConsumerState<_WaveCommentsSheet> {
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();
  bool _posting = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(() {
      final has = _inputController.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      await ref
          .read(waveEngagementServiceProvider)
          .postComment(widget.waveId, text);
      _inputController.clear();
      if (mounted) _inputFocus.unfocus();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn\'t post — try again'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _deleteOwn(WaveComment c) async {
    HapticFeedback.selectionClick();
    final colors = ref.read(appColorSchemeProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete comment?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This can\'t be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(
                  color: colors.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(waveEngagementServiceProvider).deleteComment(c.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn\'t delete — try again'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(waveCommentsProvider(widget.waveId));
    final colors = ref.watch(appColorSchemeProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _SheetHandle(),
            _SheetHeader(count: commentsAsync.value?.length),
            const Divider(height: 1, color: Colors.white10),

            // List
            Expanded(
              child: commentsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white54,
                    strokeWidth: 2.5,
                  ),
                ),
                error: (_, _) => const Center(
                  child: Text(
                    'Couldn\'t load comments',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                data: (comments) {
                  if (comments.isEmpty) return const _EmptyComments();
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: comments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => _CommentRow(
                      comment: comments[i],
                      isMine: comments[i].userId == currentUserId,
                      onDelete: () => _deleteOwn(comments[i]),
                    ),
                  );
                },
              ),
            ),

            // Input
            Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                padding:
                    const EdgeInsets.fromLTRB(14, 10, 10, 10),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white10),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 110),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: TextField(
                            controller: _inputController,
                            focusNode: _inputFocus,
                            maxLines: null,
                            maxLength: 500,
                            textCapitalization: TextCapitalization.sentences,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Add a comment…',
                              hintStyle: TextStyle(color: Colors.white38),
                              border: InputBorder.none,
                              isDense: true,
                              counterText: '',
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SendBtn(
                        enabled: _hasText && !_posting,
                        loading: _posting,
                        color: colors.primary,
                        onTap: _post,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small sub-widgets ────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
}

class _SheetHeader extends StatelessWidget {
  final int? count;
  const _SheetHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: Text(
        count == null
            ? 'Comments'
            : count == 1
                ? '1 comment'
                : '$count comments',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyComments extends StatelessWidget {
  const _EmptyComments();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mode_comment_outlined,
                size: 36, color: Colors.white.withValues(alpha: 0.35)),
            const SizedBox(height: 12),
            const Text(
              'Be the first to comment',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  final WaveComment comment;
  final bool isMine;
  final VoidCallback onDelete;

  const _CommentRow({
    required this.comment,
    required this.isMine,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: isMine ? onDelete : null,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12, width: 1),
            ),
            child: ClipOval(
              child: AppCachedImage(
                imageUrl: comment.avatarUrl,
                fit: BoxFit.cover,
                errorWidget: Container(
                  color: Colors.white10,
                  child: const Icon(Icons.person_rounded,
                      color: Colors.white38, size: 18),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.username != null
                            ? '@${comment.username}'
                            : (comment.fullName ?? 'Unknown'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _relativeTime(comment.createdAt),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: onDelete,
                        behavior: HitTestBehavior.opaque,
                        child: const Icon(
                          Icons.more_horiz_rounded,
                          size: 16,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  comment.content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.35,
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

class _SendBtn extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final Color color;
  final VoidCallback onTap;

  const _SendBtn({
    required this.enabled,
    required this.loading,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled ? color : Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(
                Icons.send_rounded,
                size: 18,
                color: enabled ? Colors.white : Colors.white38,
              ),
      ),
    );
  }
}

String _relativeTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  if (d.inDays < 30) return '${(d.inDays / 7).floor()}w';
  if (d.inDays < 365) return '${(d.inDays / 30).floor()}mo';
  return '${(d.inDays / 365).floor()}y';
}
