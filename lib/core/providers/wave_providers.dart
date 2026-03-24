import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/wave.dart';
import '../services/wave_service.dart';
import 'auth_providers.dart';

/// 0.0–1.0 progress for the Bunny upload step. Reset to 0 on each new upload.
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
    ref.read(uploadProgressProvider.notifier).set(0.0);
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _service.uploadWave(
        video,
        caption,
        _userId,
        onProgress: (p) =>
            ref.read(uploadProgressProvider.notifier).set(p),
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
