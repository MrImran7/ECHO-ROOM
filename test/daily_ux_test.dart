import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_room/app/providers.dart';
import 'package:echo_room/app/theme.dart';
import 'package:echo_room/daily/daily_service.dart';
import 'package:echo_room/daily/daily_result_body.dart';
import 'package:echo_room/daily/debug_daily_lab.dart';
import 'package:echo_room/game/session_controller.dart';
import 'package:echo_room/models/progress.dart';
import 'package:echo_room/screens/daily_screen.dart';
import 'package:echo_room/storage/progress_repository.dart';
import 'controller_test.dart' show ready, TestClock;
import 'test_support.dart';

void main() {
  test('malformed optional history is excluded without losing chapter progress', () {
    final p = Progress.fromJson({'highestLevel': 8, 'daily': {
      '2026-09-01': {'levelId': 7, 'status': 'won', 'time': 1.25},
      '2026-09-02': {'levelId': 7, 'status': 'unknown'},
      '2026-09-03': {'levelId': 'wrong'},
      '2026-09-04': {'levelId': 7, 'hintsUsed': 4},
      '2026-09-05': {'levelId': 7, 'time': -1},
      '2026-02-30': {'levelId': 7},
      'nonsense': <String, dynamic>{},
      '2026-09-06': null,
    }});
    expect(p.highestLevel, 8);
    expect(p.daily.keys, ['2026-09-01']);
    expect(p.daily.values.single.time, 1.25);
    expect(Progress.fromJson(p.toJson()).toJson(), p.toJson());
  });

  test('payload rejects impossible values and non-calendar keys', () {
    for (final record in [
      const DailyRecord(levelId: 7, status: 'won', time: -1),
      const DailyRecord(levelId: 7, status: 'won', mistakes: -1),
      const DailyRecord(levelId: 7, status: 'won', hintsUsed: 4),
      const DailyRecord(levelId: 7, status: 'won', puzzleVersion: 0),
    ]) {
      expect(() => record.officialPayload('2026-09-11'), throwsFormatException);
    }
    expect(() => const DailyRecord(levelId: 7, status: 'won')
        .officialPayload('2026-02-30'), throwsFormatException);
  });

  test('pool validates content and rejects duplicates, missing or disallowed IDs', () {
    final catalog = loadCatalog();
    LocalDailyChallengeSource.validatePool(catalog);
    for (final ids in <List<int>>[[], [7, 7], [99], [1], [20]]) {
      expect(() => LocalDailyChallengeSource.validatePool(catalog, ids: ids), throwsFormatException);
    }
  });

  test('missing reserved puzzle cannot consume or replace official attempt', () async {
    final repo = MemoryProgressRepository()..value = Progress(daily: const {
      '2026-09-11': DailyRecord(levelId: 999),
    });
    final c = await ready(repo);
    addTearDown(c.dispose);
    final before = (await repo.load()).toJson();
    await expectLater(c.read(sessionProvider.notifier).start(1, daily: true), throwsStateError);
    expect((await repo.load()).toJson(), before);
    final saved = session(daily: '2026-09-11').toJson()..['levelId'] = 999;
    await c.read(profileProvider.notifier).commit(repo.value.patch({'activeSession': saved}));
    final reserved = (await repo.load()).toJson();
    expect(() => c.read(sessionProvider.notifier).restore(), throwsStateError);
    expect((await repo.load()).toJson(), reserved);
  });

  testWidgets('pending data never briefly exposes NEW or PLAY', (tester) async {
    final pending = Completer<Progress>();
    await tester.pumpWidget(ProviderScope(overrides: [
      savedProgressProvider.overrideWith((ref) => pending.future),
      catalogProvider.overrideWith((ref) async => loadCatalog()),
    ], child: const MaterialApp(home: DailyScreen())));
    await tester.pump();
    expect(find.text('PLAY DAILY ROOM'), findsNothing);
    expect(find.text('NEW · ONE CHANCE'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    pending.complete(Progress());
  });

  for (final scale in [1.0, 1.3, 1.5, 2.0]) {
    testWidgets('daily entry history and result remain usable at ${scale}x on 320px phone', (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = MemoryProgressRepository()..value = Progress(daily: const {
        '2026-09-10': DailyRecord(levelId: 7, status: 'won', time: 2.5),
      });
      final c = await ready(repo);
      addTearDown(c.dispose);
      Widget app(Widget home) => UncontrolledProviderScope(container: c,
        child: MaterialApp(theme: EchoTheme.theme,
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true), child: child!),
          home: home));
      await tester.pumpWidget(app(const DailyScreen()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('PLAY DAILY ROOM'), 120);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('SOLVED · 2.50s'), 120);
      expect(tester.takeException(), isNull);
      var homePressed = false;
      await tester.pumpWidget(app(Scaffold(body: DailyResultBody(
        date: '2026-09-11', record: const DailyRecord(levelId: 7, status: 'won', time: 1.5, score: 1700),
        progress: repo.value, onHome: () async { homePressed = true; },
      ))));
      await tester.pumpAndSettle();
      expect(find.text('NEW DAILY BEST'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('HOME'), 120);
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(tester.element(find.text('HOME')),
          alignment: 0.5);
      await tester.pumpAndSettle();
      expect(find.text('HOME').hitTestable(), findsOneWidget);
      await tester.tap(find.text('HOME'));
      await tester.pumpAndSettle();
      expect(homePressed, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('interrupted entry and diagnostics retain owning date after midnight', (tester) async {
    final saved = session(level: 7, daily: '2026-09-11').toJson();
    final repo = MemoryProgressRepository()..value = Progress(
      activeSession: saved,
      daily: const {'2026-09-11': DailyRecord(levelId: 7, puzzleVersion: 2)},
    );
    final c = await ready(repo, clock: TestClock(DateTime(2026, 9, 12)));
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c,
      child: const MaterialApp(home: DailyScreen())));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(DailyScreen));
    final label = MaterialLocalizations.of(context).formatFullDate(DateTime(2026, 9, 11));
    expect(find.text(label), findsOneWidget);
    await tester.scrollUntilVisible(find.text('RESUME DAILY ROOM'), 120);
    await tester.scrollUntilVisible(find.text('DEBUG · 2026-09-11 · pool v2 · puzzle 7'), 120);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('lab exit restores real profile and does not retain overrides', (tester) async {
    final repo = MemoryProgressRepository();
    final c = await ready(repo);
    addTearDown(c.dispose);
    final before = (await repo.load()).toJson();
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(UncontrolledProviderScope(container: c,
      child: MaterialApp(navigatorKey: nav, home: const Scaffold(body: Text('REAL PLAYER')))));
    unawaited(nav.currentState!.push<void>(MaterialPageRoute(builder: (_) =>
      DailyDebugLab(baseClock: TestClock(DateTime(2026, 9, 11))))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('YESTERDAY SOLVED'), 160,
      scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('YESTERDAY SOLVED'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('EXIT LAB'), 100,
      scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('EXIT LAB'));
    await tester.pumpAndSettle();
    expect(find.text('REAL PLAYER'), findsOneWidget);
    expect((await repo.load()).toJson(), before);
    expect(c.read(profileProvider).daily, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
