import 'dart:math' as math;

import '../core/config.dart';

class ScoreResult {
  const ScoreResult({
    required this.total,
    required this.stars,
    required this.speed,
    required this.accuracy,
    required this.multiplier,
  });
  final int total, stars, speed, accuracy;
  final double multiplier;
}

double streakMultiplier(int streak) {
  var result = 1.0;
  for (final entry in GameConfig.streakMultipliers.entries) {
    if (streak >= entry.key) result = entry.value;
  }
  return result;
}

int calculateStars({
  required bool won,
  required double elapsed,
  required double limit,
  required int mistakes,
  required int hints,
}) {
  if (!won) return 0;
  if (mistakes == 0 &&
      hints == 0 &&
      elapsed <= limit * GameConfig.threeStarTimeFraction)
    return 3;
  if (mistakes <= 1 &&
      hints <= 1 &&
      elapsed <= limit * GameConfig.twoStarTimeFraction)
    return 2;
  return 1;
}

ScoreResult calculateScore({
  required bool won,
  required double elapsed,
  required double limit,
  required int mistakes,
  required int hints,
  required int streak,
}) {
  if (!elapsed.isFinite ||
      elapsed < 0 ||
      !limit.isFinite ||
      limit <= 0 ||
      mistakes < 0 ||
      hints < 0 ||
      hints > 3 ||
      streak < 0) {
    throw ArgumentError(
      'Score inputs must have finite positive timing and valid counters.',
    );
  }
  final speed = (GameConfig.speedBonus * (1 - elapsed / limit).clamp(0.0, 1.0))
      .round();
  final accuracy = (GameConfig.accuracyBonus / (mistakes + 1)).round();
  final penalty = GameConfig.hintPenalties.take(hints).fold(0, (a, b) => a + b);
  final multiplier = streakMultiplier(streak);
  final subtotal = math.max(
    0,
    GameConfig.baseScore +
        speed +
        accuracy +
        (hints == 0 ? GameConfig.noHintBonus : 0) -
        penalty,
  );
  return ScoreResult(
    total: won ? (subtotal * multiplier).round() : 0,
    stars: calculateStars(
      won: won,
      elapsed: elapsed,
      limit: limit,
      mistakes: mistakes,
      hints: hints,
    ),
    speed: won ? speed : 0,
    accuracy: won ? accuracy : 0,
    multiplier: multiplier,
  );
}
