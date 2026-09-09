import 'dart:math' as math;

import '../core/config.dart';
import '../models/progress.dart';

class LivesService {
  const LivesService({
    this.maximum = GameConfig.maxLives,
    this.regeneration = const Duration(minutes: GameConfig.lifeMinutes),
  });
  final int maximum;
  final Duration regeneration;
  Progress refresh(Progress p, DateTime now) {
    if (p.lives >= maximum)
      return p.patch({'lives': maximum, 'lifeAnchor': null});
    final anchor = p.lifeAnchor ?? now;
    final elapsed = now.difference(anchor).inSeconds;
    if (elapsed < 0) return p; // A clock rollback must never mint lives.
    final count = elapsed ~/ math.max(1, regeneration.inSeconds);
    final lives = math.min(maximum, p.lives + count);
    return p.patch({
      'lives': lives,
      'lifeAnchor': lives == maximum
          ? null
          : anchor
                .add(
                  Duration(
                    seconds: count * math.max(1, regeneration.inSeconds),
                  ),
                )
                .toIso8601String(),
    });
  }

  Progress consume(Progress p, DateTime now) {
    final current = refresh(p, now);
    return current.patch({
      'lives': math.max(0, current.lives - 1),
      'lifeAnchor': (current.lifeAnchor ?? now).toIso8601String(),
    });
  }

  Duration? untilNext(Progress p, DateTime now) {
    if (p.lives >= maximum || p.lifeAnchor == null) return null;
    return Duration(
      seconds: math.max(
        0,
        regeneration.inSeconds - now.difference(p.lifeAnchor!).inSeconds,
      ),
    );
  }
}
