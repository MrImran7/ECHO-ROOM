import 'package:flutter_test/flutter_test.dart';
import 'package:echo_room/core/config.dart';
import 'package:echo_room/game/session.dart';
import 'package:echo_room/game/hit_test.dart';
import 'package:echo_room/models/scene.dart';
import 'test_support.dart';
void main() {
  test('full deterministic observation-to-blackout-to-answer flow', () {
    final s = session();
    s.advance(GameConfig.introSeconds); expect(s.phase, GamePhase.countdown);
    s.advance(GameConfig.countdownSeconds); expect(s.phase, GamePhase.observing);
    s.advance(s.level.observationDuration); expect(s.phase, GamePhase.flicker);
    s.advance(GameConfig.flickerSeconds); expect(s.phase, GamePhase.blackout);
    s.advance(GameConfig.blackoutSeconds); expect(s.phase, GamePhase.answering);
    expect(s.changed.object('lamp').visible, false);
    expect(s.original.object('lamp').visible, true);
    expect(s.answerElapsed, closeTo(0, .00001));
  });
  test('removed lamp hitbox remains interactive and double tap is ignored', () {
    final s = session(); reachAnswer(s);
    final lamp = s.original.object('lamp');
    expect(s.tap(lamp.x, lamp.y), TapResult.correct);
    expect(s.tap(lamp.x, lamp.y), TapResult.ignored);
  });
  test('wrong tap uses an attempt; rapid second tap does not', () {
    final s = session(); reachAnswer(s);
    expect(s.tap(.31, .23), TapResult.wrong); expect(s.mistakes, 1);
    expect(s.tap(.31, .23), TapResult.ignored); expect(s.mistakes, 1);
    s.advance(.4); expect(s.tap(.31, .23), TapResult.wrong);
    expect(s.phase, GamePhase.incorrect);
    s.advance(.4); expect(s.tap(.31, .23), TapResult.failed);
  });
  test('empty-space tap is harmless', () {
    final s = session(); reachAnswer(s);
    expect(s.tap(.99, .01), TapResult.ignored); expect(s.mistakes, 0);
  });
  test('background pause cannot lose time; restore requires explicit resume', () {
    final s = session(); reachAnswer(s); s.advance(.8); s.pause();
    final time = s.answerElapsed;
    s.advance(1000); expect(s.answerElapsed, time); expect(s.phase, GamePhase.paused);
    final restored = session()..restore(s.toJson());
    expect(restored.paused, true); expect(restored.answerElapsed, time);
    restored.advance(20); expect(restored.phase, GamePhase.paused);
    restored.resume(); restored.advance(10); expect(restored.phase, GamePhase.lost);
  });
  test('a long frame carries over phase boundaries without extending timers', () {
    final s = session(); s.advance(100); expect(s.phase, GamePhase.lost);
    expect(s.answerElapsed, closeTo(s.level.answerDuration, .001));
  });
  test('all 20 content levels have a visible change and a hittable target', () {
    final catalog = loadCatalog(); catalog.validate(); expect(catalog.levels.length, 20);
    for (final level in catalog.levels) {
      final s = session(level: level.levelId);
      expect(s.original.objects.map((o) => o.toJson()).toList(), isNot(s.changed.objects.map((o) => o.toJson()).toList()));
      win(s); expect(s.phase, GamePhase.won, reason: 'Level ${level.levelId}');
    }
  });
  test('moved and swapped objects accept both original and new locations', () {
    for (final id in [2, 3, 9]) {
      final s = session(level: id);
      for (final target in s.level.targets) {
        for (final o in [s.original.object(target), s.changed.object(target)]) {
          expect(s.level.targets.contains(detectObject(s.original, s.changed, s.level.targets, o.x, o.y)), true);
        }
      }
    }
  });
  test('rotation hit regions match non-square artboard geometry', () {
    const o = RoomObject(id: 'r', art: 'book', x: .5, y: .5, width: .2, height: .02, rotation: 1.57079632679);
    expect(o.contains(.5, .57), true); expect(o.contains(.57, .5), false);
  });
  test('daily permits one attempt, no hints', () {
    final s = session(daily: '2026-09-09'); reachAnswer(s);
    expect(s.useHint(), false); expect(s.tap(.31, .23), TapResult.failed);
  });
  test('three hint strengths never auto-award a win', () {
    final s = session(); expect(s.useHint(), false); reachAnswer(s);
    expect(s.useHint(), true); expect(s.useHint(), true); expect(s.useHint(), true);
    expect(s.useHint(), false); expect(s.phase, GamePhase.answering);
  });
  test('unknown change types fail clearly and registered types extend the engine', () {
    final s = session(), registry = ChangeRegistry();
    const change = Change(type: 'CUSTOM', objectId: 'lamp', values: {});
    expect(() => registry.apply(s.original, [change]), throwsFormatException);
    registry.transforms['CUSTOM'] = (o, _) => o.patch({'scale': 2});
    expect(registry.apply(s.original, [change]).object('lamp').scale, 2);
  });
  test('paid hint highlight and input cooldown survive pause and restore', () {
    final s = session(); reachAnswer(s);
    s.useHint(); s.tap(.31, .23); s.advance(.1); s.pause();
    final restored = session()..restore(s.toJson());
    expect(restored.hintRemaining, closeTo(s.hintRemaining, .000001));
    expect(restored.lastTapped, s.lastTapped);
    expect(restored.cooldown, closeTo(s.cooldown, .000001));
    restored.advance(120); expect(restored.hintRemaining, s.hintRemaining);
    restored.resume();
    expect(restored.tap(.31, .23), TapResult.ignored);
    restored.advance(.4); expect(restored.tap(.31, .23), TapResult.wrong);
  });
  test('older final-reveal checkpoints remain useful after restoring', () {
    final s = session(); reachAnswer(s); s.useHint(); s.useHint(); s.useHint();
    final saved = s.toJson()..remove('hintRemaining');
    final restored = session()..restore(saved);
    expect(restored.hints, 3); expect(restored.hintRemaining, greaterThan(0));
  });
  test('damaged checkpoint is rejected without partially changing the session', () {
    final s = session(), baseline = session().toJson();
    for (final patch in <Json>[
      {'hints': 4}, {'mistakes': -1}, {'phaseElapsed': -2},
      {'answerElapsed': double.infinity}, {'levelId': 2},
      {'phase': 'unknown'}, {'lastTapped': 'missing-object'},
    ]) {
      expect(() => s.restore({...baseline, ...patch}), throwsFormatException);
      expect(s.toJson(), baseline);
    }
  });
  test('invalid touch coordinates cannot consume an attempt', () {
    final s = session(); reachAnswer(s);
    expect(s.tap(double.nan, .5), TapResult.ignored);
    expect(s.tap(.5, double.infinity), TapResult.ignored);
    expect(s.tap(-.1, .5), TapResult.ignored);
    expect(s.tap(.5, .5, padding: double.infinity), TapResult.ignored);
    expect(s.mistakes, 0);
  });

  test('loading stays inert and readiness survives backgrounding', () {
    final catalog = loadCatalog(), level = loadCatalog().level(1);
    final s = GameSession(level: level, room: catalog.rooms[level.roomId]!, runId: 'loading');
    s.advance(100); expect(s.phase, GamePhase.loading);
    s.pause(); s.ready(); s.advance(100); expect(s.phase, GamePhase.paused);
    s.resume(); expect(s.phase, GamePhase.intro);
  });
  test('timeout reveals the answer before becoming terminal', () {
    final s = session(); reachAnswer(s);
    s.advance(s.remaining);
    expect(s.phase, GamePhase.timedOut); expect(s.revealAnswer, true);
    expect(s.tap(.31, .23), TapResult.ignored);
    s.pause(); s.advance(100); expect(s.finished, false);
    s.resume(); s.advance(GameConfig.timeoutRevealSeconds);
    expect(s.phase, GamePhase.lost); expect(s.lossReason, LossReason.timeout);
  });
  test('correct feedback has fixed duration and freezes response time', () {
    final s = session(); reachAnswer(s); final lamp = s.original.object('lamp');
    s.advance(.5); s.tap(lamp.x, lamp.y);
    expect(s.phase, GamePhase.correct); final elapsed = s.answerElapsed;
    s.advance(GameConfig.correctFeedbackSeconds / 2); expect(s.finished, false);
    expect(s.answerElapsed, elapsed);
    s.advance(GameConfig.correctFeedbackSeconds / 2); expect(s.phase, GamePhase.won);
  });
  test('every pre-answer phase ignores taps', () {
    final s = session();
    while (s.phase != GamePhase.answering) {
      expect(s.tap(.31, .23), TapResult.ignored);
      s.advance(.05);
    }
    expect(s.mistakes, 0);
  });
  test('malformed transform geometry cannot enter a room state', () {
    final s = session();
    expect(() => ChangeRegistry().apply(s.original, const [
      Change(type: 'OBJECT_RESIZED', objectId: 'lamp', values: {'scale': -1}),
    ]), throwsFormatException);
    expect(s.original.object('lamp').scale, 1);
  });
  test('overlap resolution respects foreground objects without answer priority', () {
    const back = RoomObject(id: 'back', art: 'book', x: .5, y: .5, width: .2, height: .2);
    const visible = RoomObject(id: 'front', art: 'book', x: .5, y: .5, width: .1, height: .1, z: 2);
    final original = RoomState([back, visible]);
    final changed = RoomState([back.patch({'visible': false}), visible]);
    final hits = HitTester(original, changed, {'back'});
    expect(hits.resolve(.5, .5), 'front');
    expect(hits.resolve(.41, .5), 'back');
  });
}
