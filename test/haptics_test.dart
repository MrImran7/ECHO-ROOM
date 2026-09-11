import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_room/app/providers.dart';
import 'package:echo_room/core/config.dart';
import 'package:echo_room/models/progress.dart';
import 'package:echo_room/services/audio_service.dart';
import 'package:echo_room/storage/progress_repository.dart';

import 'test_support.dart';

void main() {
  final calls = <Object?>[];
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments);
      return null;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  Future<void> finishPattern(WidgetTester tester, Future<void> pattern) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: GameConfig.hapticPatternGapMilliseconds + 1));
    await pattern;
  }

  testWidgets('production provider requests Android platform feedback, not a fake', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final service = c.read(hapticsProvider);
    expect(service.enabled, true);
    await service.correct();
    // A null argument selects Flutter's generic LONG_PRESS on Android.
    expect(calls, [null]);
    await service.complete();
    await service.timeout();
    expect(calls, [null, null, null]);
  });

  testWidgets('Android first wrong is two beats; rapid repeat is suppressed; correct wins', (tester) async {
    final service = HapticsService(platform: TargetPlatform.android);
    addTearDown(service.dispose);
    final wrong = service.wrong();
    await tester.pump();
    await service.wrong();
    expect(calls, [null]);
    await service.correct();
    await finishPattern(tester, wrong);
    expect(calls, [null, null]); // Wrong first beat, then correct; no stale beat.
    calls.clear();
    await finishPattern(tester, service.wrong());
    expect(calls, [null, null]);
  });

  testWidgets('Android disabled blocks every cue and probes, including queued beats', (tester) async {
    final service = HapticsService(platform: TargetPlatform.android);
    addTearDown(service.dispose);
    final pattern = service.wrong();
    await tester.pump();
    service.enabled = false;
    await finishPattern(tester, pattern);
    expect(calls, [null]);
    calls.clear();
    await service.correct();
    await service.wrong();
    await service.timeout();
    await service.complete();
    await service.celebrate();
    for (final probe in HapticProbe.values) { await service.debugProbe(probe); }
    expect(calls, isEmpty);
    service.enabled = true;
    await finishPattern(tester, service.wrong());
    expect(calls, [null, null]);
  });

  testWidgets('repeated suspend/resume restores first feedback without stale patterns', (tester) async {
    final service = HapticsService(platform: TargetPlatform.android);
    for (var i = 0; i < 3; i++) {
      final pattern = service.celebrate();
      await tester.pump();
      service.suspend();
      service.suspend();
      await service.correct();
      await finishPattern(tester, pattern);
      service.resume();
      service.resume();
      await service.correct();
    }
    expect(calls.length, 6);
    service.dispose();
    service.resume();
    await service.correct();
    expect(calls.length, 6);
  });

  testWidgets('raw debug probes request separate API types without Android remapping', (tester) async {
    final service = HapticsService(platform: TargetPlatform.android);
    addTearDown(service.dispose);
    for (final probe in HapticProbe.values) { await service.debugProbe(probe); }
    expect(calls, ['HapticFeedbackType.lightImpact', 'HapticFeedbackType.mediumImpact', null]);
  });

  testWidgets('iOS keeps semantic feedback and correct uses medium impact', (tester) async {
    final service = HapticsService(platform: TargetPlatform.iOS);
    addTearDown(service.dispose);
    await service.correct();
    await service.wrong();
    await service.timeout();
    await service.complete();
    await finishPattern(tester, service.celebrate());
    expect(calls, [
      'HapticFeedbackType.mediumImpact', 'HapticFeedbackType.heavyImpact',
      'HapticFeedbackType.mediumImpact', 'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick', 'HapticFeedbackType.lightImpact',
    ]);
  });

  testWidgets('Android platform failure is contained and future dispatch remains available', (tester) async {
    final service = HapticsService(platform: TargetPlatform.android);
    addTearDown(service.dispose);
    var fail = true;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        if (fail) throw PlatformException(code: 'unavailable');
        calls.add(call.arguments);
      }
      return null;
    });
    await service.correct();
    expect(calls, isEmpty);
    fail = false;
    await service.correct();
    expect(calls, [null]);
  });

  testWidgets('fresh default is on; runtime preference toggles and persistence retain intent', (tester) async {
    expect(const UserSettings().haptics, true);
    expect(UserSettings.fromJson({}).haptics, true);
    final repo = MemoryProgressRepository();
    final c = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repo),
      audioProvider.overrideWithValue(SilentAudio()),
    ]);
    addTearDown(c.dispose);
    await c.read(savedProgressProvider.future);
    final service = c.read(hapticsProvider);
    final profile = c.read(profileProvider.notifier);
    await profile.settings(const UserSettings(haptics: false));
    await service.correct();
    expect(calls, isEmpty);
    expect((await repo.load()).settings.haptics, false);
    await profile.settings(const UserSettings(haptics: true));
    await service.correct();
    expect(calls.length, 1);
    expect((await repo.load()).settings.haptics, true);
  });
}
