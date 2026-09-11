import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/progress.dart';
import '../core/config.dart';

enum SoundCue {
  menu,
  countdown,
  flicker,
  correct,
  wrong,
  timeout,
  streak,
  complete,
  mystery,
}

abstract interface class AudioService {
  void cue(SoundCue cue);
  void configure(UserSettings settings);
  void suspend();
  void resume();
  Future<void> dispose();
}

/// Small injectable boundary for platform playback and deterministic service tests.
abstract interface class AudioChannel {
  Future<void> play(String asset, double volume);
  Future<void> stop();
  Future<void> pause();
  Future<void> resume();
  Future<void> loop();
  Future<void> dispose();
}

class _PlatformChannel implements AudioChannel {
  AudioPlayer? _player;
  AudioPlayer get _active => _player ??= AudioPlayer();
  @override
  Future<void> play(String asset, double volume) =>
      _active.play(AssetSource(asset), volume: volume);
  @override
  Future<void> stop() => _player?.stop() ?? Future.value();
  @override
  Future<void> pause() => _player?.pause() ?? Future.value();
  @override
  Future<void> resume() => _player?.resume() ?? Future.value();
  @override
  Future<void> loop() => _active.setReleaseMode(ReleaseMode.loop);
  @override
  Future<void> dispose() => _player?.dispose() ?? Future.value();
}

class LocalAudioService implements AudioService {
  LocalAudioService({AudioChannel Function()? createChannel})
    : _effects = (createChannel ?? _PlatformChannel.new)(),
      _music = (createChannel ?? _PlatformChannel.new)();
  UserSettings _settings = const UserSettings();
  final AudioChannel _effects, _music;
  Future<void> _effectQueue = Future.value(), _musicQueue = Future.value();
  bool _started = false, _suspended = false, _disposed = false;
  int _generation = 0;
  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (kDebugMode) debugPrint('Audio unavailable: $e');
    }
  }

  @override
  void cue(SoundCue cue) {
    if (!_settings.sound || _suspended || _disposed) return;
    final generation = ++_generation;
    _effectQueue = _effectQueue.then(
      (_) => _safe(() async {
        if (_disposed || generation != _generation) return;
        await _effects.stop();
        if (_disposed ||
            _suspended ||
            !_settings.sound ||
            generation != _generation)
          return;
        // Reuse the original subdued negative tone; no new asset is required.
        final asset = cue == SoundCue.timeout ? 'wrong' : cue.name;
        await _effects.play(
          'audio/$asset.wav',
          cue == SoundCue.timeout ? .3 : .55,
        );
      }),
    );
  }

  void _stopEffects() {
    ++_generation;
    _effectQueue = _effectQueue.then((_) => _safe(_effects.stop));
  }

  @override
  void configure(UserSettings settings) {
    if (_disposed) return;
    _settings = settings;
    if (!settings.sound) _stopEffects();
    _syncMusic();
  }

  void _syncMusic() {
    _musicQueue = _musicQueue.then(
      (_) => _safe(() async {
        if (_disposed) return;
        if (!_settings.music || _suspended) {
          await _music.pause();
          return;
        }
        if (!_started) {
          await _music.loop();
          if (_disposed || _suspended || !_settings.music) return;
          await _music.play('audio/ambient.wav', .15);
          _started = true;
        } else {
          await _music.resume();
        }
      }),
    );
  }

  @override
  void suspend() {
    if (_disposed || _suspended) return;
    _suspended = true;
    _stopEffects();
    _syncMusic();
  }

  @override
  void resume() {
    if (_disposed) return;
    _suspended = false;
    _syncMusic();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    await Future.wait([_effectQueue, _musicQueue]);
    await _safe(_effects.dispose);
    await _safe(_music.dispose);
  }
}

enum HapticProbe { light, medium, generic }

class HapticsService {
  HapticsService({TargetPlatform? platform})
    : _platform = platform ?? defaultTargetPlatform;
  final TargetPlatform _platform;
  final Stopwatch _wrongCooldown = Stopwatch();
  bool _enabled = true, _suspended = false, _disposed = false;
  int _generation = 0;
  bool get enabled => _enabled;
  set enabled(bool value) {
    _enabled = value;
    if (!value) {
      cancelPending();
      _wrongCooldown.stop();
      _wrongCooldown.reset();
    }
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('HAPTIC $message');
  }

  bool _allowed(String event) {
    final reason = _disposed ? 'disposed' : !_enabled ? 'disabled' :
        _suspended ? 'lifecycle suspended' : null;
    if (reason == null) return true;
    _log('suppressed: $event / $reason');
    return false;
  }

  void cancelPending() => _generation++;

  void suspend() {
    _suspended = true;
    cancelPending();
    _wrongCooldown.stop();
    _wrongCooldown.reset();
  }

  void resume() {
    if (_disposed) return;
    _suspended = false;
    _log('resumed');
  }

  void dispose() {
    _disposed = true;
    cancelPending();
    _wrongCooldown.stop();
  }

  Future<void> _dispatch(String event, String api,
      Future<void> Function() action, int generation) async {
    if (!_allowed(event)) return;
    if (generation != _generation) {
      _log('suppressed: $event / superseded');
      return;
    }
    _log('dispatch: $event / $api / ${_platform.name}');
    try {
      await action();
    } catch (e) {
      _log('unavailable: $event / $e');
    }
  }

  // Flutter's Future<void> cannot detect an OEM no-op or OS suppression.
  // Select LONG_PRESS up front on Android, never impact + generic together.
  // This stays on View feedback, respecting system preferences without a
  // VIBRATE permission or a custom native vibrator implementation.
  Future<void> _gameplay(String event, String iosApi,
      Future<void> Function() iosAction, int generation) => _dispatch(
    event,
    _platform == TargetPlatform.android ? 'vibrate (LONG_PRESS)' : iosApi,
    _platform == TargetPlatform.android ? HapticFeedback.vibrate : iosAction,
    generation,
  );

  Future<void> correct() async {
    cancelPending();
    // Success always supersedes a pending negative pattern/cooldown.
    _wrongCooldown.stop();
    _wrongCooldown.reset();
    await _gameplay('correct', 'mediumImpact', HapticFeedback.mediumImpact, _generation);
  }

  Future<void> wrong() async {
    if (!_allowed('wrong')) return;
    if (_wrongCooldown.isRunning &&
        _wrongCooldown.elapsedMilliseconds < (GameConfig.tapCooldown * 1000).round()) {
      _log('suppressed: wrong / cooldown');
      return;
    }
    _wrongCooldown..reset()..start();
    final generation = ++_generation;
    await _gameplay('wrong', 'heavyImpact', HapticFeedback.heavyImpact, generation);
    // Android uses a deliberate two-beat negative signal, not two fallback APIs.
    if (_platform == TargetPlatform.android) {
      await Future<void>.delayed(const Duration(milliseconds: GameConfig.hapticPatternGapMilliseconds));
      await _gameplay('wrong second beat', 'heavyImpact', HapticFeedback.heavyImpact, generation);
    }
  }

  Future<void> timeout() async {
    cancelPending();
    await _gameplay('timeout', 'mediumImpact', HapticFeedback.mediumImpact, _generation);
  }

  Future<void> complete() async {
    cancelPending();
    await _gameplay('complete', 'selectionClick', HapticFeedback.selectionClick, _generation);
  }

  Future<void> celebrate() async {
    if (!_allowed('celebrate')) return;
    final generation = ++_generation;
    await _gameplay('celebrate', 'selectionClick', HapticFeedback.selectionClick, generation);
    await Future<void>.delayed(const Duration(milliseconds: GameConfig.hapticPatternGapMilliseconds));
    await _gameplay('celebrate second beat', 'lightImpact', HapticFeedback.lightImpact, generation);
  }

  /// Raw API probes use the same settings/lifecycle guards as gameplay.
  Future<void> debugProbe(HapticProbe probe) async {
    if (!kDebugMode) return;
    cancelPending();
    switch (probe) {
      case HapticProbe.light:
        await _dispatch('test light', 'lightImpact', HapticFeedback.lightImpact, _generation);
      case HapticProbe.medium:
        await _dispatch('test medium', 'mediumImpact', HapticFeedback.mediumImpact, _generation);
      case HapticProbe.generic:
        await _dispatch('test generic', 'vibrate', HapticFeedback.vibrate, _generation);
    }
  }
}
