import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/presence_providers.dart';
import '../../../core/providers/profile_providers.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/app_theme.dart';
import '../../../core/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onlineStatusAsync = ref.watch(onlineStatusProvider);
    final isOnline = onlineStatusAsync.value ?? true;
    final profile = ref.watch(fullProfileProvider).value;
    final messagePermission = profile?.messagePermission ?? 'everyone';
    final profileVisibility = profile?.profileVisibility ?? 'public';

    final bg = isDark ? AppColors.darkScaffold : AppColors.lightScaffoldAlt;
    final subtleText = isDark ? Colors.white38 : Colors.black38;
    final tileText = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark ? Colors.white54 : Colors.black45;
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── Header ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
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
                      'Settings',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // ── Account ────────────────────────────────────────────────
          _SectionLabel(text: 'Account', color: subtleText),
          _SectionCard(
            isDark: isDark,
            dividerColor: divider,
            tiles: [
              _Tile(
                icon: Icons.lock_outline_rounded,
                label: 'Change Password',
                iconColor: iconColor,
                textColor: tileText,
                onTap: () {},
              ),
              _Tile(
                icon: Icons.email_outlined,
                label: 'Email Address',
                iconColor: iconColor,
                textColor: tileText,
                onTap: () {},
              ),
            ],
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // ── Preferences ────────────────────────────────────────────
          _SectionLabel(text: 'Preferences', color: subtleText),
          _SectionCard(
            isDark: isDark,
            dividerColor: divider,
            tiles: [
              _Tile(
                icon: Icons.palette_outlined,
                label: 'Theme',
                iconColor: iconColor,
                textColor: tileText,
                value: colors.name,
                onTap: () => context.push('/theme-selector'),
              ),
              _Tile(
                icon: Icons.notifications_none_rounded,
                label: 'Notifications',
                iconColor: iconColor,
                textColor: tileText,
                onTap: () {},
              ),
              _Tile(
                icon: Icons.language_rounded,
                label: 'Language',
                iconColor: iconColor,
                textColor: tileText,
                value: 'English',
                onTap: () {},
              ),
            ],
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // ── Privacy ────────────────────────────────────────────────
          _SectionLabel(text: 'Privacy', color: subtleText),
          _SectionCard(
            isDark: isDark,
            dividerColor: divider,
            tiles: [
              _SwitchTile(
                icon: Icons.circle,
                iconSize: 10,
                label: 'Online Status',
                subtitle: isOnline ? 'Visible to others' : 'Hidden',
                iconColor: isOnline
                    ? AppColors.onlineGreen
                    : (isDark ? Colors.white24 : Colors.black26),
                textColor: tileText,
                subtitleColor: subtleText,
                value: isOnline,
                activeColor: colors.primary,
                isDark: isDark,
                onChanged: (val) {
                  HapticFeedback.lightImpact();
                  ref.read(onlineStatusProvider.notifier).toggle(val);
                },
              ),
              _Tile(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Who Can Message Me',
                iconColor: iconColor,
                textColor: tileText,
                value: _permissionLabel(messagePermission),
                onTap: () => _showMessagePermissionSheet(
                  context, ref, messagePermission, colors, isDark,
                ),
              ),
              _Tile(
                icon: Icons.visibility_off_outlined,
                label: 'Profile Visibility',
                iconColor: iconColor,
                textColor: tileText,
                value: _visibilityLabel(profileVisibility),
                onTap: () => _showVisibilitySheet(
                  context, ref, profileVisibility, colors, isDark,
                ),
              ),
              _Tile(
                icon: Icons.block_rounded,
                label: 'Blocked Users',
                iconColor: iconColor,
                textColor: tileText,
                onTap: () => context.push('/blocked-users'),
              ),
            ],
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // ── Support ────────────────────────────────────────────────
          _SectionLabel(text: 'Support', color: subtleText),
          _SectionCard(
            isDark: isDark,
            dividerColor: divider,
            tiles: [
              _Tile(
                icon: Icons.help_outline_rounded,
                label: 'Help Center',
                iconColor: iconColor,
                textColor: tileText,
                onTap: () {},
              ),
              _Tile(
                icon: Icons.flag_outlined,
                label: 'Report a Problem',
                iconColor: iconColor,
                textColor: tileText,
                onTap: () {},
              ),
              _Tile(
                icon: Icons.info_outline_rounded,
                label: 'About',
                iconColor: iconColor,
                textColor: tileText,
                value: 'v0.1.0',
                onTap: () {},
              ),
            ],
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // ── Log Out / Delete ───────────────────────────────────────
          _SectionCard(
            isDark: isDark,
            dividerColor: divider,
            tiles: [
              _Tile(
                icon: Icons.logout_rounded,
                label: 'Log Out',
                iconColor: Colors.red.withValues(alpha: 0.7),
                textColor: Colors.red.withValues(alpha: 0.85),
                showChevron: false,
                onTap: () async {
                  HapticFeedback.lightImpact();
                  final confirmed = await _showConfirmDialog(
                    context,
                    isDark: isDark,
                    title: 'Log Out',
                    message: 'Are you sure you want to log out?',
                    confirmLabel: 'Log Out',
                  );
                  if (confirmed && context.mounted) {
                    await ref.read(authServiceProvider).signOut();
                  }
                },
              ),
              _Tile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete Account',
                iconColor: Colors.red.withValues(alpha: 0.7),
                textColor: Colors.red.withValues(alpha: 0.85),
                showChevron: false,
                onTap: () {},
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).padding.bottom + 40,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final bool isDark;
  final Color dividerColor;
  final List<Widget> tiles;

  const _SectionCard({
    required this.isDark,
    required this.dividerColor,
    required this.tiles,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white,
          border: Border.symmetric(
            horizontal: BorderSide(color: dividerColor),
          ),
        ),
        child: Column(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              tiles[i],
              if (i < tiles.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: Divider(height: 1, color: dividerColor),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Standard tile ─────────────────────────────────────────────────────────

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color textColor;
  final String? value;
  final bool showChevron;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.textColor,
    this.value,
    this.showChevron = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: textColor,
                ),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
              ),
            if (showChevron) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Switch tile ───────────────────────────────────────────────────────────

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final double iconSize;
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
    this.iconSize = 20,
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
            child: Icon(icon, size: iconSize, color: iconColor),
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

// ── Helpers ───────────────────────────────────────────────────────────────

String _visibilityLabel(String visibility) {
  const labels = {
    'public': 'Public',
    'followers_only': 'Followers',
    'private': 'Private',
  };
  return labels[visibility] ?? 'Public';
}

String _permissionLabel(String permission) {
  const labels = {
    'everyone': 'Everyone',
    'followers_only': 'Followers',
    'none': 'No one',
  };
  return labels[permission] ?? 'Everyone';
}

Future<bool> _showConfirmDialog(
  BuildContext context, {
  required bool isDark,
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 17,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          content: Text(
            message,
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
              child: Text(
                confirmLabel,
                style: const TextStyle(
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

// ── Profile visibility bottom sheet ───────────────────────────────────────

void _showVisibilitySheet(
  BuildContext context,
  WidgetRef ref,
  String current,
  AppColorScheme colors,
  bool isDark,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _OptionSheet(
      title: 'Profile Visibility',
      current: current,
      colors: colors,
      isDark: isDark,
      options: const [
        (
          value: 'public',
          label: 'Public',
          sub: 'Anyone can see your profile',
          icon: Icons.public_rounded,
        ),
        (
          value: 'followers_only',
          label: 'Followers only',
          sub: 'Only your followers can see your profile',
          icon: Icons.people_alt_rounded,
        ),
        (
          value: 'private',
          label: 'Private',
          sub: 'Only you can see your profile',
          icon: Icons.lock_outline_rounded,
        ),
      ],
      onSelected: (value) async {
        final userId = ref.read(currentUserIdProvider);
        if (userId == null) return;
        final client = ref.read(supabaseProvider);
        try {
          await ProfileService(client)
              .updateProfile(userId, {'profile_visibility': value});
          ref.invalidate(fullProfileProvider);
        } catch (_) {
          ref.invalidate(fullProfileProvider);
        }
      },
    ),
  );
}

// ── Message permission bottom sheet ───────────────────────────────────────

void _showMessagePermissionSheet(
  BuildContext context,
  WidgetRef ref,
  String current,
  AppColorScheme colors,
  bool isDark,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _OptionSheet(
      title: 'Who can message me',
      current: current,
      colors: colors,
      isDark: isDark,
      options: const [
        (
          value: 'everyone',
          label: 'Everyone',
          sub: 'Anyone on likewise can message you',
          icon: Icons.public_rounded,
        ),
        (
          value: 'followers_only',
          label: 'Followers only',
          sub: 'Only people who follow you can message you',
          icon: Icons.people_alt_rounded,
        ),
        (
          value: 'none',
          label: 'No one',
          sub: 'Turn off direct messages completely',
          icon: Icons.do_not_disturb_on_rounded,
        ),
      ],
      onSelected: (value) async {
        final userId = ref.read(currentUserIdProvider);
        if (userId == null) return;
        final client = ref.read(supabaseProvider);
        try {
          await ProfileService(client)
              .updateProfile(userId, {'message_permission': value});
          ref.invalidate(fullProfileProvider);
        } catch (_) {
          ref.invalidate(fullProfileProvider);
        }
      },
    ),
  );
}

// ── Reusable option sheet ─────────────────────────────────────────────────

typedef _OptionRecord = ({String value, String label, String sub, IconData icon});

class _OptionSheet extends StatefulWidget {
  final String title;
  final String current;
  final AppColorScheme colors;
  final bool isDark;
  final List<_OptionRecord> options;
  final Future<void> Function(String) onSelected;

  const _OptionSheet({
    required this.title,
    required this.current,
    required this.colors,
    required this.isDark,
    required this.options,
    required this.onSelected,
  });

  @override
  State<_OptionSheet> createState() => _OptionSheetState();
}

class _OptionSheetState extends State<_OptionSheet> {
  late String _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  Future<void> _save() async {
    if (_saving || _selected == widget.current) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    await widget.onSelected(_selected);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.darkSurface : Colors.white;
    final divider = widget.isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
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
              color: widget.isDark
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
                  widget.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                if (_saving)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: widget.colors.primary),
                  )
                else
                  GestureDetector(
                    onTap: _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          widget.colors.primary,
                          widget.colors.accent,
                        ]),
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
          ...widget.options.map((opt) {
            final isChosen = _selected == opt.value;
            return Column(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selected = opt.value);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                          opt.icon,
                          size: 20,
                          color: isChosen
                              ? widget.colors.primary
                              : (widget.isDark
                                  ? Colors.white38
                                  : Colors.black38),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt.label,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isChosen
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isChosen
                                      ? widget.colors.primary
                                      : (widget.isDark
                                          ? Colors.white
                                          : Colors.black87),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                opt.sub,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: widget.isDark
                                      ? Colors.white30
                                      : Colors.black26,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isChosen
                                ? widget.colors.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: isChosen
                                  ? widget.colors.primary
                                  : (widget.isDark
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : Colors.black.withValues(alpha: 0.2)),
                              width: 1.5,
                            ),
                          ),
                          child: isChosen
                              ? const Icon(Icons.check_rounded,
                                  size: 12, color: Colors.white)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: divider),
              ],
            );
          }),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
