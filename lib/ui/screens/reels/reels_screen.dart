import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/theme_provider.dart';
import '../../widgets/app_cached_image.dart';

class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  final PageController _pageController = PageController();
  int _currentReelIndex = 0;

  // Dummy reels data
  final List<Map<String, dynamic>> _reels = [
    {
      'user': 0, // Index in dummyUsers
      'videoUrl': 'https://images.unsplash.com/photo-1551632811-561732d1e306?q=80&w=1000',
      'caption': 'Conquering new heights! 🏔️ #adventure #hiking',
      'likes': '2.4K',
      'comments': '186',
      'shares': '94',
    },
    {
      'user': 4,
      'videoUrl': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?q=80&w=1000',
      'caption': 'New song out now! What do you think? 🎸✨',
      'likes': '5.2K',
      'comments': '342',
      'shares': '218',
    },
    {
      'user': 6,
      'videoUrl': 'https://images.unsplash.com/photo-1542038784424-fa00ea147159?q=80&w=1000',
      'caption': 'Golden hour magic 📸 Perfect light for portraits!',
      'likes': '3.8K',
      'comments': '221',
      'shares': '157',
    },
    {
      'user': 2,
      'videoUrl': 'https://images.unsplash.com/photo-1513364776144-60967b0f800f?q=80&w=1000',
      'caption': 'Finding peace in every brushstroke 🎨',
      'likes': '1.9K',
      'comments': '128',
      'shares': '76',
    },
    {
      'user': 9,
      'videoUrl': 'https://images.unsplash.com/photo-1466637574441-749b8f19452f?q=80&w=1000',
      'caption': 'New fusion recipe! Swipe up for the full video 🍳',
      'likes': '4.1K',
      'comments': '298',
      'shares': '189',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _reels.length,
        onPageChanged: (index) {
          setState(() {
            _currentReelIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return _buildReelItem(_reels[index], colors);
        },
      ),
    );
  }

  Widget _buildReelItem(Map<String, dynamic> reel, AppColorScheme colors) {
    final user = AppConstants.dummyUsers[reel['user'] as int];

    return Stack(
      children: [
        // Background video/image
        Positioned.fill(
          child: AppCachedImage(
            imageUrl: reel['videoUrl'] as String,
            fit: BoxFit.cover,
            errorWidget: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primary.withValues(alpha: 0.3),
                    colors.accent.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Gradient overlays for readability
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.8),
                ],
                stops: const [0.0, 0.2, 0.6, 1.0],
              ),
            ),
          ),
        ),

        // Right action buttons
        Positioned(
          right: 12,
          bottom: 120,
          child: Column(
            children: [
              _buildActionButton(
                icon: Icons.favorite_rounded,
                label: reel['likes'] as String,
                colors: colors,
                isActive: true,
              ),
              const SizedBox(height: 24),
              _buildActionButton(
                icon: Icons.chat_bubble_rounded,
                label: reel['comments'] as String,
                colors: colors,
              ),
              const SizedBox(height: 24),
              _buildActionButton(
                icon: Icons.share_rounded,
                label: reel['shares'] as String,
                colors: colors,
              ),
              const SizedBox(height: 24),
              _buildActionButton(
                icon: Icons.more_vert_rounded,
                label: '',
                colors: colors,
              ),
            ],
          ),
        ),

        // Bottom user info and caption
        Positioned(
          left: 16,
          right: 80,
          bottom: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // User info row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [colors.primary, colors.accent],
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.black,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundImage: NetworkImage(user.avatarUrl),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      user.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.primary, colors.primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Follow',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Caption
              Text(
                reel['caption'] as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Hobby tags
              Wrap(
                spacing: 6,
                children: user.hobbies.take(2).map((hobby) {
                  final hobbyData = AppConstants.hobbies.firstWhere(
                    (h) => h['name'] == hobby,
                    orElse: () => {
                      'name': hobby,
                      'icon': '🎯',
                      'color': 0xFF6C63FF,
                    },
                  );
                  final hobbyIcon = hobbyData['icon'] as String;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(hobbyIcon, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          hobby,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        // Progress indicator
        SafeArea(
          child: Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: List.generate(_reels.length, (index) {
                  return Expanded(
                    child: Container(
                      height: 2.5,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index == _currentReelIndex
                            ? colors.primary
                            : Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required AppColorScheme colors,
    bool isActive = false,
  }) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(
                    colors: [colors.primary, colors.accent],
                  )
                : null,
            color: isActive ? null : Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
