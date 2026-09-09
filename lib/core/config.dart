import 'package:flutter/foundation.dart';

abstract final class GameConfig {
  static const maxLives = 5;
  static const initialHints = 12;
  static const hintReward = 2;
  static const hintCosts = [1, 2, 3];
  static const hintPenalties = [100, 250, 500];
  static const streakMultipliers = {0: 1.0, 3: 1.2, 5: 1.5, 10: 2.0};
  static const threeStarTimeFraction = .5;
  static const twoStarTimeFraction = .85;
  static const baseScore = 1000;
  static const speedBonus = 500;
  static const accuracyBonus = 250;
  static const noHintBonus = 250;
  static const introSeconds = 1.0;
  static const countdownSeconds = 3.0;
  static const flickerSeconds = .45;
  static const blackoutSeconds = .7;
  static const correctFeedbackSeconds = 1.0;
  static const wrongFeedbackSeconds = .36;
  static const timeoutRevealSeconds = 1.0;
  static const hintPulseSeconds = 1.8;
  static const skippedObservationSeconds = .1;
  static const minimumTouchSize = 44.0;
  static const hudInterval = .08;
  static const checkpointInterval = 1.0;
  static const scoreAnimationMilliseconds = 550;
  static const transitionMilliseconds = 180;
  static const tapCooldown = .32;
  static const livesEnabled = !bool.fromEnvironment('DISABLE_LIVES');
  static const lifeMinutes = int.fromEnvironment('LIFE_MINUTES', defaultValue: 20);
  static const debugTools = kDebugMode;
  static const milestones = {3: 'SHARP EYES', 5: 'DETECTIVE', 10: 'EAGLE EYE', 20: 'IMPOSSIBLE'};
}
