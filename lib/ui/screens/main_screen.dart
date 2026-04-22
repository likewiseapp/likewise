import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/providers/navigation_providers.dart';
import '../../core/providers/profile_providers.dart';
import '../../core/providers/wave_providers.dart';
import '../../core/services/location_service.dart';
import '../../core/theme_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/profile_completion_banner.dart';
import 'explore/explore_screen.dart';
import 'explore/search_screen.dart';
import 'profile/profile_screen.dart';
import 'waves/waves_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final List<Widget> _screens = [
    const ExploreScreen(),
    const WavesScreen(),
    const SearchScreen(),
    const ProfileScreen(),
  ];

  bool _showSuccessBanner = false;
  String? _uploadError;
  bool _profileBannerDismissed = false;
  bool _locationAutoDetectTried = false;

  @override
  Widget build(BuildContext context) {
    // Auto-detect location once per mount as soon as the profile resolves
    // and we can confirm it has no saved coordinates.
    ref.listen(fullProfileProvider, (_, next) {
      if (_locationAutoDetectTried) return;
      final profile = next.asData?.value;
      if (profile == null) return;
      if (profile.latitude != null && profile.longitude != null) {
        _locationAutoDetectTried = true;
        return;
      }
      _locationAutoDetectTried = true;
      LocationService.detectAndSaveForCurrentUser(ref);
    });

    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final currentIndex = ref.watch(selectedTabProvider);

    final isReels = currentIndex == 1;

    ref.listen<AsyncValue<void>>(waveUploadProvider, (prev, next) {
      if (prev is AsyncLoading && next is AsyncData) {
        ref.invalidate(wavesProvider);
        setState(() {
          _showSuccessBanner = true;
          _uploadError = null;
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showSuccessBanner = false);
        });
      } else if (prev is AsyncLoading && next is AsyncError) {
        setState(() {
          _uploadError = next.error.toString();
          _showSuccessBanner = false;
        });
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (currentIndex != 0) {
          ref.read(selectedTabProvider.notifier).setTab(0);
        } else {
          _showExitDialog(context);
        }
      },
      child: Scaffold(
      key: ref.watch(mainScaffoldKeyProvider),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          IndexedStack(index: currentIndex, children: _screens),

          // ── Profile completion banner (home tab only) ─────────────
          if (currentIndex == 0 && !_profileBannerDismissed)
            Positioned(
              left: 16,
              right: 16,
              top: MediaQuery.of(context).padding.top + 12,
              child: ProfileCompletionBanner(
                onDismiss: () =>
                    setState(() => _profileBannerDismissed = true),
              ),
            ),

          // ── Upload progress banner ────────────────────────────────
          _buildUploadBanner(colors),

          // ── One unified bottom bar ─────────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            left: isReels ? 0 : 20,
            right: isReels ? 0 : 20,
            bottom: isReels ? 0 : 24,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
              height: isReels ? 64 + bottomPadding : 64,
              padding: EdgeInsets.only(bottom: isReels ? bottomPadding : 0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(isReels ? 0 : 32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isReels ? 0.15 : 0.1,
                    ),
                    blurRadius: isReels ? 10 : 20,
                    offset: Offset(0, isReels ? -2 : 10),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Nav icons take up available space
                  Expanded(
                    child: _buildNavItem(
                      colors, 0, Icons.home_rounded, Icons.home_outlined,
                    ),
                  ),
                  Expanded(
                    child: _buildNavItem(
                      colors, 1, Icons.video_library_rounded, Icons.video_library_outlined,
                    ),
                  ),
                  Expanded(
                    child: _buildNavItem(
                      colors, 2, Icons.search_rounded, Icons.search_outlined,
                    ),
                  ),
                  Expanded(
                    child: _buildNavItem(
                      colors, 3, Icons.person_rounded, Icons.person_outline_rounded,
                    ),
                  ),
                  // Add button sitting inside the bar on the right
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => context.push('/upload-wave'),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [colors.primary, colors.accent],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Future<void> _showExitDialog(BuildContext context) async {
    final colors = ref.read(appColorSchemeProvider);
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Exit App', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: colors.primary),
            child: const Text('Exit', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (shouldExit == true) {
      SystemNavigator.pop();
    }
  }

  Widget _buildUploadBanner(AppColorScheme colors) {
    final uploadState = ref.watch(waveUploadProvider);
    final progress = ref.watch(uploadProgressProvider);
    final stage = ref.watch(uploadStageProvider);
    final isUploading = uploadState is AsyncLoading;

    final visible = isUploading || _showSuccessBanner || _uploadError != null;
    if (!visible) return const SizedBox.shrink();

    final isSuccess = _showSuccessBanner;
    final isError = _uploadError != null;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 104,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          color: isError
              ? const Color(0xFFB00020)
              : isSuccess
                  ? const Color(0xFF1B8C4E)
                  : const Color(0xFF1E1E1E),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: isError
                ? Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _uploadError!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _uploadError = null),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white70, size: 18),
                      ),
                    ],
                  )
                : isSuccess
                    ? const Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Wave uploaded! It will be ready shortly.',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(
                                stage == UploadStage.compressing
                                    ? Icons.compress_rounded
                                    : Icons.upload_rounded,
                                color: Colors.white70,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  stage == UploadStage.compressing
                                      ? progress > 0
                                          ? 'Compressing...  ${(progress * 100).toInt()}%'
                                          : 'Compressing your Wave...'
                                      : progress >= 1.0
                                          ? 'Finalizing your Wave...'
                                          : progress > 0
                                              ? 'Uploading your Wave...  ${(progress * 100).toInt()}%'
                                              : 'Uploading your Wave...',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (progress > 0 && progress < 1.0)
                                  ? progress
                                  : null,
                              minHeight: 3,
                              backgroundColor: Colors.white12,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    AppColorScheme colors,
    int index,
    IconData selectedIcon,
    IconData unselectedIcon,
  ) {
    final isSelected = ref.watch(selectedTabProvider) == index;

    return GestureDetector(
      onTap: () => ref.read(selectedTabProvider.notifier).setTab(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 52,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(
              isSelected ? selectedIcon : unselectedIcon,
              key: ValueKey(isSelected),
              color: isSelected ? colors.primary : Colors.grey.shade500,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
