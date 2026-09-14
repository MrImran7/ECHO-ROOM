import 'package:flutter_test/flutter_test.dart';
import 'package:echo_room/daily/daily_service.dart';
import 'package:echo_room/models/progress.dart';
import 'package:echo_room/services/progression_service.dart';

import 'test_support.dart';

void main() {
  test(
    'selection depends only on local calendar date and is always in range',
    () {
      const daily = LocalDailyChallengeSource();
      expect(
        daily.levelFor(DateTime(2026, 9, 9, 0), 20),
        daily.levelFor(DateTime(2026, 9, 9, 23, 59), 20),
      );
      final selected = <int>{};
      for (var i = 0; i < 365; i++) {
        final id = daily.levelFor(DateTime(2026, 1, 1 + i), 20);
        expect(LocalDailyChallengeSource.eligibleLevels, contains(id));
        selected.add(id);
      }
      expect(selected.length, LocalDailyChallengeSource.eligibleLevels.length);
    },
  );
  test('calendar predecessor survives leap days and DST-length days', () {
    expect(previousDate('2024-03-01'), '2024-02-29');
    expect(previousDate('2026-01-01'), '2025-12-31');
    expect(previousDate('2026-03-09'), '2026-03-08');
  });
  test(
    'daily streak increments on consecutive dates and resets after a gap',
    () {
      var p = Progress();
      for (final day in [9, 10, 12]) {
        final s = session(
          daily: dateKey(DateTime(2026, 9, day)),
          runId: '$day',
        );
        win(s);
        p = completeSession(p, s, DateTime(2026, 9, day), 20).progress;
        expect(p.dailyStreak, day == 10 ? 2 : 1);
      }
      expect(p.bestDailyStreak, 2);
      expect(p.levels, isEmpty);
      expect(p.highestLevel, 1);
      expect(visibleDailyStreak(p, DateTime(2026, 9, 14)), 0);
    },
  );
  test('daily failure records attempt without spending chapter lives', () {
    final s = session(daily: '2026-09-09')..advance(100);
    final p = completeSession(Progress(), s, DateTime(2026, 9, 9), 20).progress;
    expect(p.daily['2026-09-09']!.status, 'lost');
    expect(p.lives, 5);
  });
}
