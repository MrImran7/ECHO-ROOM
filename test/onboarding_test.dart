import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_room/app/providers.dart';
import 'package:echo_room/app/theme.dart';
import 'package:echo_room/models/progress.dart';
import 'package:echo_room/onboarding/guidance.dart';
import 'package:echo_room/onboarding/how_to_play_screen.dart';
import 'package:echo_room/screens/settings_screen.dart';
import 'package:echo_room/storage/progress_repository.dart';
import 'controller_test.dart' show ready;
import 'package:echo_room/widgets/common.dart';
import 'package:echo_room/services/progression_service.dart';
import 'result_robustness_test.dart' show showResult;
import 'test_support.dart' show session, win;

Widget app(ProviderContainer c, Widget home, {double scale = 1}) =>
    UncontrolledProviderScope(container: c, child: MaterialApp(
      theme: EchoTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale), disableAnimations: true), child: child!),
      home: home));
Future<void> tapVisible(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(find.text(text), 120);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}
class FailingIntroRepository extends MemoryProgressRepository {
  bool fail = true;
  @override
  Future<void> save(Progress progress) async {
    if (fail) throw StateError('Storage unavailable');
    await super.save(progress);
  }
}
class PendingIntroRepository extends MemoryProgressRepository {
  final gate = Completer<void>();
  int writes = 0;
  @override
  Future<void> save(Progress progress) async {
    writes++;
    await gate.future;
    await super.save(progress);
  }
}
void main() {
  test('skip suppresses optional cues and preserves essential guidance', () async {
    final repo = MemoryProgressRepository();
    final c = await ready(repo); addTearDown(c.dispose);
    await c.read(profileProvider.notifier).finishIntro(skipped: true);
    final p = await repo.load();
    expect(p.settings.seenTips, containsAll(['answer', 'success', 'stars']));
    expect(p.settings.seenTips.intersection({'wrong', 'hint', 'daily'}), isEmpty);
    expect(p.levels, isEmpty);
    expect(p.daily, isEmpty);
    expect(p.activeSession, isNull);
  });
  testWidgets('rapid skip and back make one save and one Home transition', (tester) async {
    final repo = PendingIntroRepository();
    final c = await ready(repo); addTearDown(c.dispose);
    await tester.pumpWidget(app(c, const FirstRunGate(child: Scaffold(body: Text('HOME')))));
    expect(find.text('HOME'), findsNothing);
    await tester.tap(find.text('SKIP'));
    await tester.tap(find.text('SKIP'));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(repo.writes, 1);
    expect(find.text('HOME'), findsNothing);
    repo.gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });
  testWidgets('each intro step survives background and unfinished restart starts at one', (tester) async {
    final repo = MemoryProgressRepository();
    var c = await ready(repo);
    for (var step = 0; step < 3; step++) {
      if (step == 0) {
        await tester.pumpWidget(app(c, const FirstRunGate(child: Scaffold(body: Text('HOME')))));
        await tester.pumpAndSettle();
      } else {
        await tapVisible(tester, 'CONTINUE');
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('STEP ${step + 1} OF 3'), findsOneWidget);
      expect(repo.value.settings.introVersion, 0);
    }
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    c = await ready(repo); addTearDown(c.dispose);
    await tester.pumpWidget(app(c, const FirstRunGate(child: Scaffold(body: Text('HOME')))));
    await tester.pumpAndSettle();
    expect(find.text('LOOK CLOSELY'), findsOneWidget);
  });
  testWidgets('first result uses one optional cue after navigation despite multiple awards', (tester) async {
    final s = session(); win(s);
    final done = completeSession(Progress(), s, DateTime(2026, 9, 11), 20);
    expect(done.newAchievements, isNotEmpty);
    await showResult(tester, s, done, MemoryProgressRepository());
    final children = tester.widget<PageBody>(find.byType(PageBody)).children;
    final cues = children.whereType<Guidance>().toList();
    expect(cues.length, 1);
    expect(cues.single.id, 'stars');
    final home = children.indexWhere((w) => w is ActionButton && w.label == 'HOME');
    expect(children.indexOf(cues.single), greaterThan(home));
    expect(children.whereType<ActionButton>().any((w) => w.label == 'NEXT ROOM'), true);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('stars expose one aggregate spoken value', (tester) async {
    final semantics = tester.ensureSemantics(); addTearDown(semantics.dispose);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Stars(2))));
    expect(find.bySemanticsLabel('2 of 3 stars'), findsOneWidget);
    final label = tester.widget<Semantics>(find.descendant(
      of: find.byType(Stars), matching: find.byType(Semantics)).first);
    expect(label.excludeSemantics, true);
  });
  testWidgets('unexpected landscape keeps intro controls reachable', (tester) async {
    tester.view.physicalSize = const Size(740, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = await ready(MemoryProgressRepository()); addTearDown(c.dispose);
    await tester.pumpWidget(app(c, const FirstRunGate(child: Scaffold(body: Text('HOME')))));
    await tester.pumpAndSettle();
    await tapVisible(tester, 'SKIP');
    expect(find.text('HOME'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed intro save stays recoverable until retry succeeds', (tester) async {
    final repo = FailingIntroRepository();
    final c = await ready(repo); addTearDown(c.dispose);
    await tester.pumpWidget(app(c, const FirstRunGate(child: Scaffold(body: Text('HOME')))));
    await tester.pumpAndSettle();
    await tapVisible(tester, 'SKIP');
    expect(find.text('LOOK CLOSELY'), findsOneWidget);
    expect(repo.value.settings.introVersion, 0);
    repo.fail = false;
    await tapVisible(tester, 'SKIP');
    expect(find.text('HOME'), findsOneWidget);
    expect(repo.value.settings.introVersion, 1);
  });
  test('legacy progression skips intro while empty saves remain new', () {
    expect(Progress.fromJson({}).settings.introVersion, 0);
    for (final old in <Map<String, dynamic>>[
      {'highestLevel': 2}, {'levels': {'1': {'stars': 1}}},
      {'daily': {'2026-09-11': {'levelId': 7, 'status': 'won'}}},
      {'activeSession': <String, dynamic>{}},
      {'achievements': ['first_find']}, {'collectibles': ['old_key']},
    ]) {
      expect(Progress.fromJson(old).settings.introVersion, 1);
    }
    expect(Progress.fromJson({'highestLevel': 5, 'settings': {'introVersion': 0}})
        .settings.introVersion, 0);
  });
  test('intro and tip preferences survive settings, restart and progress reset', () async {
    final repo = MemoryProgressRepository();
    final c = await ready(repo);
    final p = c.read(profileProvider.notifier);
    await p.finishIntro();
    await p.markTip('hint');
    await p.settings(c.read(profileProvider).settings.copyWith(sound: false));
    await p.reset();
    c.dispose();
    final restored = await ready(repo);
    addTearDown(restored.dispose);
    final settings = restored.read(profileProvider).settings;
    expect(settings.introVersion, 1);
    expect(settings.seenTips, {'hint'});
    expect(settings.sound, false);
    expect(restored.read(profileProvider).highestLevel, 1);
  });
  for (final skip in [true, false]) {
    testWidgets('${skip ? 'skip' : 'complete'} exits fresh intro without creating game', (tester) async {
      final repo = MemoryProgressRepository();
      final c = await ready(repo); addTearDown(c.dispose);
      await tester.pumpWidget(app(c, const FirstRunGate(child: Scaffold(body: Text('HOME SENTINEL')))));
      await tester.pumpAndSettle();
      expect(find.text('LOOK CLOSELY'), findsOneWidget);
      if (!skip) {
        await tapVisible(tester, 'CONTINUE');
        await tapVisible(tester, 'CONTINUE');
      }
      await tapVisible(tester, skip ? 'SKIP' : 'LET’S PLAY');
      expect(find.text('HOME SENTINEL'), findsOneWidget);
      expect(repo.value.settings.introVersion, 1);
      expect(repo.value.activeSession, isNull);
      expect(repo.value.levels, isEmpty);
      expect(repo.value.daily, isEmpty);
      expect(repo.value.lives, Progress().lives);
    });
  }
  testWidgets('back returns to previous intro step and background retains step', (tester) async {
    final c = await ready(MemoryProgressRepository()); addTearDown(c.dispose);
    await tester.pumpWidget(app(c, const FirstRunGate(child: Scaffold(body: Text('HOME')))));
    await tester.pumpAndSettle();
    await tapVisible(tester, 'CONTINUE');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('LIGHTS OUT'), findsOneWidget);
    await tester.binding.handlePopRoute(); await tester.pumpAndSettle();
    expect(find.text('LOOK CLOSELY'), findsOneWidget);
    expect(c.read(profileProvider).settings.introVersion, 0);
  });
  testWidgets('Settings replay and back leave all progress unchanged', (tester) async {
    final repo = MemoryProgressRepository()..value = Progress(highestLevel: 8,
      settings: const UserSettings(introVersion: 1, seenTips: {'hint', 'stars'}),
      daily: const {'2026-09-11': DailyRecord(levelId: 7, status: 'won')});
    final c = await ready(repo); addTearDown(c.dispose);
    final before = c.read(profileProvider).toJson();
    await tester.pumpWidget(app(c, const SettingsScreen()));
    await tester.pumpAndSettle();
    await tapVisible(tester, 'HOW TO PLAY');
    expect(find.text('LOOK CLOSELY'), findsOneWidget);
    await tester.binding.handlePopRoute(); await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(c.read(profileProvider).toJson(), before);
  });
  for (final id in ['wrong', 'hint', 'stars', 'daily']) {
    testWidgets('$id tip is contextual and only appears once', (tester) async {
      final c = await ready(MemoryProgressRepository()); addTearDown(c.dispose);
      await tester.pumpWidget(app(c, Scaffold(body: Guidance(key: const ValueKey('off'),
        id: id, text: 'Helpful cue', eligible: false))));
      await tester.pumpAndSettle();
      expect(find.text('Helpful cue'), findsNothing);
      expect(c.read(profileProvider).settings.seenTips, isEmpty);
      await tester.pumpWidget(app(c, Scaffold(body: Guidance(key: const ValueKey('on'), id: id, text: 'Helpful cue'))));
      await tester.pumpAndSettle();
      expect(find.text('Helpful cue'), findsOneWidget);
      expect(c.read(profileProvider).settings.seenTips, {id});
      await tester.pumpWidget(app(c, Scaffold(body: Guidance(key: const ValueKey('again'), id: id, text: 'Helpful cue'))));
      await tester.pumpAndSettle();
      expect(find.text('Helpful cue'), findsNothing);
    });
  }
  for (final scale in [1.0, 1.3, 1.5, 2.0]) {
    testWidgets('intro and reference are accessible at ${scale}x on narrow phone', (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = await ready(MemoryProgressRepository()); addTearDown(c.dispose);
      await tester.pumpWidget(app(c, const HowToPlayScreen(firstLaunch: true), scale: scale));
      await tester.pumpAndSettle();
      await tapVisible(tester, 'CONTINUE');
      await tapVisible(tester, 'CONTINUE');
      await tester.ensureVisible(find.text('SKIP')); await tester.pumpAndSettle();
      expect(find.text('SKIP').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(app(c, const HowToPlayScreen(), scale: scale));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('YOUR GAME'), 120); await tester.pumpAndSettle();
      expect(find.text('YOUR GAME').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
