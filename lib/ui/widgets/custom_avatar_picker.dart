import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/bunny_config.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/profile_providers.dart';
import '../../core/services/profile_service.dart';
import '../../core/theme_provider.dart';
import 'app_cached_image.dart';

/// Opens a bottom sheet showing the 20 prebuilt thumbs avatars.
/// Writes the chosen CDN URL to profiles.avatar_url directly. If [onPicked]
/// is provided, the picker calls that instead and does not touch the DB
/// (used during first-time profile completion where the upsert hasn't run
/// yet).
Future<void> showCustomAvatarPicker(
  BuildContext context, {
  void Function(String url)? onPicked,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CustomAvatarPicker(onPicked: onPicked),
  );
}

class _CustomAvatarPicker extends ConsumerStatefulWidget {
  final void Function(String url)? onPicked;

  const _CustomAvatarPicker({this.onPicked});

  @override
  ConsumerState<_CustomAvatarPicker> createState() =>
      _CustomAvatarPickerState();
}

class _CustomAvatarPickerState extends ConsumerState<_CustomAvatarPicker> {
  String? _selectedUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Preselect the user's current avatar if it's already a custom one.
    final current = ref.read(fullProfileProvider).value?.avatarUrl;
    if (CustomAvatars.isCustom(current)) {
      _selectedUrl = current;
    }
  }

  Future<void> _save() async {
    if (_saving || _selectedUrl == null) return;

    if (widget.onPicked != null) {
      widget.onPicked!(_selectedUrl!);
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = true);
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      setState(() => _saving = false);
      return;
    }
    try {
      await ProfileService(ref.read(supabaseProvider))
          .updateProfile(userId, {'avatar_url': _selectedUrl});
      ref.invalidate(fullProfileProvider);
      ref.invalidate(currentProfileProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not set avatar: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
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
    final tileText = isDark ? Colors.white : Colors.black87;
    final urls = CustomAvatars.allUrls();

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
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Pick an avatar',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: tileText,
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
                    onTap: _selectedUrl == null ? null : _save,
                    child: Opacity(
                      opacity: _selectedUrl == null ? 0.4 : 1.0,
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
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: urls.length,
              itemBuilder: (context, i) {
                final url = urls[i];
                final selected = _selectedUrl == url;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedUrl = url);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? colors.primary
                            : Colors.transparent,
                        width: selected ? 2.5 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: AppCachedImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
