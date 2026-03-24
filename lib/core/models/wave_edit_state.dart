import 'package:flutter/material.dart';

enum WaveFilter { none, vivid, warm, cool, fade, noir, drama }

extension WaveFilterExt on WaveFilter {
  String get label => switch (this) {
        WaveFilter.none => 'Normal',
        WaveFilter.vivid => 'Vivid',
        WaveFilter.warm => 'Warm',
        WaveFilter.cool => 'Cool',
        WaveFilter.fade => 'Fade',
        WaveFilter.noir => 'B&W',
        WaveFilter.drama => 'Drama',
      };

  // 4x5 color matrix (20 values, row-major: R, G, B, A rows)
  List<double>? get colorMatrix => switch (this) {
        WaveFilter.none => null,
        WaveFilter.vivid => [
            1.4, 0, 0, 0, -0.15, 0, 1.4, 0, 0, -0.15, 0, 0, 1.4, 0, -0.15, 0, 0, 0, 1, 0
          ],
        WaveFilter.warm => [
            1.2, 0, 0, 0, 0, 0, 1.05, 0, 0, 0, 0, 0, 0.75, 0, 0, 0, 0, 0, 1, 0
          ],
        WaveFilter.cool => [
            0.8, 0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 0, 1.3, 0, 0, 0, 0, 0, 1, 0
          ],
        WaveFilter.fade => [
            0.75, 0, 0, 0, 0.08, 0, 0.75, 0, 0, 0.08, 0, 0, 0.75, 0, 0.08, 0, 0, 0, 1, 0
          ],
        WaveFilter.noir => [
            0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0, 0, 0, 1, 0
          ],
        WaveFilter.drama => [
            1.5, 0, 0, 0, -0.3, 0, 1.5, 0, 0, -0.3, 0, 0, 1.5, 0, -0.3, 0, 0, 0, 1, 0
          ],
      };

  ColorFilter? get flutterColorFilter {
    final m = colorMatrix;
    if (m == null) return null;
    return ColorFilter.matrix(m);
  }
}

class WaveEditState {
  final String videoPath;
  final Duration videoDuration;
  final Duration trimStart;
  final Duration trimEnd;
  final WaveFilter filter;

  const WaveEditState({
    required this.videoPath,
    required this.videoDuration,
    required this.trimStart,
    required this.trimEnd,
    this.filter = WaveFilter.none,
  });

  WaveEditState copyWith({
    Duration? trimStart,
    Duration? trimEnd,
    WaveFilter? filter,
  }) =>
      WaveEditState(
        videoPath: videoPath,
        videoDuration: videoDuration,
        trimStart: trimStart ?? this.trimStart,
        trimEnd: trimEnd ?? this.trimEnd,
        filter: filter ?? this.filter,
      );
}
