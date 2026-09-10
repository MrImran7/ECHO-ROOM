import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/progress.dart';

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
  final AudioPlayer _player = AudioPlayer();
  @override
  Future<void> play(String asset, double volume) =>
      _player.play(AssetSource(asset), volume: volume);
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> resume() => _player.resume();
  @override
  Future<void> loop() => _player.setReleaseMode(ReleaseMode.loop);
  @override
  Future<void> dispose() => _player.dispose();
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

class HapticsService {
  bool _enabled = true, _suspended = false, _disposed = false;
  int _generation = 0;
  bool get enabled => _enabled;
  set enabled(bool value) {
    _enabled = value;
    if (!value) _generation++;
  }

  bool get _available => _enabled && !_suspended && !_disposed;
  void cancelPending() {
    _generation++;
  }

  void suspend() {
    _suspended = true;
    cancelPending();
  }

  void resume() {
    if (!_disposed) _suspended = false;
  }

  void dispose() {
    _disposed = true;
    _generation++;
  }

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (kDebugMode) debugPrint('Haptics unavailable: $e');
    }
  }

  Future<void> correct() async {
    if (_available) await _safe(HapticFeedback.lightImpact);
  }

  Future<void> wrong() async {
    if (_available) await _safe(HapticFeedback.heavyImpact);
  }

  Future<void> timeout() async {
    if (_available) await _safe(HapticFeedback.mediumImpact);
  }

  Future<void> complete() async {
    if (_available) await _safe(HapticFeedback.selectionClick);
  }

  Future<void> celebrate() async {
    if (!_available) return;
    final generation = ++_generation;
    await _safe(HapticFeedback.selectionClick);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (_available && generation == _generation)
      await _safe(HapticFeedback.lightImpact);
  }
}
