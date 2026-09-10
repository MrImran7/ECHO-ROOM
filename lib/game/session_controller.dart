import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/config.dart';
import '../daily/daily_service.dart';
import '../models/progress.dart';
import '../services/audio_service.dart';
import '../services/progression_service.dart';
import 'session.dart';

final sessionProvider = NotifierProvider<SessionController, int>(
  SessionController.new,
);

class SessionController extends Notifier<int> {
  GameSession? game;
  Completion? completion;
  Completion? _pendingCompletion;
  String? error;
  bool _finishing = false, _starting = false;
  double _hudElapsed = 0, _checkpointElapsed = 0;
  int _lastCountdown = 4;
  bool _disposed = false;
  @override
  int build() {
    ref.onDispose(() => _disposed = true);
    return 0;
  }

  void _notify() {
    if (!_disposed) state++;
  }

  void ready() {
    game?.ready();
    _notify();
  }

  Future<void> start(int levelId, {bool daily = false}) async {
    if (_starting) throw StateError('A room is already opening.');
    _starting = true;
    try {
      await _start(levelId, daily: daily);
    } finally {
      _starting = false;
    }
  }

  Future<void> _start(int levelId, {bool daily = false}) async {
    final catalog = ref.read(catalogProvider).requireValue;
    await ref.read(profileProvider.notifier).refreshLives();
    final p = ref.read(profileProvider);
    final today = DateTime.now();
    if (daily)
      levelId = const LocalDailyChallengeSource().levelFor(
        today,
        catalog.levels.length,
      );
    if (p.activeSession != null)
      throw StateError('Resume or finish your current room first.');
    if (!daily && GameConfig.livesEnabled && p.lives <= 0)
      throw StateError(
        'Your next life is on its way. Daily Room is still available.',
      );
    if (!daily &&
        levelId > p.highestLevel &&
        !(GameConfig.debugTools && ref.read(debugProvider).unlockAll)) {
      throw StateError('Complete the previous room to unlock this one.');
    }
    final date = daily ? dateKey(today) : null;
    if (date != null && p.daily.containsKey(date))
      throw StateError('Today’s room has already been played.');
    final level = catalog.level(levelId);
    final s = GameSession(
      level: level,
      room: catalog.rooms[level.roomId]!,
      runId: DateTime.now().microsecondsSinceEpoch.toString(),
      dailyDate: date,
      skipCountdown:
          GameConfig.debugTools && ref.read(debugProvider).skipCountdown,
      skipObservation:
          GameConfig.debugTools && ref.read(debugProvider).skipObservation,
    );
    var next = p.patch({'activeSession': s.toJson()});
    if (date != null)
      next = next.patch({
        'daily': {
          ...p.daily.map((k, v) => MapEntry(k, v.toJson())),
          date: DailyRecord(levelId: levelId).toJson(),
        },
      });
    await ref.read(profileProvider.notifier).commit(next);
    _install(s);
    ref.read(analyticsProvider).log(daily ? 'daily_started' : 'game_started', {
      'level': levelId,
    });
    ref.read(analyticsProvider).log('level_started', {'level': levelId});
    ref.read(audioProvider).cue(SoundCue.menu);
  }

  void restore() {
    final saved = ref.read(profileProvider).activeSession;
    if (saved == null) return;
    final catalog = ref.read(catalogProvider).requireValue;
    final level = catalog.level(saved['levelId'] as int);
    final s = GameSession(
      level: level,
      room: catalog.rooms[level.roomId]!,
      runId: saved['runId'] as String,
      dailyDate: saved['dailyDate'] as String?,
      skipCountdown: saved['skipCountdown'] as bool? ?? false,
      skipObservation: saved['skipObservation'] as bool? ?? false,
    )..restore(saved);
    _install(s);
    if (s.finished) unawaited(_finish());
  }

  void _install(GameSession s) {
    game = s;
    completion = null;
    _pendingCompletion = null;
    error = null;
    _hudElapsed = 0;
    _checkpointElapsed = 0;
    _lastCountdown = 4;
    _notify();
  }

  void tick(double dt) {
    final s = game;
    if (_disposed || s == null || s.paused || s.finished) return;
    final previous = s.phase;
    s.advance(dt);
    if (s.phase == GamePhase.countdown &&
        s.remaining.ceil() != _lastCountdown) {
      _lastCountdown = s.remaining.ceil();
      ref.read(audioProvider).cue(SoundCue.countdown);
    }
    if (s.phase == GamePhase.flicker && previous != s.phase)
      ref.read(audioProvider).cue(SoundCue.flicker);
    if (s.lossReason == LossReason.timeout &&
        previous != GamePhase.timedOut && previous != GamePhase.lost) {
      ref.read(audioProvider).cue(SoundCue.timeout);
      unawaited(ref.read(hapticsProvider).timeout());
    }
    if (s.finished) {
      unawaited(_finish());
    }
    _hudElapsed += dt;
    _checkpointElapsed += dt;
    if (_hudElapsed >= GameConfig.hudInterval || previous != s.phase) {
      _hudElapsed = 0;
      _notify();
    }
    if (!s.finished &&
        (previous != s.phase ||
            _checkpointElapsed >= GameConfig.checkpointInterval)) {
      _checkpointElapsed = 0;
      unawaited(checkpoint());
    }
  }

  void tap(double x, double y, double padding) {
    final s = game;
    if (s == null) return;
    final result = s.tap(x, y, padding: padding);
    if (result == TapResult.ignored) return;
    final correct = result == TapResult.correct;
    ref.read(audioProvider).cue(correct ? SoundCue.correct : SoundCue.wrong);
    unawaited(
      correct
          ? ref.read(hapticsProvider).correct()
          : ref.read(hapticsProvider).wrong(),
    );
    _notify();
    if (s.finished) {
      unawaited(_finish());
    } else {
      unawaited(checkpoint());
    }
  }

  Future<void> hint() async {
    final s = game, p = ref.read(profileProvider);
    if (s == null || s.hints >= 3 || s.dailyDate != null) return;
    final cost = GameConfig.hintCosts[s.hints];
    if (p.hints < cost) {
      error = 'Not enough hints. First-time room completions earn two.';
      _notify();
      return;
    }
    if (!s.useHint()) return;
    error = null;
    ref.read(analyticsProvider).log('hint_used', {
      'level': s.level.levelId,
      'strength': s.hints,
    });
    try {
      await ref
          .read(profileProvider.notifier)
          .commit(
            p.patch({'hints': p.hints - cost, 'activeSession': s.toJson()}),
          );
    } catch (_) {
      error = 'Your hint is active, but saving failed. Pause and retry saving.';
    }
    _notify();
  }

  Future<void> checkpoint() async {
    final s = game;
    if (s == null || s.finished) return;
    try {
      await ref
          .read(profileProvider.notifier)
          .commit(
            ref.read(profileProvider).patch({'activeSession': s.toJson()}),
          );
      error = null;
    } catch (_) {
      error = 'Progress could not be saved. Pause and retry saving.';
      _notify();
    }
  }

  void pause() {
    final s = game;
    if (s == null || s.finished) return;
    s.pause();
    _notify();
    unawaited(checkpoint());
  }

  void resume() {
    final s = game;
    if (s == null) return;
    s.resume();
    _notify();
  }

  Future<void> abandon() async {
    final s = game;
    if (s == null || s.finished) return;
    s.abandon();
    if (s.finished) await _finish();
    _notify();
  }

  Future<void> retrySave() async {
    error = null;
    if (game?.finished ?? false) {
      await _finish();
    } else {
      await checkpoint();
    }
    _notify();
  }

  Future<void> _finish() async {
    final s = game;
    if (_disposed ||
        s == null ||
        !s.finished ||
        _finishing ||
        completion != null)
      return;
    _finishing = true;
    _pendingCompletion ??= completeSession(
      ref.read(profileProvider),
      s,
      DateTime.now(),
      ref.read(catalogProvider).requireValue.levels.length,
    );
    try {
      await ref
          .read(profileProvider.notifier)
          .commit(_pendingCompletion!.progress);
      if (_disposed) return;
      completion = _pendingCompletion;
      final won = s.phase == GamePhase.won;
      ref.read(analyticsProvider).log(
        won ? 'level_completed' : 'level_failed',
        {'level': s.level.levelId, 'score': completion!.score.total},
      );
      if (s.dailyDate != null)
        ref.read(analyticsProvider).log('daily_completed', {
          'date': s.dailyDate,
          'won': won,
        });
      for (final id in completion!.newAchievements) {
        ref.read(analyticsProvider).log('achievement_unlocked', {'id': id});
      }
      error = null;
    } catch (_) {
      error = 'Result is ready, but saving failed. Tap RETRY SAVE.';
    }
    _finishing = false;
    _notify();
  }
}
