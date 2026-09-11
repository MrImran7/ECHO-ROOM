import '../models/progress.dart';

enum AchievementMetric {
  completedLevels,
  perfectLevels,
  fastestFind,
  unassistedLevels,
  chapterComplete,
  threeStarLevels,
  totalStars,
  bestStreak,
}

class AchievementDefinition {
  const AchievementDefinition(
    this.id,
    this.name,
    this.description,
    this.metric,
    this.target,
  );
  final String id, name, description;
  final AchievementMetric metric;
  final int target;
  String progressLabel(Progress p, int chapterSize) => switch (metric) {
    AchievementMetric.completedLevels => '${p.roomsCompleted(chapterSize)} / $target rooms',
    AchievementMetric.perfectLevels => '${p.perfectLevels.length} / $target rooms',
    AchievementMetric.fastestFind => p.bestResponseTime == null ? 'Find a change to set a best time' : 'Best ${p.bestResponseTime!.toStringAsFixed(2)}s',
    AchievementMetric.unassistedLevels => '${p.unassistedLevels.length} / $target rooms',
    AchievementMetric.chapterComplete => '${p.roomsCompleted(chapterSize)} / $chapterSize rooms',
    AchievementMetric.threeStarLevels => '${p.levels.values.where((r) => r.stars == 3).length} / $target rooms',
    AchievementMetric.totalStars => '${p.totalStars(chapterSize)} / $target stars',
    AchievementMetric.bestStreak => '${p.bestStreak} / $target in a row',
  };
  bool satisfied(Progress p, int chapterSize) => switch (metric) {
    AchievementMetric.completedLevels => p.levels.length >= target,
    AchievementMetric.perfectLevels => p.perfectLevels.length >= target,
    AchievementMetric.fastestFind => p.levels.values.any(
      (r) => r.bestTime <= target,
    ),
    AchievementMetric.unassistedLevels => p.unassistedLevels.length >= target,
    AchievementMetric.chapterComplete => p.chapterComplete(chapterSize),
    AchievementMetric.threeStarLevels => p.levels.entries.where((e) => e.key >= 1 && e.key <= chapterSize && e.value.stars == 3).length >= target,
    AchievementMetric.totalStars => p.totalStars(chapterSize) >= target,
    AchievementMetric.bestStreak => p.bestStreak >= target,
  };
}

const achievements = [
  AchievementDefinition(
    'first_find',
    'FIRST FIND',
    'Complete your first room.',
    AchievementMetric.completedLevels,
    1,
  ),
  AchievementDefinition(
    'perfect_memory',
    'PERFECT MEMORY',
    'Complete 5 distinct rooms without a mistake.',
    AchievementMetric.perfectLevels,
    5,
  ),
  AchievementDefinition(
    'eagle_eye',
    'EAGLE EYE',
    'Find a change within 1 second.',
    AchievementMetric.fastestFind,
    1,
  ),
  AchievementDefinition(
    'no_help',
    'NO HELP NEEDED',
    'Complete 10 distinct rooms without hints.',
    AchievementMetric.unassistedLevels,
    10,
  ),
  AchievementDefinition(
    'observer',
    'OBSERVER',
    'Complete The Apartment.',
    AchievementMetric.chapterComplete,
    20,
  ),
  AchievementDefinition('perfectionist', 'PERFECTIONIST', 'Earn 3 stars on 10 distinct rooms.', AchievementMetric.threeStarLevels, 10),
  AchievementDefinition('master_observer', 'MASTER OBSERVER', 'Earn all 60 Apartment stars.', AchievementMetric.totalStars, 60),
  AchievementDefinition('streak_master', 'STREAK MASTER', 'Solve 10 rooms in a row without failing.', AchievementMetric.bestStreak, 10),
];
Set<String> unlockedAchievements(Progress p, int chapterSize) => {
  ...p.achievements,
  for (final a in achievements)
    if (a.satisfied(p, chapterSize)) a.id,
};
