import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_theme.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _pageController = PageController();

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  int _step = 0;
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _go(int step) {
    setState(() {
      _step = step;
      _error = null;
    });
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _sendOTP() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).sendPasswordResetOTP(email: email);
      _go(1);
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).verifyPasswordResetOTP(
            email: _emailController.text.trim(),
            otp: otp,
          );
      _go(2);
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setNewPassword() async {
    final pw = _passwordController.text;
    final confirm = _confirmController.text;
    if (pw.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (pw != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).updatePassword(pw);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. You are signed in.')),
      );
      // Router auto-redirects based on profile existence.
      context.go('/');
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendly(Object e) {
    final msg = e.toString();
    if (msg.contains('Token has expired') || msg.contains('invalid')) {
      return 'Invalid or expired code. Try again.';
    }
    if (msg.contains('rate')) {
      return 'Too many attempts. Please wait a moment.';
    }
    return msg.replaceAll('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkScaffold : AppColors.lightScaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () {
            if (_step == 0) {
              context.go('/auth');
            } else {
              _go(_step - 1);
            }
          },
        ),
      ),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildEmailStep(isDark, colors),
            _buildOtpStep(isDark, colors),
            _buildPasswordStep(isDark, colors),
          ],
        ),
      ),
    );
  }

  Widget _stepScaffold({
    required bool isDark,
    required AppColorScheme colors,
    required String title,
    required String subtitle,
    required List<Widget> children,
    required String buttonLabel,
    required VoidCallback onButton,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _stepIndicator(colors),
          const SizedBox(height: 28),
          Text(
            title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          ...children,
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: MaterialButton(
              onPressed: _loading ? null : onButton,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: EdgeInsets.zero,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _loading
                        ? [Colors.grey.shade400, Colors.grey.shade400]
                        : [colors.primary, colors.accent],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          buttonLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _stepIndicator(AppColorScheme colors) {
    return Row(
      children: List.generate(3, (i) {
        final active = i <= _step;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
            decoration: BoxDecoration(
              color: active ? colors.primary : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEmailStep(bool isDark, AppColorScheme colors) {
    return _stepScaffold(
      isDark: isDark,
      colors: colors,
      title: 'Forgot password?',
      subtitle:
          'Enter your email and we\'ll send you a 6-digit code to reset your password.',
      children: [
        _field(
          controller: _emailController,
          hint: 'Email address',
          icon: Icons.email_outlined,
          isDark: isDark,
          colors: colors,
          keyboardType: TextInputType.emailAddress,
        ),
      ],
      buttonLabel: 'Send Code',
      onButton: _sendOTP,
    );
  }

  Widget _buildOtpStep(bool isDark, AppColorScheme colors) {
    return _stepScaffold(
      isDark: isDark,
      colors: colors,
      title: 'Enter code',
      subtitle:
          'We sent a 6-digit code to ${_emailController.text.trim()}. Enter it below to continue.',
      children: [
        _field(
          controller: _otpController,
          hint: '6-digit code',
          icon: Icons.pin_outlined,
          isDark: isDark,
          colors: colors,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _loading ? null : _sendOTP,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Resend code',
              style: TextStyle(
                fontSize: 13,
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
      buttonLabel: 'Verify',
      onButton: _verifyOTP,
    );
  }

  Widget _buildPasswordStep(bool isDark, AppColorScheme colors) {
    return _stepScaffold(
      isDark: isDark,
      colors: colors,
      title: 'New password',
      subtitle: 'Choose a strong password (at least 6 characters).',
      children: [
        _field(
          controller: _passwordController,
          hint: 'New password',
          icon: Icons.lock_outline_rounded,
          isDark: isDark,
          colors: colors,
          obscure: _obscure,
          suffixIcon: IconButton(
            icon: Icon(
              _obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
              color: Colors.grey.shade500,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        const SizedBox(height: 12),
        _field(
          controller: _confirmController,
          hint: 'Confirm password',
          icon: Icons.lock_outline_rounded,
          isDark: isDark,
          colors: colors,
          obscure: _obscure,
        ),
      ],
      buttonLabel: 'Update Password',
      onButton: _setNewPassword,
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    required AppColorScheme colors,
    bool obscure = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.07),
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 20, color: colors.primary),
          suffixIcon: suffixIcon,
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontWeight: FontWeight.w400,
            fontSize: 15,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
      ),
    );
  }
}
