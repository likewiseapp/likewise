import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppCachedImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const AppCachedImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      final fb = _fallback();
      if (borderRadius != null) {
        return ClipRRect(borderRadius: borderRadius!, child: fb);
      }
      return fb;
    }

    final image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, __) =>
          placeholder ??
          SizedBox(
            width: width,
            height: height,
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
          ),
      errorWidget: (_, __, ___) => _fallback(),
      memCacheWidth: _cacheSize(width),
      memCacheHeight: _cacheSize(height),
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _fallback() {
    return errorWidget ??
        Container(
          width: width,
          height: height,
          color: Colors.grey.shade300,
          child: Icon(Icons.person, color: Colors.grey.shade500, size: 24),
        );
  }

  // Downscale cached bitmaps to 2x the display size for memory savings
  int? _cacheSize(double? dimension) {
    if (dimension == null) return null;
    return (dimension * 2).toInt();
  }
}
