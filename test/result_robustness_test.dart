import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_room/app/providers.dart';
import 'package:echo_room/app/theme.dart';
import 'package:echo_room/game/scoring.dart';
import 'package:echo_room/game/session.dart';
import 'package:echo_room/game/session_controller.dart';
import 'package:echo_room/models/progress.dart';
import 'package:echo_room/screens/result_screen.dart';
import 'package:echo_room/screens/settings_screen.dart';
import 'package:echo_room/services/audio_service.dart';
import 'package:echo_room/services/progression_service.dart';
import 'package:echo_room/storage/progress_repository.dart';
import 'package:echo_room/widgets/common.dart';

import 'test_support.dart';

class GatedRepository extends MemoryProgressRepository {
  Completer<void>? gate;
  int writes = 0;
  @override
  Future<void> save(Progress progress) async {
    writes++;
    await gate?.future;
    await super.save(progress);
  }
}

Future<ProviderContainer> showResult(WidgetTester tester, GameSession s, Completion done, MemoryProgressRepository repo) async {
  repo.value = done.progress;
  tester.view.physicalSize = const Size(320, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(overrides: [
    repositoryProvider.overrideWithValue(repo),
    catalogProvider.overrideWith((ref) async => loadCatalog()),
    audioProvider.overrideWithValue(SilentAudio()),
    hapticsProvider.overrideWithValue(HapticsService()..enabled = false),
  ]);
  addTearDown(container.dispose);
  await container.read(savedProgressProvider.future);
  await container.read(catalogProvider.future);
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      navigatorKey: navigator,
      theme: EchoTheme.theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: TextScaler.linear(1.3)),
        child: child!,
      ),
      home: const Scaffold(body: Text('HOME SENTINEL')),
    ),
  ));
  unawaited(navigator.currentState!.push<void>(MaterialPageRoute(builder: (_) => ResultScreen(session: s, completion: done))));
  await tester.pumpAndSettle();
  return container;
}

Future<void> reveal(WidgetTester tester, String label) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, 4000));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text(label), 160, scrollable: find.byType(Scrollable).first, maxScrolls: 40);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Level 20 persists completion and shows story, milestones and all awards without Level 21', (tester) async {
    var progress = Progress();
    for (var id = 1; id < 20; id++) {
      final s = session(level: id, runId: 'room-$id');
      win(s);
      progress = completeSession(progress, s, DateTime(2026, 9, 10), 20).progress;
    }
    // Exercise the maximal award layout alongside a valid full-chapter save.
    progress = progress.patch({'achievements': []});
    final s = session(level: 20, runId: 'room-20');
    win(s);
    final done = completeSession(progress, s, DateTime(2026, 9, 10), 20);
    expect(done.score.stars, 3);
    expect(done.newAchievements.length, 5);
    final repo = MemoryProgressRepository();
    await showResult(tester, s, done, repo);
    expect(find.text('NEXT ROOM'), findsNothing);
    expect(find.text('ROOM COMPLETE'), findsOneWidget);
    expect(tester.widgetList<TweenAnimationBuilder<double>>(find.byType(TweenAnimationBuilder<double>)).every((w) => w.duration == Duration.zero), true);
    for (final label in ['FIRST FIND', 'PERFECT MEMORY', 'EAGLE EYE', 'NO HELP NEEDED', 'OBSERVER']) {
      await reveal(tester, label);
      expect(tester.takeException(), isNull);
    }
    await reveal(tester, 'IMPOSSIBLE · 20 IN A ROW');
    await reveal(tester, '“${s.level.storyText}”');
    await reveal(tester, 'CHAPTER 1 COMPLETE\nThe next door is not open. Yet.');
    final restored = await repo.load();
    expect(restored.highestLevel, 20);
    expect(restored.levels.length, 20);
    expect(restored.achievements, contains('observer'));
    expect(restored.activeSession, isNull);
    await reveal(tester, 'HOME');
    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle();
    expect(find.text('HOME SENTINEL'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final level in [1, 20]) {
    testWidgets('result $level admits one navigation while storage is pending', (tester) async {
      final s = session(level: level);
      win(s);
      final done = completeSession(Progress().patch({'highestLevel': level}), s, DateTime(2026, 9, 10), 20);
      final repo = GatedRepository();
      final container = await showResult(tester, s, done, repo);
      final primary = level == 20 ? 'REPLAY' : 'NEXT ROOM';
      await reveal(tester, primary);
      final play = tester.widgetList<ActionButton>(find.byType(ActionButton)).firstWhere((b) => b.label == primary).onPressed!;
      await reveal(tester, 'HOME');
      final home = tester.widgetList<ActionButton>(find.byType(ActionButton)).firstWhere((b) => b.label == 'HOME').onPressed!;
      await reveal(tester, primary);
      repo.gate = Completer<void>();
      final first = play();
      await tester.pump();
      await play();
      await home();
      expect(tester.widgetList<ActionButton>(find.byType(ActionButton)).every((b) => b.onPressed == null), true);
      expect(repo.writes, 1);
      repo.gate!.complete();
      await first;
      for (var i = 0; i < 8; i++) { await tester.pump(const Duration(milliseconds: 80)); }
      expect(container.read(sessionProvider.notifier).game!.level.levelId, level == 20 ? 20 : 2);
      expect(find.byType(ResultScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final stars in [0, 1, 3]) {
    testWidgets('$stars stars and long scores fit a narrow phone with sound and haptics off', (tester) async {
      final s = session();
      if (stars == 0) { reachAnswer(s); s.advance(s.remaining + 2); } else { win(s); }
      final base = completeSession(Progress(), s, DateTime(2026, 9, 10), 20);
      final done = Completion(base.progress, ScoreResult(total: stars == 0 ? 0 : 1234567890, stars: stars, speed: 0, accuracy: 0, multiplier: 1), {}, null, null);
      await showResult(tester, s, done, MemoryProgressRepository());
      expect(find.text(stars == 0 ? 'ROOM UNRESOLVED' : 'ROOM COMPLETE'), findsOneWidget);
      expect(tester.widget<Stars>(find.byType(Stars)).count, stars);
      await reveal(tester, stars == 0 ? 'TRY AGAIN' : 'NEXT ROOM');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('rapid settings toggles preserve each other and survive reload', (tester) async {
    final repo = MemoryProgressRepository();
    final s = session(); win(s);
    final done = completeSession(Progress(), s, DateTime(2026, 9, 10), 20);
    final container = await showResult(tester, s, done, repo);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const MaterialApp(home: SettingsScreen())));
    await tester.pumpAndSettle();
    final tiles = tester.widgetList<SwitchListTile>(find.byType(SwitchListTile)).toList();
    for (final title in ['Music', 'Sound effects', 'Haptics']) {
      tiles.firstWhere((t) => (t.title as Text).data == title).onChanged!(false);
    }
    await tester.pumpAndSettle();
    final restored = await repo.load();
    expect(restored.settings.music, false);
    expect(restored.settings.sound, false);
    expect(restored.settings.haptics, false);
    expect(container.read(hapticsProvider).enabled, false);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

}
