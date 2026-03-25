import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/wave.dart';
import '../services/wave_service.dart';
import 'auth_providers.dart';

enum UploadStage { compressing, uploading }

final uploadStageProvider =
    NotifierProvider<_UploadStageNotifier, UploadStage>(
  _UploadStageNotifier.new,
);

class _UploadStageNotifier extends Notifier<UploadStage> {
  @override
  UploadStage build() => UploadStage.compressing;

  void set(UploadStage stage) => state = stage;
}

/// 0.0–1.0 progress for the current stage (compress or upload).
final uploadProgressProvider =
    NotifierProvider<_UploadProgressNotifier, double>(
  _UploadProgressNotifier.new,
);

class _UploadProgressNotifier extends Notifier<double> {
  @override
  double build() => 0.0;

  void set(double value) => state = value;
}

final wavesProvider = FutureProvider<List<Wave>>((ref) async {
  final client = ref.watch(supabaseProvider);
  return WaveService(client).fetchWaves();
});

class WaveUploadNotifier extends Notifier<AsyncValue<void>> {
  late WaveService _service;
  late String _userId;

  @override
  AsyncValue<void> build() {
    _service = WaveService(ref.watch(supabaseProvider));
    _userId = ref.watch(currentUserIdProvider) ?? '';
    return const AsyncData(null);
  }

  Future<bool> upload(File video, String caption) async {
    ref.read(uploadStageProvider.notifier).set(UploadStage.compressing);
    ref.read(uploadProgressProvider.notifier).set(0.0);
    state = const AsyncLoading();

    state = await AsyncValue.guard(
      () => _service.uploadWave(
        video,
        caption,
        _userId,
        onCompressProgress: (p) {
          ref.read(uploadStageProvider.notifier).set(UploadStage.compressing);
          ref.read(uploadProgressProvider.notifier).set(p);
        },
        onUploadProgress: (p) {
          ref.read(uploadStageProvider.notifier).set(UploadStage.uploading);
          ref.read(uploadProgressProvider.notifier).set(p);
        },
      ),
    );
    return state is! AsyncError;
  }

  void reset() => state = const AsyncData(null);
}

final waveUploadProvider =
    NotifierProvider<WaveUploadNotifier, AsyncValue<void>>(
  WaveUploadNotifier.new,
);
