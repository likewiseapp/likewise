import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_theme.dart';
import '../../../core/providers/account_providers.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme_provider.dart';

const _reasons = [
  (value: 'not_useful', label: 'The app isn\u2019t useful to me'),
  (value: 'privacy_concerns', label: 'Privacy concerns'),
  (value: 'too_many_notifications', label: 'Too many notifications'),
  (value: 'found_another_app', label: 'I found another app'),
  (value: 'temporary_break', label: 'I just need a temporary break'),
  (value: 'other', label: 'Other'),
];

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  String? _selectedReason;
  final _descriptionController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null || _submitting) return;

    final confirmed = await _showConfirmDialog();
    if (!confirmed || !mounted) return;

    setState(() => _submitting = true);

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      setState(() => _submitting = false);
      return;
    }

    try {
      await ref.read(accountServiceProvider).requestDeletion(
            userId: userId,
            reason: _selectedReason!,
            description: _descriptionController.text,
          );
      if (!mounted) return;
      await _showSuccessDialog();
      if (!mounted) return;
      await ref.read(authServiceProvider).signOut();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not submit request: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<bool> _showConfirmDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Delete account?',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 17,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            content: Text(
              'This will submit a deletion request. Your account and data will be removed shortly after review. This action can\u2019t be undone.',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Request Deletion',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showSuccessDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Request submitted',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Your account will be processed for deletion. You\u2019ll now be signed out.',
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendingAsync = ref.watch(pendingDeletionRequestProvider);

    final bg = isDark ? AppColors.darkScaffold : AppColors.lightScaffoldAlt;
    final tileText = isDark ? Colors.white : Colors.black87;
    final subtleText = isDark ? Colors.white38 : Colors.black38;
    final fieldBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top bar ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.pop();
                    },
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: tileText,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Delete Account',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────
            Expanded(
              child: pendingAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: colors.primary,
                    strokeWidth: 2.5,
                  ),
                ),
                error: (_, _) => _buildForm(
                  isDark: isDark,
                  colors: colors,
                  tileText: tileText,
                  subtleText: subtleText,
                  fieldBg: fieldBg,
                  border: border,
                ),
                data: (pending) {
                  if (pending != null) {
                    return _buildPendingState(
                      isDark: isDark,
                      tileText: tileText,
                      subtleText: subtleText,
                    );
                  }
                  return _buildForm(
                    isDark: isDark,
                    colors: colors,
                    tileText: tileText,
                    subtleText: subtleText,
                    fieldBg: fieldBg,
                    border: border,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pending state ────────────────────────────────────────────────────────

  Widget _buildPendingState({
    required bool isDark,
    required Color tileText,
    required Color subtleText,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_empty_rounded,
              size: 48,
              color: subtleText,
            ),
            const SizedBox(height: 16),
            Text(
              'Deletion requested',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: tileText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your account is queued for deletion. You can still use the app until the request is processed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: subtleText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Form ────────────────────────────────────────────────────────────────

  Widget _buildForm({
    required bool isDark,
    required AppColorScheme colors,
    required Color tileText,
    required Color subtleText,
    required Color fieldBg,
    required Color border,
  }) {
    final disabled = _selectedReason == null || _submitting;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        // ── Warning banner ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 20,
                color: Colors.red.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Deleting your account is permanent. Your profile, waves, messages and followers will be removed.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Reason ─────────────────────────────────────────────────
        Text(
          'Why are you leaving?',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: subtleText,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Column(
            children: [
              for (int i = 0; i < _reasons.length; i++) ...[
                _ReasonTile(
                  label: _reasons[i].label,
                  selected: _selectedReason == _reasons[i].value,
                  primary: colors.primary,
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedReason = _reasons[i].value);
                  },
                ),
                if (i < _reasons.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Divider(height: 1, color: border),
                  ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Description ────────────────────────────────────────────
        Text(
          'Anything else? (optional)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: subtleText,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: TextField(
            controller: _descriptionController,
            maxLines: 4,
            maxLength: 500,
            style: TextStyle(color: tileText, fontSize: 14),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(14),
              border: InputBorder.none,
              hintText: 'Share more context so we can improve',
              hintStyle: TextStyle(
                color: subtleText,
                fontSize: 14,
              ),
              counterStyle: TextStyle(
                color: subtleText,
                fontSize: 11,
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),

        // ── Submit ─────────────────────────────────────────────────
        GestureDetector(
          onTap: disabled ? null : _submit,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: disabled
                  ? Colors.red.withValues(alpha: isDark ? 0.2 : 0.25)
                  : Colors.red,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Request Account Deletion',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Reason tile ───────────────────────────────────────────────────────────

class _ReasonTile extends StatelessWidget {
  final String label;
  final bool selected;
  final Color primary;
  final bool isDark;
  final VoidCallback onTap;

  const _ReasonTile({
    required this.label,
    required this.selected,
    required this.primary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? primary
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? primary : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? primary
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.2)),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      size: 12, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
