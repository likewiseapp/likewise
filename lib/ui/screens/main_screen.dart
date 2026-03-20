import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/providers/navigation_providers.dart';
import '../../core/theme_provider.dart';
import 'explore_screen.dart';
import 'search_screen.dart';
import 'profile_screen.dart';
import 'reels_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final List<Widget> _screens = [
    const ExploreScreen(),
    const ReelsScreen(),
    const SearchScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final currentIndex = ref.watch(selectedTabProvider);

    final isReels = currentIndex == 1;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: currentIndex, children: _screens),

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
                      onTap: () {
                        // TODO: Handle add action
                      },
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
