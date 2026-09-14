import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_room/app/providers.dart';
import 'package:echo_room/daily/daily_service.dart';
import 'package:echo_room/daily/debug_daily_lab.dart';
import 'package:echo_room/game/session.dart';
import 'package:echo_room/game/session_controller.dart';
import 'package:echo_room/models/progress.dart';
import 'package:echo_room/screens/daily_screen.dart';
import 'package:echo_room/storage/progress_repository.dart';
import 'package:echo_room/widgets/common.dart';

import 'controller_test.dart' show ready, TestClock;
import 'test_support.dart';

class FinalWriteRepository extends MemoryProgressRepository {
  bool failFinal = false;
  int finalWrites = 0;
  Completer<void>? gate;
  @override
  Future<void> save(Progress p) async {
    if (p.daily.values.any((r) => r.finalized)) {
      finalWrites++;
      if (failFinal) throw StateError('simulated disk failure');
    }
    await gate?.future;
    await super.save(p);
  }
}

void main() {
  final date = DateTime(2026, 9, 11, 23, 59);
  for (final phase in [GamePhase.observing, GamePhase.blackout, GamePhase.answering, GamePhase.correct]) {
    test('process death after $phase checkpoint preserves official reservation', () async {
      final repo = FinalWriteRepository();
      final clock = TestClock(date);
      final c = await ready(repo, clock: clock);
      final controller = c.read(sessionProvider.notifier);
      await controller.start(1, daily: true);
      final s = controller.game!..ready();
      final targetPhase = phase == GamePhase.correct ? GamePhase.answering : phase;
      for (var i = 0; i < 1000 && s.phase != targetPhase; i++) { s.advance(.025); }
      expect(s.phase, targetPhase);
      if (phase == GamePhase.answering) { await controller.hint(); }
      if (phase == GamePhase.correct) {
        for (var y = 0; y < 100 && s.phase != GamePhase.correct; y++) {
          for (var x = 0; x < 100 && s.phase != GamePhase.correct; x++) {
            if (s.targets.contains(s.hitTester.resolve(x / 100, y / 100))) s.tap(x / 100, y / 100);
          }
        }
      }
      await controller.checkpoint();
      final before = (await repo.load()).activeSession!;
      final streak = (await repo.load()).dailyStreak;
      c.dispose();
      clock.value = DateTime(2026, 9, 12, 0, 1);
      final next = await ready(repo, clock: clock);
      addTearDown(next.dispose);
      final restored = next.read(sessionProvider.notifier)..restore();
      expect(restored.game!.toJson(), before);
      expect(restored.game!.paused, true);
      expect(next.read(profileProvider).dailyStreak, streak);
      restored.tick(100);
      expect(restored.game!.toJson(), before);
      restored.resume();
      if (phase == GamePhase.correct) {
        restored.tick(1.1);
        await Future<void>.delayed(Duration.zero);
        await restored.retrySave();
        await restored.retrySave();
        expect(repo.finalWrites, 1);
        expect((await repo.load()).daily['2026-09-11']!.status, 'won');
        expect((await repo.load()).daily['2026-09-12'], isNull);
      } else {
        expect(restored.game!.hints, phase == GamePhase.answering ? 1 : 0);
        expect((await repo.load()).daily.length, 1);
      }
    });
  }

  test('failed final write retries once without rolling preferences back', () async {
    final repo = FinalWriteRepository();
    final c = await ready(repo);
    addTearDown(c.dispose);
    final controller = c.read(sessionProvider.notifier);
    await controller.start(1, daily: true);
    win(controller.game!);
    repo.failFinal = true;
    await controller.retrySave();
    expect(controller.completion, isNull);
    expect((await repo.load()).daily.values.single.finalized, false);
    repo.failFinal = false;
    await c.read(profileProvider.notifier).settings(const UserSettings(sound: false));
    await controller.retrySave();
    await controller.retrySave();
    final saved = await repo.load();
    expect(saved.settings.sound, false);
    expect(saved.dailyStreak, 1);
    expect(saved.daily.length, 1);
    expect(saved.activeSession, isNull);
  });

  test('rapid daily start creates one reservation while disk write is pending', () async {
    final repo = FinalWriteRepository();
    final c = await ready(repo);
    addTearDown(c.dispose);
    repo.gate = Completer<void>();
    final controller = c.read(sessionProvider.notifier);
    final first = controller.start(1, daily: true);
    await expectLater(controller.start(1, daily: true), throwsStateError);
    repo.gate!.complete();
    await first;
    expect((await repo.load()).daily.length, 1);
    expect((await repo.load()).activeSession!['runId'], controller.game!.runId);
  });

  test('pause persists interrupted status; reset makes today available', () async {
    final repo = MemoryProgressRepository();
    final c = await ready(repo);
    addTearDown(c.dispose);
    final controller = c.read(sessionProvider.notifier);
    await controller.start(1, daily: true);
    expect(dailyAttemptState(c.read(profileProvider), date), DailyAttemptState.started);
    controller.pause();
    await controller.checkpoint();
    expect((await repo.load()).daily.values.single.state, DailyAttemptState.interrupted);
    await c.read(profileProvider.notifier).reset();
    expect(dailyAttemptState(await repo.load(), date), DailyAttemptState.available);
    expect((await repo.load()).activeSession, isNull);
    await controller.start(1, daily: true);
    expect(controller.game!.dailyDate, '2026-09-11');
  });

  test('official payload contains normalized standalone submission fields', () {
    const record = DailyRecord(levelId: 7, status: 'won', puzzleVersion: 2,
        time: 1.234, score: 1600, mistakes: 0, hintsUsed: 1);
    expect(record.officialPayload('2026-09-11'), {
      'date': '2026-09-11', 'dailyPoolVersion': 2, 'puzzleId': 'apartment-7',
      'solved': true, 'responseTimeMs': 1234, 'score': 1600,
      'mistakes': 0, 'hintsUsed': 1,
    });
    expect(() => const DailyRecord(levelId: 7).officialPayload('2026-09-11'), throwsStateError);
    expect(() => const DailyRecord(levelId: 7, status: 'invalid').state, throwsFormatException);
  });

  test('date moving backwards preserves completed historical records', () async {
    final repo = MemoryProgressRepository()..value = Progress(daily: const {
      '2026-09-11': DailyRecord(levelId: 7, status: 'lost'),
    });
    final clock = TestClock(DateTime(2026, 9, 12));
    final c = await ready(repo, clock: clock);
    addTearDown(c.dispose);
    expect(dailyStatus(c.read(profileProvider), clock.now()), 'NEW');
    clock.value = DateTime(2026, 9, 11);
    expect(dailyStatus(c.read(profileProvider), clock.now()), 'MISSED');
    await expectLater(c.read(sessionProvider.notifier).start(1, daily: true), throwsStateError);
    expect((await repo.load()).daily['2026-09-11']!.status, 'lost');
  });

  testWidgets('entry opened before midnight starts new date once and back preserves it', (tester) async {
    final clock = TestClock(date);
    final repo = MemoryProgressRepository();
    final c = await ready(repo, clock: clock);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c,
        child: const MaterialApp(home: DailyScreen())));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('PLAY DAILY ROOM'), 100);
    final play = tester.widgetList<ActionButton>(find.byType(ActionButton))
        .firstWhere((b) => b.label == 'PLAY DAILY ROOM').onPressed!;
    clock.value = DateTime(2026, 9, 12);
    final first = play();
    await play();
    for (var i = 0; i < 8; i++) { await tester.pump(const Duration(milliseconds: 80)); }
    final controller = c.read(sessionProvider.notifier);
    expect(controller.game!.dailyDate, '2026-09-12');
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(controller.game!.paused, true);
    expect(c.read(profileProvider).daily.values.single.finalized, false);
    await tester.pumpWidget(const SizedBox());
    unawaited(first);
  });

  testWidgets('Daily Lab simulated dates and saves never reach real repository', (tester) async {
    final repo = MemoryProgressRepository();
    final c = await ready(repo);
    addTearDown(c.dispose);
    final before = (await repo.load()).toJson();
    await tester.pumpWidget(UncontrolledProviderScope(container: c,
        child: MaterialApp(home: DailyDebugLab(baseClock: TestClock(date)))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('YESTERDAY SOLVED'), 150,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('YESTERDAY SOLVED'));
    await tester.pumpAndSettle();
    expect((await repo.load()).toJson(), before);
    expect(c.read(profileProvider).daily, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
