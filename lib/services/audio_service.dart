import 'dart:async';

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

class LocalAudioService implements AudioService {
  UserSettings _settings = const UserSettings();
  final Map<SoundCue, AudioPlayer> _players = {};
  final AudioPlayer _music = AudioPlayer();
  Future<void> _musicQueue = Future.value();
  bool _started = false, _suspended = false, _disposed = false;
  Future<void> _safe(Future<void> Function() action) async {
    if (_disposed) return;
    try {
      await action();
    } catch (e) {
      if (kDebugMode) debugPrint('Audio unavailable: $e');
    }
  }

  @override
  void cue(SoundCue cue) {
    if (!_settings.sound || _suspended || _disposed) return;
    unawaited(
      _safe(() async {
        final player = _players.putIfAbsent(cue, AudioPlayer.new);
        await player.stop();
        if (_disposed || _suspended || !_settings.sound) return;
        await player.play(AssetSource('audio/${cue.name}.wav'), volume: .55);
      }),
    );
  }

  @override
  void configure(UserSettings settings) {
    _settings = settings;
    _syncMusic();
  }

  void _syncMusic() {
    _musicQueue = _musicQueue.then(
      (_) => _safe(() async {
        if (!_settings.music || _suspended) {
          await _music.pause();
          return;
        }
        if (!_started) {
          await _music.setReleaseMode(ReleaseMode.loop);
          if (_disposed || _suspended || !_settings.music) return;
          await _music.play(AssetSource('audio/ambient.wav'), volume: .15);
          _started = true;
        } else {
          await _music.resume();
        }
      }),
    );
  }

  @override
  void suspend() {
    _suspended = true;
    _syncMusic();
    for (final p in _players.values) {
      unawaited(_safe(p.pause));
    }
  }

  @override
  void resume() {
    _suspended = false;
    _syncMusic();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _musicQueue;
    for (final p in _players.values) {
      await p.dispose();
    }
    await _music.dispose();
  }
}

class HapticsService {
  bool enabled = true;
  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (kDebugMode) debugPrint('Haptics unavailable: $e');
    }
  }

  Future<void> correct() async {
    if (enabled) await _safe(HapticFeedback.lightImpact);
  }

  Future<void> wrong() async {
    if (enabled) await _safe(HapticFeedback.heavyImpact);
  }

  Future<void> celebrate() async {
    if (!enabled) return;
    await _safe(HapticFeedback.selectionClick);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (enabled) await _safe(HapticFeedback.lightImpact);
  }
}
