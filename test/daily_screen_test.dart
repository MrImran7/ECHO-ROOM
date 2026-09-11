import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_room/models/progress.dart';
import 'package:echo_room/widgets/common.dart';
import 'package:echo_room/screens/daily_screen.dart';
import 'package:echo_room/services/progression_service.dart';
import 'package:echo_room/storage/progress_repository.dart';

import 'controller_test.dart' show ready, TestClock;
import 'result_robustness_test.dart' show showResult, reveal;
import 'test_support.dart';

void main() {
  for (final won in [true, false]) {
    testWidgets('daily ${won ? 'success' : 'failure'} is readable and has no replay', (tester) async {
      final s = session(daily: '2026-09-11');
      if (won) { win(s); } else { s.advance(100); }
      final done = completeSession(Progress(), s, DateTime(2026, 9, 11), 20);
      await showResult(tester, s, done, MemoryProgressRepository());
      expect(find.text(won ? 'DAILY ROOM COMPLETE' : 'DAILY ROOM MISSED'), findsOneWidget);
      expect(find.text('NEXT ROOM'), findsNothing);
      expect(find.text('REPLAY'), findsNothing);
      expect(find.byType(Stars), findsNothing);
      await reveal(tester, 'BEST DAILY STREAK');
      expect(tester.takeException(), isNull);
      await reveal(tester, 'HOME');
      await tester.tap(find.text('HOME'));
      await tester.pumpAndSettle();
      expect(find.text('HOME SENTINEL'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('completed entry refreshes at resume after local midnight without polling', (tester) async {
    final clock = TestClock(DateTime(2026, 9, 11, 23, 59));
    final repo = MemoryProgressRepository()..value = Progress(daily: const {
      '2026-09-11': DailyRecord(levelId: 7, status: 'won', time: 1.25),
    });
    final c = await ready(repo, clock: clock);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c,
      child: const MaterialApp(home: DailyScreen())));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('TODAY COMPLETE'), 100);
    expect(find.text('PLAY DAILY ROOM'), findsNothing);
    clock.value = DateTime(2026, 9, 12);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('PLAY DAILY ROOM'), 100);
    expect(find.text('TODAY COMPLETE'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
