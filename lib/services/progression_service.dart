import 'dart:math' as math;
import '../achievements/definitions.dart';
import '../core/config.dart';
import '../daily/daily_service.dart';
import '../game/scoring.dart';
import '../game/session.dart';
import '../models/progress.dart';
import 'lives_service.dart';

class Completion {
  const Completion(this.progress, this.score, this.newAchievements, this.newCollectible, this.streakLabel);
  final Progress progress;
  final ScoreResult score;
  final Set<String> newAchievements;
  final String? newCollectible, streakLabel;
}
Completion completeSession(Progress p, GameSession s, DateTime now, int chapterSize,
    {bool livesEnabled = GameConfig.livesEnabled}) {
  final won = s.phase == GamePhase.won;
  final streak = won ? (s.mistakes == 0 ? p.streak + 1 : 1) : 0;
  final score = calculateScore(won: won, elapsed: s.answerElapsed, limit: s.level.answerDuration,
    mistakes: s.mistakes, hints: s.hints, streak: streak);
  if (p.completedRuns.contains(s.runId)) return Completion(p, score, {}, null, null);
  var next = p;
  String? collectible;
  if (s.dailyDate != null) {
    final key = s.dailyDate!;
    final dailyStreak = won ? (p.lastDailyWin == previousDate(key) ? p.dailyStreak + 1 : 1) : 0;
    next = next.patch({'daily': {...p.daily.map((k, v) => MapEntry(k, v.toJson())), key:
      DailyRecord(levelId: s.level.levelId, status: won ? 'won' : 'lost', time: s.answerElapsed, score: score.total).toJson()},
      'dailyStreak': dailyStreak, 'bestDailyStreak': math.max(p.bestDailyStreak, dailyStreak),
      'lastDailyWin': won ? key : p.lastDailyWin});
  } else if (won) {
    final id = s.level.levelId;
    final old = p.levels[id];
    final record = LevelRecord(score: math.max(old?.score ?? 0, score.total),
      stars: math.max(old?.stars ?? 0, score.stars),
      bestTime: old == null ? s.answerElapsed : math.min(old.bestTime, s.answerElapsed));
    if (s.level.collectibleId != null && !p.collectibles.contains(s.level.collectibleId)) collectible = s.level.collectibleId;
    next = next.patch({'levels': {...p.levels.map((k, v) => MapEntry('$k', v.toJson())), '$id': record.toJson()},
      'highestLevel': math.min(chapterSize, math.max(p.highestLevel, id + 1)),
      'hints': p.hints + (old == null ? GameConfig.hintReward : 0),
      'perfectLevels': {...p.perfectLevels, if (s.mistakes == 0) id}.toList(),
      'unassistedLevels': {...p.unassistedLevels, if (s.hints == 0) id}.toList(),
      'collectibles': {...p.collectibles, if (collectible != null) collectible}.toList()});
  }
  if (!won && livesEnabled && s.dailyDate == null) next = const LivesService().consume(next, now);
  final unlocked = unlockedAchievements(next, chapterSize);
  final runs = [...p.completedRuns, s.runId];
  next = next.patch({'streak': streak, 'bestStreak': math.max(p.bestStreak, streak),
    'achievements': unlocked.toList(), 'activeSession': null,
    'completedRuns': runs.length > 100 ? runs.sublist(runs.length - 100) : runs});
  return Completion(next, score, unlocked.difference(p.achievements), collectible,
    won ? GameConfig.milestones[streak] : null);
}
