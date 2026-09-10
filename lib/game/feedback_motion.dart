import 'dart:math' as math;

/// Presentation curves use phase time, never a second gameplay clock.
abstract final class FeedbackMotion {
  static double correctScale(double elapsed, {bool reduced = false}) {
    if (reduced) return 1;
    final progress = (elapsed / .3).clamp(0.0, 1.0);
    return 1 + .06 * math.sin(progress * math.pi);
  }

  static double wrongOffset(double elapsed, {bool reduced = false}) {
    if (reduced) return 0;
    final progress = (elapsed / .22).clamp(0.0, 1.0);
    return math.sin(progress * math.pi * 6) * 3 * (1 - progress);
  }

  static double darkness(double progress, {bool reduced = false}) {
    final t = progress.clamp(0.0, 1.0);
    // One gentle dip, a partial recovery, then darkness. No repeated flashing.
    if (reduced) return t;
    if (t < .3) return .35 * t / .3;
    if (t < .5) return .35 - .15 * (t - .3) / .2;
    return .2 + .8 * (t - .5) / .5;
  }
}
