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
void main() {
  test('legacy progression skips intro while empty saves remain new', () {
    expect(Progress.fromJson({}).settings.introVersion, 0);
    for (final old in <Map<String, dynamic>>[
      {'highestLevel': 2}, {'levels': {'1': {'stars': 1}}},
      {'daily': {'2026-09-11': {'levelId': 7, 'status': 'won'}}},
      {'activeSession': <String, dynamic>{}},
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
    final repo = MemoryProgressRepository()..value = Progress(highestLevel: 8);
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
