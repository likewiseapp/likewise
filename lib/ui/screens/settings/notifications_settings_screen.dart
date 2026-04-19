import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_theme.dart';
import '../../../core/providers/notification_providers.dart';
import '../../../core/theme_provider.dart';

const _toggles = [
  (
    field: 'follows',
    label: 'New followers',
    subtitle: 'When someone follows you',
    icon: Icons.person_add_alt_rounded,
  ),
  (
    field: 'messages',
    label: 'Messages',
    subtitle: 'New messages and requests',
    icon: Icons.chat_bubble_outline_rounded,
  ),
  (
    field: 'twin_match',
    label: 'Twin matches',
    subtitle: 'When we find someone like you',
    icon: Icons.favorite_outline_rounded,
  ),
  (
    field: 'mentions',
    label: 'Mentions',
    subtitle: 'When someone tags you',
    icon: Icons.alternate_email_rounded,
  ),
  (
    field: 'likes',
    label: 'Likes',
    subtitle: 'When someone likes your wave',
    icon: Icons.favorite_border_rounded,
  ),
  (
    field: 'comments',
    label: 'Comments',
    subtitle: 'Replies and comments on your waves',
    icon: Icons.mode_comment_outlined,
  ),
];

class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prefsAsync = ref.watch(notificationPreferencesProvider);

    final bg = isDark ? AppColors.darkScaffold : AppColors.lightScaffoldAlt;
    final subtleText = isDark ? Colors.white38 : Colors.black38;
    final tileText = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark ? Colors.white54 : Colors.black45;
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top bar ───────────────────────────────────────────
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
                    'Notifications',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: prefsAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: colors.primary,
                    strokeWidth: 2.5,
                  ),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load preferences.\n$err',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: subtleText),
                    ),
                  ),
                ),
                data: (prefs) => _buildList(
                  context: context,
                  ref: ref,
                  prefs: prefs,
                  colors: colors,
                  isDark: isDark,
                  subtleText: subtleText,
                  tileText: tileText,
                  iconColor: iconColor,
                  divider: divider,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList({
    required BuildContext context,
    required WidgetRef ref,
    required Map<String, bool> prefs,
    required AppColorScheme colors,
    required bool isDark,
    required Color subtleText,
    required Color tileText,
    required Color iconColor,
    required Color divider,
  }) {
    final pushEnabled = prefs['push_enabled'] ?? true;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // ── Master toggle ─────────────────────────────────────
        _SectionLabel(text: 'Push', color: subtleText),
        _Card(
          isDark: isDark,
          dividerColor: divider,
          children: [
            _SwitchTile(
              icon: Icons.notifications_active_outlined,
              label: 'Push notifications',
              subtitle: pushEnabled ? 'Enabled' : 'All push is muted',
              iconColor: iconColor,
              textColor: tileText,
              subtitleColor: subtleText,
              value: pushEnabled,
              activeColor: colors.primary,
              isDark: isDark,
              onChanged: (val) => _toggle(ref, context, 'push_enabled', val),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ── Categories ────────────────────────────────────────
        _SectionLabel(text: 'Activity', color: subtleText),
        Opacity(
          opacity: pushEnabled ? 1 : 0.4,
          child: IgnorePointer(
            ignoring: !pushEnabled,
            child: _Card(
              isDark: isDark,
              dividerColor: divider,
              children: [
                for (int i = 0; i < _toggles.length; i++) ...[
                  _SwitchTile(
                    icon: _toggles[i].icon,
                    label: _toggles[i].label,
                    subtitle: _toggles[i].subtitle,
                    iconColor: iconColor,
                    textColor: tileText,
                    subtitleColor: subtleText,
                    value: prefs[_toggles[i].field] ?? true,
                    activeColor: colors.primary,
                    isDark: isDark,
                    onChanged: (val) => _toggle(
                      ref,
                      context,
                      _toggles[i].field,
                      val,
                    ),
                  ),
                  if (i < _toggles.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 52),
                      child: Divider(height: 1, color: divider),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggle(
    WidgetRef ref,
    BuildContext context,
    String field,
    bool value,
  ) async {
    HapticFeedback.lightImpact();
    try {
      await ref
          .read(notificationPreferencesProvider.notifier)
          .setPreference(field, value);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }
}

// ── Reusable pieces (kept local so the settings page file stays isolated) ──

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final bool isDark;
  final Color dividerColor;
  final List<Widget> children;

  const _Card({
    required this.isDark,
    required this.dividerColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        border: Border.symmetric(horizontal: BorderSide(color: dividerColor)),
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color iconColor;
  final Color textColor;
  final Color subtitleColor;
  final Color activeColor;
  final bool value;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.iconColor,
    required this.textColor,
    required this.subtitleColor,
    required this.activeColor,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 8, top: 6, bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: subtitleColor),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: activeColor,
            activeTrackColor: activeColor.withValues(alpha: 0.3),
            inactiveThumbColor: isDark ? Colors.white38 : Colors.grey.shade400,
            inactiveTrackColor: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ],
      ),
    );
  }
}
