import 'package:flutter_test/flutter_test.dart';
import 'package:echo_room/core/config.dart';
import 'package:echo_room/game/session.dart';
import 'package:echo_room/game/session_controller.dart';
import 'package:echo_room/models/progress.dart';
import 'package:echo_room/services/progression_service.dart';
import 'package:echo_room/collection/definitions.dart';
import 'package:echo_room/app/providers.dart';
import 'package:echo_room/storage/progress_repository.dart';

import 'test_support.dart';
import 'controller_test.dart' show ready;

void main() {
  final now = DateTime(2026, 9, 11);
  test('milestone hints and collectibles are awarded once across replay and reload', () {
    var p = Progress();
    for (var id = 1; id <= 20; id++) {
      final s = session(level: id, runId: 'first-$id');
      win(s);
      final done = completeSession(p, s, now, 20);
      expect(done.hintsEarned, GameConfig.hintRewards[id] ?? 0);
      expect(done.progress.lives, 5);
      p = Progress.fromJson(done.progress.toJson());
      final replay = session(level: id, runId: 'replay-$id');
      win(replay);
      final repeated = completeSession(p, replay, now, 20);
      expect(repeated.hintsEarned, 0);
      expect(repeated.newCollectibles, isEmpty);
      expect(repeated.progress.hints, p.hints);
      expect(repeated.progress.highestLevel, p.highestLevel);
      p = repeated.progress;
    }
    expect(p.hints, GameConfig.initialHints + 9);
    expect(p.totalStars(20), 60);
    expect(p.completionPercent(20), 100);
    expect(p.chapterComplete(20), true);
    expect(p.collectibles, collectibles.map((c) => c.id).toSet());
    expect(p.correctAnswers, 40);
    expect(p.roomsCompleted(20), 20);
  });

  test('independent record flags require a strict improvement', () {
    final s = session();
    win(s, elapsed: .5);
    final first = completeSession(Progress(), s, now, 20);
    expect(
      first.newBestScore && first.newBestTime && first.newStarRecord,
      true,
    );
    // Reset only the active streak to compare equal scoring inputs.
    final baseline = first.progress.patch({'streak': 0});
    final equal = session(runId: 'equal');
    win(equal, elapsed: .5);
    final same = completeSession(baseline, equal, now, 20);
    expect(same.newBestScore || same.newBestTime || same.newStarRecord, false);
    final slower = session(runId: 'slow');
    win(slower, elapsed: 6);
    final worse = completeSession(baseline, slower, now, 20);
    expect(worse.score.stars, 1);
    expect(worse.progress.levels[1]!.toJson(), baseline.levels[1]!.toJson());
    expect(
      worse.newBestScore || worse.newBestTime || worse.newStarRecord,
      false,
    );
    final faster = session(runId: 'fast');
    win(faster, elapsed: .2);
    final better = completeSession(baseline, faster, now, 20);
    expect(better.newBestTime, true);
    expect(better.newBestScore, true);
    expect(better.newStarRecord, false);
  });

  test('success with a wrong tap extends streak; failure resets only active streak', () {
    final s = session();
    reachAnswer(s);
    var tapped = false;
    for (var y = 0; y < 100 && !tapped; y++) {
      for (var x = 0; x < 100 && !tapped; x++) {
        final id = s.hitTester.resolve(x / 100, y / 100);
        if (id != null && !s.targets.contains(id)) {
          expect(s.tap(x / 100, y / 100), TapResult.wrong);
          tapped = true;
        }
      }
    }
    expect(tapped, true);
    s.advance(.5);
    win(s);
    final done = completeSession(
      Progress(streak: 9, bestStreak: 9),
      s,
      now,
      20,
    );
    expect(done.progress.streak, 10);
    expect(done.progress.bestStreak, 10);
    expect(done.newAchievements, contains('streak_master'));
    expect(done.progress.wrongTaps, 1);
    expect(done.progress.perfectLevels, isEmpty);
    final duplicate = completeSession(done.progress, s, now, 20);
    expect(duplicate.progress.toJson(), done.progress.toJson());
    expect(duplicate.newAchievements, isEmpty);
    final failure = session(runId: 'failure')..advance(100);
    final lost = completeSession(done.progress, failure, now, 20).progress;
    expect(lost.streak, 0);
    expect(lost.bestStreak, 10);
    expect(lost.correctAnswers, 1);
    expect(Progress.fromJson(lost.toJson()).bestStreak, 10);
  });

  test(
    'replaying one room cannot farm distinct-room achievements or hints',
    () {
      var p = Progress();
      for (var i = 0; i < 20; i++) {
        final s = session(runId: '$i');
        win(s);
        p = completeSession(p, s, now, 20).progress;
      }
      expect(p.achievements, isNot(contains('perfect_memory')));
      expect(p.achievements, isNot(contains('no_help')));
      expect(p.achievements, isNot(contains('perfectionist')));
      expect(p.totalStars(20), 3);
      expect(p.hints, GameConfig.initialHints);
      expect(p.chapterComplete(20), false);
    },
  );

  test(
    'missing additive fields preserve old records, balances and settings',
    () {
      final p = Progress.fromJson({
        'version': 1,
        'highestLevel': 6,
        'hints': 22,
        'bestStreak': 5,
        'settings': {'music': false, 'sound': false, 'haptics': false},
        'levels': {
          '5': {'stars': 2, 'score': 1700, 'bestTime': 2.5},
        },
        'collectibles': ['brass_key'],
      });
      expect(p.correctAnswers, 1);
      expect(p.wrongTaps, 0);
      expect(p.hintsUsed, 0);
      expect(p.hints, 22);
      expect(p.settings.sound, false);
      expect(p.bestResponseTime, 2.5);
      final s = session(level: 5);
      win(s);
      final done = completeSession(p, s, now, 20);
      expect(done.hintsEarned, 0);
      expect(done.newCollectibles, isEmpty);
      expect(done.progress.levels[5]!.stars, 3);
    },
  );

  test('chapter completion requires every room, not just reaching Room 20', () {
    final s = session(level: 20);
    win(s);
    final p = completeSession(Progress(highestLevel: 20), s, now, 20).progress;
    expect(p.chapterComplete(20), false);
    expect(p.achievements, isNot(contains('observer')));
    expect(p.totalStars(20), 3);
    expect(p.completionPercent(20), 5);
  });

  test('reset clears every progression field and preserves preferences after reload', () async {
    final repo = MemoryProgressRepository();
    final s = session(level: 5);
    win(s);
    repo.value = completeSession(Progress(streak: 9), s, now, 20).progress
        .patch({
          'settings': const UserSettings(
            music: false,
            sound: false,
            haptics: false,
          ).toJson(),
          'wrongTaps': 8,
          'hintsUsed': 2,
          'lives': 1,
        });
    final c = await ready(repo);
    addTearDown(c.dispose);
    await c.read(profileProvider.notifier).reset();
    final restored = await repo.load();
    expect(restored.toJson(), Progress(settings: repo.value.settings).toJson());
    expect(restored.settings.haptics, false);
  });

  test(
    'hint spending cannot become negative and completed stats count hints once',
    () async {
      final repo = MemoryProgressRepository();
      final c = await ready(repo);
      addTearDown(c.dispose);
      await c.read(profileProvider.notifier).commit(Progress(hints: 0));
      final controller = c.read(sessionProvider.notifier);
      await controller.start(1);
      reachAnswer(controller.game!);
      await controller.hint();
      expect(controller.game!.hints, 0);
      expect((await repo.load()).hints, 0);
      // Test rule accounting separately from the controller's atomic spending.
      final s = session();
      reachAnswer(s);
      s.useHint();
      win(s);
      final done = completeSession(Progress(hints: 0), s, now, 20);
      expect(done.progress.hints, 0);
      expect(done.progress.hintsUsed, 1);
      expect(done.score.stars, lessThan(3));
      expect(completeSession(done.progress, s, now, 20).progress.hintsUsed, 1);
    },
  );
}
