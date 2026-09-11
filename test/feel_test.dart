import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_room/core/config.dart';
import 'package:echo_room/game/feedback_motion.dart';
import 'package:echo_room/game/session.dart';
import 'package:echo_room/models/progress.dart';
import 'package:echo_room/services/audio_service.dart';

import 'test_support.dart';

class RecordingChannel implements AudioChannel {
  final events = <String>[];
  Completer<void>? pendingPlay;
  @override
  Future<void> play(String asset, double volume) async {
    events.add('play:$asset:$volume');
    await pendingPlay?.future;
  }

  @override
  Future<void> stop() async {
    events.add('stop');
  }

  @override
  Future<void> pause() async {
    events.add('pause');
  }

  @override
  Future<void> resume() async {
    events.add('resume');
  }

  @override
  Future<void> loop() async {
    events.add('loop');
  }

  @override
  Future<void> dispose() async {
    events.add('dispose');
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'correct tap locks input and feedback completes at its configured boundary',
    () {
      final s = session();
      reachAnswer(s);
      final target = s.original.object('lamp');
      expect(s.tap(target.x, target.y), TapResult.correct);
      expect(s.tap(target.x, target.y), TapResult.ignored);
      s.advance(GameConfig.correctFeedbackSeconds - .01);
      expect(s.phase, GamePhase.correct);
      s.advance(.01);
      expect(s.phase, GamePhase.won);
    },
  );

  test('wrong taps cannot stack feedback and timeout wins at the boundary', () {
    final s = session();
    reachAnswer(s);
    final wrong = s.original.object('painting');
    expect(s.tap(wrong.x, wrong.y), TapResult.wrong);
    for (var i = 0; i < 10; i++) {
      expect(s.tap(wrong.x, wrong.y), TapResult.ignored);
    }
    expect(s.mistakes, 1);
    s.advance(GameConfig.wrongFeedbackSeconds);
    expect(s.phase, GamePhase.answering);
    s.advance(s.remaining);
    final target = s.original.object('lamp');
    expect(s.tap(target.x, target.y), TapResult.ignored);
    expect(s.phase, GamePhase.timedOut);
    expect(s.revealAnswer, true);
  });

  test('a correct tap before the deadline cannot become a timeout', () {
    final s = session();
    reachAnswer(s);
    s.advance(s.remaining - .01);
    final target = s.original.object('lamp');
    expect(s.tap(target.x, target.y), TapResult.correct);
    s.advance(10);
    expect(s.phase, GamePhase.won);
    expect(s.lossReason, isNull);
  });

  for (final phase in [
    GamePhase.countdown,
    GamePhase.flicker,
    GamePhase.observing,
    GamePhase.blackout,
    GamePhase.answering,
    GamePhase.correct,
    GamePhase.incorrect,
    GamePhase.timedOut,
  ]) {
    test(
      'pause/resume preserves $phase without background time or duplicate transitions',
      () {
        final s = session();
        if ([
          GamePhase.correct,
          GamePhase.incorrect,
          GamePhase.timedOut,
        ].contains(phase)) {
          reachAnswer(s);
          if (phase == GamePhase.timedOut) {
            s.advance(s.remaining);
          } else {
            final o = s.original.object(
              phase == GamePhase.correct ? 'lamp' : 'painting',
            );
            s.tap(o.x, o.y);
          }
        } else {
          while (s.phase != phase) {
            s.advance(.01);
          }
        }
        final before = s.toJson();
        s.pause();
        s.pause();
        s.advance(60);
        expect(s.tap(.1, .1), TapResult.ignored);
        expect(s.toJson(), before);
        s.resume();
        s.resume();
        expect(s.phase, phase);
        expect(s.toJson(), before);
      },
    );
  }

  test('motion settles quickly and reduced motion removes pulses', () {
    expect(FeedbackMotion.correctScale(.15), greaterThan(1));
    expect(FeedbackMotion.correctScale(.5), closeTo(1, .000001));
    expect(FeedbackMotion.wrongOffset(.3), 0);
    expect(FeedbackMotion.correctScale(.15, reduced: true), 1);
    expect(FeedbackMotion.wrongOffset(.1, reduced: true), 0);
    expect(FeedbackMotion.darkness(0), 0);
    expect(FeedbackMotion.darkness(1), 1);
    expect(FeedbackMotion.darkness(.5, reduced: true), .5);
  });

  test(
    'sound toggle stops active playback and invalidates queued effects',
    () async {
      final channels = <RecordingChannel>[];
      final audio = LocalAudioService(
        createChannel: () {
          final channel = RecordingChannel();
          channels.add(channel);
          return channel;
        },
      );
      audio.configure(const UserSettings(music: false));
      audio.cue(SoundCue.correct);
      await flush();
      expect(
        channels.first.events.where((e) => e.startsWith('play:')).length,
        1,
      );
      audio.cue(SoundCue.wrong);
      audio.configure(const UserSettings(music: false, sound: false));
      await flush();
      expect(channels.first.events.last, 'stop');
      expect(
        channels.first.events.where((e) => e.startsWith('play:')).length,
        1,
      );
      audio.cue(SoundCue.complete);
      await flush();
      expect(
        channels.first.events.where((e) => e.startsWith('play:')).length,
        1,
      );
      audio.configure(const UserSettings(music: false));
      audio.cue(SoundCue.timeout);
      await flush();
      expect(channels.first.events.last, 'play:audio/wrong.wav:0.3');
      await audio.dispose();
    },
  );

  test(
    'rapid cues use one channel and suspend never replays stale effects',
    () async {
      final channels = <RecordingChannel>[];
      final audio = LocalAudioService(
        createChannel: () {
          final channel = RecordingChannel();
          channels.add(channel);
          return channel;
        },
      );
      audio.configure(const UserSettings(music: false));
      audio.cue(SoundCue.wrong);
      audio.cue(SoundCue.correct);
      await flush();
      expect(
        channels.first.events.where((e) => e.startsWith('play:')).toList(),
        ['play:audio/correct.wav:0.55'],
      );
      audio.suspend();
      audio.cue(SoundCue.complete);
      await flush();
      expect(channels.first.events.last, 'stop');
      audio.resume();
      await flush();
      expect(channels.first.events.last, 'stop');
      await audio.dispose();
      audio.cue(SoundCue.correct);
      expect(channels.first.events.last, 'dispose');
    },
  );

  test(
    'dispose waits for pending playback before releasing channels',
    () async {
      final channels = <RecordingChannel>[];
      final audio = LocalAudioService(
        createChannel: () {
          final channel = RecordingChannel();
          channels.add(channel);
          return channel;
        },
      );
      channels.first.pendingPlay = Completer<void>();
      audio.cue(SoundCue.correct);
      await flush();
      final disposed = audio.dispose();
      expect(channels.first.events, isNot(contains('dispose')));
      channels.first.pendingPlay!.complete();
      await disposed;
      expect(channels.first.events.last, 'dispose');
    },
  );

  test('music responds immediately to settings and background state', () async {
    final channels = <RecordingChannel>[];
    final audio = LocalAudioService(
      createChannel: () {
        final channel = RecordingChannel();
        channels.add(channel);
        return channel;
      },
    );
    audio.configure(const UserSettings());
    await flush();
    expect(channels.last.events, contains('play:audio/ambient.wav:0.15'));
    audio.configure(const UserSettings(music: false));
    await flush();
    expect(channels.last.events.last, 'pause');
    audio.configure(const UserSettings());
    await flush();
    expect(channels.last.events.last, 'resume');
    audio.suspend();
    await flush();
    expect(channels.last.events.last, 'pause');
    await audio.dispose();
  });

  testWidgets(
    'haptics respect disable, interruption and disposal mid-pattern',
    (tester) async {
      final calls = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate')
            calls.add(call.arguments);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final haptics = HapticsService(platform: TargetPlatform.iOS)..enabled = false;
      await haptics.correct();
      await haptics.wrong();
      await haptics.timeout();
      await haptics.complete();
      await haptics.celebrate();
      expect(calls, isEmpty);
      haptics.enabled = true;
      await haptics.correct();
      await haptics.wrong();
      await haptics.timeout();
      expect(calls, [
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
        'HapticFeedbackType.mediumImpact',
      ]);
      final pattern = haptics.celebrate();
      await tester.pump();
      haptics.suspend();
      await tester.pump(const Duration(milliseconds: 100));
      await pattern;
      expect(calls.length, 4);
      haptics.resume();
      final next = haptics.celebrate();
      await tester.pump();
      haptics.dispose();
      await tester.pump(const Duration(milliseconds: 100));
      await next;
      expect(calls.length, 5);
      await haptics.correct();
      expect(calls.length, 5);
    },
  );
  test('pause just before timeout preserves the final answer opportunity', () {
    final s = session();
    reachAnswer(s);
    s.advance(s.remaining - .01);
    s.pause();
    s.advance(100);
    s.resume();
    final lamp = s.original.object('lamp');
    expect(s.tap(lamp.x, lamp.y), TapResult.correct);
  });

  test(
    'audio platform failure does not poison future cues or disposal',
    () async {
      final channel = FailingChannel();
      final audio = LocalAudioService(createChannel: () => channel);
      audio.cue(SoundCue.correct);
      await flush();
      channel.fail = false;
      audio.cue(SoundCue.wrong);
      await flush();
      expect(channel.events, contains('play:audio/wrong.wav:0.55'));
      await audio.dispose();
    },
  );

  testWidgets(
    'correct haptic replaces a delayed pattern; unavailable platform is harmless',
    (tester) async {
      final calls = <Object?>[];
      var fail = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            if (fail) throw PlatformException(code: 'unavailable');
            calls.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final haptics = HapticsService(platform: TargetPlatform.iOS);
      final pattern = haptics.celebrate();
      await tester.pump();
      await haptics.correct();
      await tester.pump(const Duration(milliseconds: 100));
      await pattern;
      expect(calls, [
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.mediumImpact',
      ]);
      fail = true;
      await haptics.wrong();
      fail = false;
      haptics.enabled = false;
      await haptics.correct();
      expect(calls.length, 2);
      haptics.enabled = true;
      await haptics.correct();
      expect(calls.length, 3);
      haptics.dispose();
    },
  );
}

class FailingChannel extends RecordingChannel {
  bool fail = true;
  @override
  Future<void> play(String asset, double volume) async {
    if (fail) throw PlatformException(code: 'missing_asset');
    await super.play(asset, volume);
  }
}
