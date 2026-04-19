import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_theme.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme_provider.dart';

Future<void> showChangePasswordSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _ChangePasswordSheet(),
  );
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _saving = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  String? _currentError;
  String? _newError;
  String? _confirmError;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _currentError = _currentCtrl.text.isEmpty
          ? 'Enter your current password'
          : null;
      _newError = _newCtrl.text.length < 8
          ? 'Must be at least 8 characters'
          : null;
      _confirmError = _confirmCtrl.text != _newCtrl.text
          ? 'Passwords don\u2019t match'
          : null;
    });
    return _currentError == null &&
        _newError == null &&
        _confirmError == null;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_validate()) return;

    setState(() => _saving = true);

    final client = ref.read(supabaseProvider);
    final email = client.auth.currentUser?.email;
    if (email == null) {
      setState(() {
        _saving = false;
        _currentError = 'Not signed in';
      });
      return;
    }

    try {
      await client.auth.signInWithPassword(
        email: email,
        password: _currentCtrl.text,
      );
    } on AuthException catch (_) {
      setState(() {
        _saving = false;
        _currentError = 'Current password is incorrect';
      });
      return;
    } catch (e) {
      setState(() {
        _saving = false;
        _currentError = 'Could not verify: $e';
      });
      return;
    }

    try {
      await ref.read(authServiceProvider).updatePassword(_newCtrl.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated')),
      );
    } catch (e) {
      setState(() {
        _saving = false;
        _newError = 'Could not update password: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Change password',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  if (_saving)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colors.primary, colors.accent],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PasswordField(
                    controller: _currentCtrl,
                    label: 'Current password',
                    obscure: !_showCurrent,
                    isDark: isDark,
                    primary: colors.primary,
                    error: _currentError,
                    onToggleVisibility: () {
                      HapticFeedback.lightImpact();
                      setState(() => _showCurrent = !_showCurrent);
                    },
                  ),
                  const SizedBox(height: 14),
                  _PasswordField(
                    controller: _newCtrl,
                    label: 'New password',
                    obscure: !_showNew,
                    isDark: isDark,
                    primary: colors.primary,
                    error: _newError,
                    onToggleVisibility: () {
                      HapticFeedback.lightImpact();
                      setState(() => _showNew = !_showNew);
                    },
                  ),
                  const SizedBox(height: 14),
                  _PasswordField(
                    controller: _confirmCtrl,
                    label: 'Confirm new password',
                    obscure: !_showConfirm,
                    isDark: isDark,
                    primary: colors.primary,
                    error: _confirmError,
                    onToggleVisibility: () {
                      HapticFeedback.lightImpact();
                      setState(() => _showConfirm = !_showConfirm);
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final bool isDark;
  final Color primary;
  final String? error;
  final VoidCallback onToggleVisibility;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.isDark,
    required this.primary,
    required this.error,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final fieldBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.03);
    final border = error != null
        ? Colors.red.withValues(alpha: 0.5)
        : (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.06));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onToggleVisibility,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.red.withValues(alpha: 0.9),
            ),
          ),
        ],
      ],
    );
  }
}
