import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/wave.dart';
import '../models/wave_comment.dart';
import '../services/wave_engagement_service.dart';
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

/// When true, the wave feed only shows waves from posters who share
/// at least one hobby with the current user.
class _WaveHobbyFilterNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final waveHobbyFilterProvider =
    NotifierProvider<_WaveHobbyFilterNotifier, bool>(
  _WaveHobbyFilterNotifier.new,
);

final wavesProvider = FutureProvider<List<Wave>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final filterByHobby = ref.watch(waveHobbyFilterProvider);

  if (filterByHobby) {
    final userId = ref.read(currentUserIdProvider);
    if (userId != null) {
      final hobbies = await client
          .from('user_hobbies')
          .select('hobby_id')
          .eq('user_id', userId);
      final hobbyIds =
          (hobbies as List).map((e) => e['hobby_id'] as int).toList();
      if (hobbyIds.isNotEmpty) {
        return WaveService(client).fetchWavesByHobbies(hobbyIds);
      }
    }
  }

  return WaveService(client).fetchWaves();
});

/// Approved + transcoding-ready waves for a specific user, newest first.
/// Used by the profile screen's "My waves" section and (later) other
/// users' profiles.
final userWavesProvider =
    FutureProvider.family<List<Wave>, String>((ref, userId) async {
  final client = ref.watch(supabaseProvider);
  return WaveService(client).fetchWavesByUser(userId);
});

final waveEngagementServiceProvider = Provider<WaveEngagementService>((ref) {
  return WaveEngagementService(ref.watch(supabaseProvider));
});

/// Per-wave like state, stored in a single map and narrow-watched via
/// `.select` in the UI to avoid unrelated rebuilds.
class WaveLikeState {
  final bool liked;
  final int count;

  const WaveLikeState({required this.liked, required this.count});
}

class WaveLikesNotifier extends Notifier<Map<String, WaveLikeState>> {
  @override
  Map<String, WaveLikeState> build() => const {};

  WaveLikeState stateFor(String waveId) =>
      state[waveId] ?? const WaveLikeState(liked: false, count: 0);

  /// Hydrate from the server-side [Wave]. No-op when values already match.
  void seedFrom(Wave wave) {
    final current = state[wave.id];
    if (current != null &&
        current.liked == wave.viewerLiked &&
        current.count == wave.likeCount) {
      return;
    }
    state = {
      ...state,
      wave.id: WaveLikeState(liked: wave.viewerLiked, count: wave.likeCount),
    };
  }

  /// Optimistically toggle, call the service, roll back on failure.
  Future<void> toggle(String waveId) async {
    final prev = stateFor(waveId);
    final next = WaveLikeState(
      liked: !prev.liked,
      count: prev.liked
          ? (prev.count - 1).clamp(0, 1 << 31)
          : prev.count + 1,
    );
    state = {...state, waveId: next};

    try {
      await ref.read(waveEngagementServiceProvider).toggleLike(
            waveId,
            currentlyLiked: prev.liked,
          );
    } catch (_) {
      state = {...state, waveId: prev};
      rethrow;
    }
  }
}

final waveLikesProvider =
    NotifierProvider<WaveLikesNotifier, Map<String, WaveLikeState>>(
  WaveLikesNotifier.new,
);

/// Newest-first list of comments for a wave, refreshed whenever the
/// realtime stream on wave_comments fires for that wave. We use the stream
/// as a change-notifier only — the actual fetch goes through the service so
/// author profiles get merged in (the stream itself can't embed profiles).
final waveCommentsProvider =
    StreamProvider.family<List<WaveComment>, String>((ref, waveId) async* {
  final client = ref.watch(supabaseProvider);
  final service = ref.watch(waveEngagementServiceProvider);

  yield await service.fetchComments(waveId);

  await for (final _ in client
      .from('wave_comments')
      .stream(primaryKey: ['id'])
      .eq('wave_id', waveId)
      .skip(1)) {
    yield await service.fetchComments(waveId);
  }
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
