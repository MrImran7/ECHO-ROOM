import 'package:flutter_test/flutter_test.dart';
import 'package:echo_room/app/providers.dart';
import 'package:echo_room/daily/daily_service.dart';
import 'package:echo_room/game/session.dart';
import 'package:echo_room/game/session_controller.dart';
import 'package:echo_room/models/progress.dart';
import 'package:echo_room/services/progression_service.dart';
import 'package:echo_room/storage/progress_repository.dart';

import 'controller_test.dart' show ready, TestClock;
import 'test_support.dart';

void main() {
  final day = DateTime(2026, 9, 11);
  test('versioned daily pool is explicit, stable and independent of time', () {
    const source = LocalDailyChallengeSource();
    final id = source.levelFor(day, 20);
    expect(source.levelFor(DateTime(2026, 9, 11, 23, 59), 20), id);
    expect(source.levelFor(day.add(const Duration(days: 1)), 20), isNot(id));
    expect(const LocalDailyChallengeSource(version: 2).levelFor(day, 20), isNot(id));
    expect(const LocalDailyChallengeSource(version: 2).levelFor(day, 20),
        const LocalDailyChallengeSource(version: 2).levelFor(day, 20));
    for (final id in LocalDailyChallengeSource.eligibleLevels) {
      final level = loadCatalog().level(id);
      expect(['medium', 'hard'], contains(level.difficulty));
      expect(level.answerDuration, greaterThanOrEqualTo(8));
      expect(level.targets, isNotEmpty);
    }
    expect(() => source.levelFor(day, 5), throwsArgumentError);
    expect(() => const LocalDailyChallengeSource(version: 0).levelFor(day, 20), throwsArgumentError);
  });

  test('date key and predecessor use calendar fields across boundaries', () {
    expect(dateKey(DateTime(2026, 9, 1, 23)), '2026-09-01');
    expect(previousDate('2027-01-01'), '2026-12-31');
    expect(previousDate('2024-03-01'), '2024-02-29');
    expect(previousDate('2026-11-02'), '2026-11-01');
  });

  test('daily solve isolates all chapter state and ignores chapter score streak', () {
    final baseline = Progress(streak: 19, bestStreak: 20, lives: 0, hints: 0,
      levels: const {1: LevelRecord(score: 2000, stars: 3, bestTime: .4)},
      highestLevel: 2, correctAnswers: 3, wrongTaps: 4, hintsUsed: 5,
      achievements: {'first_find'}, collectibles: {'brass_key'});
    final s = session(daily: dateKey(day));
    reachAnswer(s);
    s.useHint();
    win(s);
    final done = completeSession(baseline, s, day, 20);
    final after = done.progress.toJson(), before = baseline.toJson();
    for (final field in ['daily', 'dailyStreak', 'bestDailyStreak', 'lastDailyWin', 'completedRuns', 'activeSession']) {
      after.remove(field);
      before.remove(field);
    }
    expect(after, before);
    expect(done.newAchievements, isEmpty);
    expect(done.newCollectibles, isEmpty);
    expect(done.streakLabel, isNull);
    expect(done.score.multiplier, 1);
    expect(done.progress.daily[dateKey(day)]!.hintsUsed, 1);
    expect(done.score.stars, lessThan(3));
  });

  test('official record is immutable even with another run ID', () {
    final first = session(daily: dateKey(day), runId: 'one');
    win(first, elapsed: 2);
    final p = completeSession(Progress(), first, day, 20).progress;
    final replay = session(daily: dateKey(day), runId: 'two');
    win(replay, elapsed: .1);
    expect(completeSession(p, replay, day, 20).progress.toJson(), p.toJson());
  });

  test('failed official result cannot be repaired by a successful replay', () {
    final first = session(daily: dateKey(day))..advance(100);
    final p = completeSession(Progress(dailyStreak: 7, bestDailyStreak: 7), first, day, 20).progress;
    final retry = session(daily: dateKey(day), runId: 'retry');
    win(retry);
    expect(completeSession(p, retry, day, 20).progress.toJson(), p.toJson());
    expect(p.dailyStreak, 0);
    expect(p.bestDailyStreak, 7);
  });

  for (final pair in [ ['2026-09-30', '2026-10-01'], ['2026-12-31', '2027-01-01'], ['2024-02-29', '2024-03-01'] ]) {
    test('consecutive wins across ${pair.join(' / ')}', () {
      var p = Progress();
      for (final date in pair) {
        final s = session(daily: date, runId: date);
        win(s);
        p = completeSession(p, s, DateTime.parse(date), 20).progress;
      }
      expect(p.dailyStreak, 2);
      expect(Progress.fromJson(p.toJson()).bestDailyStreak, 2);
      expect(visibleDailyStreak(p, DateTime.parse(pair.last).add(const Duration(days: 2))), 0);
      expect(p.bestDailyStreak, 2);
    });
  }

  test('new player at zero lives can start, hint, suspend and restore daily', () async {
    final clock = TestClock(day);
    final repo = MemoryProgressRepository()..value = Progress(lives: 0, hints: 0);
    final c = await ready(repo, clock: clock);
    final controller = c.read(sessionProvider.notifier);
    await controller.start(1, daily: true);
    final s = controller.game!;
    expect(s.level.levelId, const LocalDailyChallengeSource().levelFor(day, 20));
    expect(s.level.levelId, greaterThan(c.read(profileProvider).highestLevel));
    reachAnswer(s);
    for (var i = 0; i < 3; i++) { await controller.hint(); }
    expect(s.hints, 3);
    expect(c.read(profileProvider).hints, 0);
    expect(c.read(profileProvider).lives, 0);
    controller.pause();
    await controller.checkpoint();
    final saved = s.toJson();
    c.dispose();
    clock.value = DateTime(2026, 9, 12);
    final restored = await ready(repo, clock: clock);
    addTearDown(restored.dispose);
    final next = restored.read(sessionProvider.notifier)..restore();
    expect(next.game!.dailyDate, '2026-09-11');
    expect(next.game!.toJson(), saved);
    next.tick(100);
    expect(next.game!.toJson(), saved);
    next.resume();
    win(next.game!);
    await next.retrySave();
    expect(restored.read(profileProvider).daily['2026-09-11']!.hintsUsed, 3);
    expect(restored.read(profileProvider).daily['2026-09-12'], isNull);
    await next.start(1, daily: true);
    expect(next.game!.dailyDate, '2026-09-12');
  });

  test('unfinished reservation without checkpoint permits retry of same puzzle', () async {
    final repo = MemoryProgressRepository()..value = Progress(daily: const {
      '2026-09-11': DailyRecord(levelId: 7, puzzleVersion: 1),
    });
    final c = await ready(repo);
    addTearDown(c.dispose);
    await c.read(sessionProvider.notifier).start(1, daily: true);
    expect(c.read(sessionProvider.notifier).game!.level.levelId, 7);
  });

  test('controller blocks completed dates and refreshes selection after midnight', () async {
    final clock = TestClock(day);
    final repo = MemoryProgressRepository()..value = Progress(daily: const {
      '2026-09-11': DailyRecord(levelId: 7, status: 'won'),
    });
    final c = await ready(repo, clock: clock);
    addTearDown(c.dispose);
    final controller = c.read(sessionProvider.notifier);
    await expectLater(controller.start(1, daily: true), throwsStateError);
    expect(dailyStatus(c.read(profileProvider), clock.now()), '✓ COMPLETE');
    clock.value = DateTime(2026, 9, 12);
    expect(dailyStatus(c.read(profileProvider), clock.now()), 'NEW');
    await controller.start(1, daily: true);
    expect(controller.game!.dailyDate, '2026-09-12');
  });

  test('legacy daily saves migrate milliseconds and missing fields safely', () {
    final old = Progress.fromJson({'highestLevel': 8, 'daily': {
      '2026-09-10': {'levelId': 7, 'status': 'won', 'time': 1.234, 'score': 1500},
    }});
    final record = old.daily['2026-09-10']!;
    expect(record.responseTimeMs, 1234);
    expect(record.hintsUsed, 0);
    expect(record.puzzleVersion, 1);
    expect(Progress.fromJson(old.toJson()).toJson(), old.toJson());
    expect(old.highestLevel, 8);
    expect(Progress.fromJson({'highestLevel': 8}).daily, isEmpty);
  });

  test('reset clears daily state while preserving preferences', () async {
    final repo = MemoryProgressRepository()..value = Progress(
      daily: const {'2026-09-11': DailyRecord(levelId: 7, status: 'won')},
      dailyStreak: 3, bestDailyStreak: 5, lastDailyWin: '2026-09-11',
      settings: const UserSettings(music: false, sound: false, haptics: false),
    );
    final c = await ready(repo);
    addTearDown(c.dispose);
    await c.read(profileProvider.notifier).reset();
    final p = await repo.load();
    expect(p.daily, isEmpty);
    expect(p.dailyStreak, 0);
    expect(p.bestDailyStreak, 0);
    expect(p.lastDailyWin, isNull);
    expect(p.settings.haptics, false);
  });
}
