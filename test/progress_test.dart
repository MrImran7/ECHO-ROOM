import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:echo_room/core/config.dart';
import 'package:echo_room/models/progress.dart';
import 'package:echo_room/models/scene.dart';
import 'package:echo_room/services/progression_service.dart';
import 'package:echo_room/services/lives_service.dart';
import 'package:echo_room/storage/progress_repository.dart';
import 'package:echo_room/achievements/definitions.dart';

import 'test_support.dart';

void main() {
  test('win unlocks exactly the next level, awards first-clear hints, idempotently', () {
    final s = session();
    win(s);
    final done = completeSession(Progress(), s, DateTime(2026), 20);
    expect(done.progress.highestLevel, 2);
    expect(done.progress.hints, GameConfig.initialHints + 2);
    expect(done.progress.levels[1]!.stars, 3);
    expect(done.progress.achievements, contains('first_find'));
    expect(done.progress.achievements, contains('eagle_eye'));
    final again = completeSession(done.progress, s, DateTime(2026), 20);
    expect(again.progress.toJson(), done.progress.toJson());
  });
  test(
    'replay retains independent best metrics and gives no repeat hint reward',
    () {
      final first = session(runId: 'first');
      win(first, elapsed: .4);
      final p = completeSession(Progress(), first, DateTime(2026), 20).progress;
      final replay = session(runId: 'second');
      win(replay, elapsed: 3);
      final next = completeSession(p, replay, DateTime(2026), 20).progress;
      expect(next.hints, p.hints);
      expect(next.levels[1]!.bestTime, p.levels[1]!.bestTime);
      expect(next.levels[1]!.stars, 3);
      expect(next.perfectLevels.length, 1);
    },
  );
  test('failure consumes a life, resets streak, and cannot advance', () {
    final s = session()..advance(100);
    final p = completeSession(
      Progress(streak: 5),
      s,
      DateTime(2026),
      20,
    ).progress;
    expect(p.streak, 0);
    expect(p.lives, 4);
    expect(p.highestLevel, 1);
    expect(p.levels, isEmpty);
    expect(
      completeSession(
        Progress(),
        s,
        DateTime(2026),
        20,
        livesEnabled: false,
      ).progress.lives,
      5,
    );
  });
  test('chapter completion caps progression and unlocks definition-driven achievements', () {
    var p = Progress();
    for (var level = 1; level <= 20; level++) {
      final s = session(level: level, runId: '$level');
      win(s);
      p = completeSession(p, s, DateTime(2026), 20).progress;
    }
    expect(p.highestLevel, 20);
    expect(p.levels.length, 20);
    expect(p.achievements, achievements.map((a) => a.id).toSet());
    expect(p.collectibles.length, 4);
    expect(p.streak, 20);
  });
  test(
    'versioned save round-trips settings, records, collection and checkpoint',
    () async {
      final s = session();
      reachAnswer(s);
      s.advance(1.2);
      final p = Progress(
        settings: const UserSettings(
          music: false,
          sound: false,
          haptics: false,
        ),
        activeSession: s.toJson(),
        lifeAnchor: DateTime.utc(2026, 9, 9),
        lives: 3,
        daily: const {
          '2026-09-09': DailyRecord(levelId: 4, status: 'won', time: 1.25),
        },
        achievements: {'first_find'},
        collectibles: {'brass_key'},
        levels: const {1: LevelRecord(score: 1234, stars: 2, bestTime: 2.4)},
      );
      final decoded = Progress.fromJson(
        jsonDecode(jsonEncode(p.toJson())) as Json,
      );
      expect(decoded.toJson(), p.toJson());
      final repo = MemoryProgressRepository();
      await repo.save(p);
      expect((await repo.load()).toJson(), p.toJson());
      expect(() => Progress.fromJson({'version': 99}), throwsFormatException);
    },
  );
  test(
    'lives accumulate complete intervals, preserve remainder, cap at five',
    () {
      const life = LivesService(regeneration: Duration(minutes: 20));
      final now = DateTime.utc(2026, 9, 9);
      var p = life.consume(Progress(), now);
      expect(p.lives, 4);
      p = life.consume(p, now.add(const Duration(minutes: 5)));
      expect(p.lifeAnchor, now);
      p = life.refresh(p, now.add(const Duration(minutes: 39)));
      expect(p.lives, 4);
      expect(p.lifeAnchor, now.add(const Duration(minutes: 20)));
      p = life.refresh(p, now.add(const Duration(days: 4)));
      expect(p.lives, 5);
      expect(p.lifeAnchor, null);
    },
  );
  test(
    'clock rollback does not regenerate lives; zero lives stay nonnegative',
    () {
      const life = LivesService();
      final now = DateTime(2026);
      final p = Progress(lives: 0, lifeAnchor: now);
      expect(life.refresh(p, now.subtract(const Duration(days: 1))).lives, 0);
      expect(life.consume(p, now).lives, 0);
    },
  );
  test('unresolved sessions cannot award progression', () {
    expect(
      () => completeSession(Progress(), session(), DateTime(2026), 20),
      throwsStateError,
    );
  });
}
