import 'dart:math' as math;

import '../achievements/definitions.dart';
import '../core/config.dart';
import '../collection/definitions.dart';
import '../daily/daily_service.dart';
import '../game/scoring.dart';
import '../game/session.dart';
import '../models/progress.dart';
import 'lives_service.dart';

class Completion {
  const Completion(
    this.progress,
    this.score,
    this.newAchievements,
    this.newCollectible,
    this.streakLabel, {
    this.newBestScore = false,
    this.newBestTime = false,
    this.newStarRecord = false,
    this.hintsEarned = 0,
    this.additionalCollectibles = const {},
  });
  final bool newBestScore, newBestTime, newStarRecord;
  final int hintsEarned;
  final Set<String> additionalCollectibles;
  Set<String> get newCollectibles => {
    if (newCollectible != null) newCollectible!,
    ...additionalCollectibles,
  };
  final Progress progress;
  final ScoreResult score;
  final Set<String> newAchievements;
  final String? newCollectible, streakLabel;
}

Completion completeSession(
  Progress p,
  GameSession s,
  DateTime now,
  int chapterSize, {
  bool livesEnabled = GameConfig.livesEnabled,
}) {
  if (!s.finished)
    throw StateError('Only a completed session can update progression.');
  final won = s.phase == GamePhase.won;
  // Every successful solve extends the active streak, including replays.
  // Permanent mastery and hint rewards depend on distinct room records.
  final streak = won ? p.streak + 1 : 0;
  final score = calculateScore(
    won: won,
    elapsed: s.answerElapsed,
    limit: s.level.answerDuration,
    mistakes: s.mistakes,
    hints: s.hints,
    streak: streak,
  );
  if (p.completedRuns.contains(s.runId))
    return Completion(p, score, {}, null, null);
  var next = p;
  String? collectible;
  var newBestScore = false, newBestTime = false, newStarRecord = false;
  var hintsEarned = 0;
  var foundCollectibles = <String>{};
  if (s.dailyDate != null) {
    final key = s.dailyDate!;
    final dailyStreak = won
        ? (p.lastDailyWin == previousDate(key) ? p.dailyStreak + 1 : 1)
        : 0;
    next = next.patch({
      'daily': {
        ...p.daily.map((k, v) => MapEntry(k, v.toJson())),
        key: DailyRecord(
          levelId: s.level.levelId,
          status: won ? 'won' : 'lost',
          time: s.answerElapsed,
          score: score.total,
        ).toJson(),
      },
      'dailyStreak': dailyStreak,
      'bestDailyStreak': math.max(p.bestDailyStreak, dailyStreak),
      'lastDailyWin': won ? key : p.lastDailyWin,
    });
  } else if (won) {
    final id = s.level.levelId;
    final old = p.levels[id];
    newBestScore = old == null || score.total > old.score;
    newBestTime = old == null || s.answerElapsed < old.bestTime;
    newStarRecord = old == null || score.stars > old.stars;
    hintsEarned = old == null ? GameConfig.hintRewards[id] ?? 0 : 0;
    final record = LevelRecord(
      score: math.max(old?.score ?? 0, score.total),
      stars: math.max(old?.stars ?? 0, score.stars),
      bestTime: old == null
          ? s.answerElapsed
          : math.min(old.bestTime, s.answerElapsed),
    );
    if (s.level.collectibleId != null &&
        !p.collectibles.contains(s.level.collectibleId))
      collectible = s.level.collectibleId;
    next = next.patch({
      'levels': {
        ...p.levels.map((k, v) => MapEntry('$k', v.toJson())),
        '$id': record.toJson(),
      },
      'highestLevel': math.min(chapterSize, math.max(p.highestLevel, id + 1)),
      'hints': p.hints + hintsEarned,
      'perfectLevels': {...p.perfectLevels, if (s.mistakes == 0) id}.toList(),
      'unassistedLevels': {
        ...p.unassistedLevels,
        if (s.hints == 0) id,
      }.toList(),
      'collectibles': {
        ...p.collectibles,
        if (collectible != null) collectible,
      }.toList(),
    });
  }
  if (!won && livesEnabled && s.dailyDate == null)
    next = const LivesService().consume(next, now);
  if (s.dailyDate == null) {
    next = next.patch({
      'correctAnswers': p.correctAnswers + (won ? 1 : 0),
      'wrongTaps': p.wrongTaps + s.mistakes,
      'hintsUsed': p.hintsUsed + s.hints,
    });
    if (won) {
      foundCollectibles = {
        for (final item in collectibles)
          if (item.satisfied(next) && !p.collectibles.contains(item.id))
            item.id,
      };
      next = next.patch({
        'collectibles': {...next.collectibles, ...foundCollectibles}.toList(),
      });
    }
  }
  next = next.patch({
    'streak': streak,
    'bestStreak': math.max(p.bestStreak, streak),
  });
  final unlocked = unlockedAchievements(next, chapterSize);
  final runs = [...p.completedRuns, s.runId];
  next = next.patch({
    'achievements': unlocked.toList(),
    'activeSession': null,
    'completedRuns': runs.length > 100 ? runs.sublist(runs.length - 100) : runs,
  });
  return Completion(
    next,
    score,
    unlocked.difference(p.achievements),
    collectible,
    won ? GameConfig.milestones[streak] : null,
    newBestScore: newBestScore,
    newBestTime: newBestTime,
    newStarRecord: newStarRecord,
    hintsEarned: hintsEarned,
    additionalCollectibles: Set.unmodifiable(foundCollectibles),
  );
}
