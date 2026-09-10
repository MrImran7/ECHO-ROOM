import '../models/progress.dart';

abstract interface class DailyChallengeSource {
  int levelFor(DateTime localDate, int count);
}

class LocalDailyChallengeSource implements DailyChallengeSource {
  const LocalDailyChallengeSource();
  @override
  int levelFor(DateTime localDate, int count) {
    if (count < 1) throw ArgumentError.value(count, 'count');
    // Stable arithmetic across Dart VM/web; independent of locale and hashCode.
    final day = DateTime.utc(
      localDate.year,
      localDate.month,
      localDate.day,
    ).difference(DateTime.utc(2020)).inDays;
    return ((day * 7919 + 104729) % count) + 1;
  }
}

String dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String previousDate(String date) {
  final d = DateTime.parse(date);
  return dateKey(DateTime(d.year, d.month, d.day - 1));
}

int visibleDailyStreak(Progress p, DateTime now) {
  final today = dateKey(now);
  if (p.daily[today]?.status == 'lost') return 0;
  return p.lastDailyWin == today || p.lastDailyWin == previousDate(today)
      ? p.dailyStreak
      : 0;
}
