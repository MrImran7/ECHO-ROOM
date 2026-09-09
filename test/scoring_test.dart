import 'package:flutter_test/flutter_test.dart';
import 'package:echo_room/game/scoring.dart';
void main() {
  test('perfect instant find yields full component sum', () {
    final r = calculateScore(won: true, elapsed: 0, limit: 5, mistakes: 0, hints: 0, streak: 1);
    expect(r.total, 2000); expect(r.stars, 3);
  });
  test('milestone multipliers apply at exact boundaries', () {
    expect([0, 2, 3, 4, 5, 9, 10, 20].map(streakMultiplier), [1, 1, 1.2, 1.2, 1.5, 1.5, 2, 2]);
  });
  test('hints and mistakes lower score; no negative speed bonus', () {
    final perfect = calculateScore(won: true, elapsed: 1, limit: 5, mistakes: 0, hints: 0, streak: 1);
    final assisted = calculateScore(won: true, elapsed: 1, limit: 5, mistakes: 1, hints: 2, streak: 1);
    expect(assisted.total, lessThan(perfect.total));
    expect(calculateScore(won: true, elapsed: 8, limit: 5, mistakes: 3, hints: 3, streak: 0).speed, 0);
  });
  test('failure cannot earn score or stars', () {
    final r = calculateScore(won: false, elapsed: 0, limit: 5, mistakes: 0, hints: 0, streak: 20);
    expect(r.total, 0); expect(r.stars, 0);
  });
  test('star thresholds account for time, mistakes and hints', () {
    int stars(double time, int misses, int hints) => calculateStars(won: true, elapsed: time, limit: 10, mistakes: misses, hints: hints);
    expect(stars(5, 0, 0), 3); expect(stars(5.01, 0, 0), 2);
    expect(stars(1, 1, 0), 2); expect(stars(1, 0, 1), 2);
    expect(stars(8.5, 1, 1), 2); expect(stars(8.51, 0, 0), 1);
    expect(stars(1, 0, 3), 1);
  });
  test('invalid scoring inputs fail with a clear argument error', () {
    for (final limit in [0.0, -1.0, double.nan, double.infinity]) {
      expect(() => calculateScore(won: true, elapsed: 1, limit: limit,
        mistakes: 0, hints: 0, streak: 0), throwsArgumentError);
    }
  });
}
