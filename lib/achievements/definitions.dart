import '../models/progress.dart';

enum AchievementMetric {
  completedLevels,
  perfectLevels,
  fastestFind,
  unassistedLevels,
  chapterComplete,
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
  bool satisfied(Progress p, int chapterSize) => switch (metric) {
    AchievementMetric.completedLevels => p.levels.length >= target,
    AchievementMetric.perfectLevels => p.perfectLevels.length >= target,
    AchievementMetric.fastestFind => p.levels.values.any(
      (r) => r.bestTime <= target,
    ),
    AchievementMetric.unassistedLevels => p.unassistedLevels.length >= target,
    AchievementMetric.chapterComplete => p.levels.length >= chapterSize,
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
];
Set<String> unlockedAchievements(Progress p, int chapterSize) => {
  ...p.achievements,
  for (final a in achievements)
    if (a.satisfied(p, chapterSize)) a.id,
};
