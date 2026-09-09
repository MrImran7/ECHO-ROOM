import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/game.dart';
import 'package:echo_room/app/app.dart';
import 'package:echo_room/app/providers.dart';
import 'package:echo_room/game/session_controller.dart';
import 'package:echo_room/game/session.dart';
import 'package:echo_room/game/echo_game.dart';
import 'package:echo_room/services/audio_service.dart';
import 'package:echo_room/storage/progress_repository.dart';
import 'test_support.dart';
void main() {
  testWidgets('home, real Flame room, correct tap and persisted result', (tester) async {
    tester.view.physicalSize = const Size(430, 932); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final repo = MemoryProgressRepository();
    final container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repo), catalogProvider.overrideWith((ref) async => loadCatalog()),
      audioProvider.overrideWithValue(SilentAudio()), hapticsProvider.overrideWithValue(HapticsService()..enabled = false),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const EchoRoomApp()));
    await tester.pump(); await tester.pump();
    await tester.ensureVisible(find.text('PLAY')); await tester.tap(find.text('PLAY')); await tester.pump();
    for (var i = 0; i < 170; i++) { await tester.pump(const Duration(milliseconds: 80)); }
    final s = container.read(sessionProvider.notifier).game!;
    expect(s.phase, GamePhase.answering);
    final gameRect = tester.getRect(find.byWidgetPredicate((widget) => widget is GameWidget<EchoGame>));
    final lamp = s.original.object('lamp');
    await tester.tapAt(gameRect.topLeft + Offset(lamp.x * gameRect.width, lamp.y * gameRect.height));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('✓ FOUND IT!'), findsOneWidget);
    for (var i = 0; i < 20; i++) { await tester.pump(const Duration(milliseconds: 80)); }
    expect((await repo.load()).highestLevel, 2);
    expect(find.text('ROOM COMPLETE'), findsOneWidget); expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
