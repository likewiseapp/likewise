import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_cached_image.dart';

/// Shows [url] fullscreen with pinch-to-zoom + tap/swipe to dismiss.
/// No-ops when [url] is null or empty.
Future<void> showAvatarPopup(BuildContext context, String? url) async {
  if (url == null || url.isEmpty) return;
  HapticFeedback.lightImpact();
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'avatar',
    barrierColor: Colors.black.withValues(alpha: 0.92),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => _AvatarPopup(url: url),
    transitionBuilder: (_, anim, _, child) {
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

class _AvatarPopup extends StatelessWidget {
  final String url;
  const _AvatarPopup({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ClipOval(
                    child: AppCachedImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
