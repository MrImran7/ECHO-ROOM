import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../levels/catalog.dart';
import '../models/progress.dart';
import '../services/ad_service.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/lives_service.dart';
import '../storage/progress_repository.dart';

final repositoryProvider = Provider<ProgressRepository>(
  (ref) => LocalProgressRepository(),
);
final catalogProvider = FutureProvider<GameCatalog>(
  (ref) => GameCatalog.load(),
);
final savedProgressProvider = FutureProvider<Progress>(
  (ref) => ref.read(repositoryProvider).load(),
);
final analyticsProvider = Provider<AnalyticsService>(
  (ref) => DebugAnalyticsService(),
);
final adProvider = Provider<AdService>((ref) => MockAdService());
final audioProvider = Provider<AudioService>((ref) {
  final audio = LocalAudioService();
  ref.onDispose(() => unawaited(audio.dispose()));
  return audio;
});
final hapticsProvider = Provider<HapticsService>((ref) => HapticsService());
final profileProvider = NotifierProvider<ProfileController, Progress>(
  ProfileController.new,
);

class ProfileController extends Notifier<Progress> {
  String? saveError;
  @override
  Progress build() => const LivesService().refresh(
    ref.watch(savedProgressProvider).requireValue,
    DateTime.now(),
  );
  Future<void> commit(Progress value) async {
    state = value;
    try {
      await ref.read(repositoryProvider).save(value);
      saveError = null;
    } catch (_) {
      saveError = 'Progress could not be saved. Please retry.';
      rethrow;
    }
  }

  Future<void> retrySave() => commit(state);
  Future<void> refreshLives() async {
    final next = const LivesService().refresh(state, DateTime.now());
    if (next.lives != state.lives || next.lifeAnchor != state.lifeAnchor)
      await commit(next);
  }

  Future<void> settings(UserSettings settings) async {
    ref.read(audioProvider).configure(settings);
    ref.read(hapticsProvider).enabled = settings.haptics;
    await commit(state.patch({'settings': settings.toJson()}));
  }

  Future<void> reset() =>
      commit(Progress().patch({'settings': state.settings.toJson()}));
}

final debugProvider = NotifierProvider<DebugController, DebugOptions>(
  DebugController.new,
);

class DebugOptions {
  const DebugOptions({
    this.unlockAll = false,
    this.skipObservation = false,
    this.skipCountdown = false,
    this.hitboxes = false,
  });
  final bool unlockAll, skipObservation, skipCountdown, hitboxes;
}

class DebugController extends Notifier<DebugOptions> {
  @override
  DebugOptions build() => const DebugOptions();
  void update({
    bool? unlockAll,
    bool? skipObservation,
    bool? skipCountdown,
    bool? hitboxes,
  }) {
    state = DebugOptions(
      unlockAll: unlockAll ?? state.unlockAll,
      skipObservation: skipObservation ?? state.skipObservation,
      skipCountdown: skipCountdown ?? state.skipCountdown,
      hitboxes: hitboxes ?? state.hitboxes,
    );
  }
}
