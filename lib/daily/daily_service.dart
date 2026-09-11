import '../models/progress.dart';

/// Injectable local clock. Calendar fields, never elapsed hours, identify a day.
abstract interface class LocalClock {
  DateTime now();
}

class SystemLocalClock implements LocalClock {
  const SystemLocalClock();
  @override
  DateTime now() => DateTime.now();
}

abstract interface class DailyChallengeSource {
  int levelFor(DateTime localDate, int count);
}

class LocalDailyChallengeSource implements DailyChallengeSource {
  const LocalDailyChallengeSource({this.version = dailyPoolVersion});
  static const dailyPoolVersion = 1;
  // Medium/hard, recognizable targets; no tutorial or tiny-object puzzles.
  // Keep ordering stable within a version. Bump version when content changes.
  static const eligibleLevels = [6, 7, 8, 9, 10, 11, 13, 14, 15];
  final int version;
  @override
  int levelFor(DateTime localDate, int count) {
    if (version < 1) throw ArgumentError.value(version, 'version');
    if (eligibleLevels.any((id) => id > count)) {
      throw ArgumentError('Daily pool requires Chapter 1 levels 1–15.');
    }
    final day = DateTime.utc(localDate.year, localDate.month, localDate.day)
        .difference(DateTime.utc(2020)).inDays;
    return eligibleLevels[(day * 7919 + version * 104729) % eligibleLevels.length];
  }
}

String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String previousDate(String date) {
  final d = DateTime.parse(date);
  return dateKey(DateTime.utc(d.year, d.month, d.day - 1));
}

int visibleDailyStreak(Progress p, DateTime now) {
  final today = dateKey(now);
  if (p.daily[today]?.status == 'lost') return 0;
  return p.lastDailyWin == today || p.lastDailyWin == previousDate(today)
      ? p.dailyStreak
      : 0;
}

DailyAttemptState dailyAttemptState(Progress p, DateTime now) =>
    p.daily[dateKey(now)]?.state ?? DailyAttemptState.available;

String dailyStatus(Progress p, DateTime now) => switch (dailyAttemptState(p, now)) {
  DailyAttemptState.completed => '✓ COMPLETE',
  DailyAttemptState.failed => 'MISSED',
  DailyAttemptState.started || DailyAttemptState.interrupted => 'RESUME',
  DailyAttemptState.available => 'NEW',
};
