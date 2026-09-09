import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_room/app/providers.dart';
import 'package:echo_room/game/session_controller.dart';
import 'package:echo_room/game/session.dart';
import 'package:echo_room/models/progress.dart';
import 'package:echo_room/services/audio_service.dart';
import 'package:echo_room/storage/progress_repository.dart';

import 'test_support.dart';

Future<ProviderContainer> ready(MemoryProgressRepository repo) async {
  final c = ProviderContainer(
    overrides: [
      repositoryProvider.overrideWithValue(repo),
      catalogProvider.overrideWith((ref) async => loadCatalog()),
      audioProvider.overrideWithValue(SilentAudio()),
      hapticsProvider.overrideWithValue(HapticsService()..enabled = false),
    ],
  );
  await c.read(savedProgressProvider.future);
  await c.read(catalogProvider.future);
  return c;
}

void main() {
  test(
    'checkpoint and settings survive disposal and a fresh provider container',
    () async {
      final repo = MemoryProgressRepository();
      final c = await ready(repo);
      final controller = c.read(sessionProvider.notifier);
      await controller.start(1);
      reachAnswer(controller.game!);
      controller.game!.advance(.7);
      controller.pause();
      await controller.checkpoint();
      await c
          .read(profileProvider.notifier)
          .settings(
            const UserSettings(music: false, sound: false, haptics: false),
          );
      final elapsed = controller.game!.answerElapsed;
      c.dispose();
      final restored = await ready(repo);
      addTearDown(restored.dispose);
      final next = restored.read(sessionProvider.notifier)..restore();
      expect(next.game!.paused, true);
      expect(next.game!.answerElapsed, elapsed);
      expect(restored.read(profileProvider).settings.music, false);
      next.tick(100);
      expect(next.game!.phase, GamePhase.paused);
    },
  );
  test(
    'daily reservation persists before play and restores the same attempt',
    () async {
      final repo = MemoryProgressRepository();
      final first = await ready(repo);
      final controller = first.read(sessionProvider.notifier);
      await controller.start(1, daily: true);
      final key = controller.game!.dailyDate!, runId = controller.game!.runId;
      expect((await repo.load()).daily[key]!.status, 'started');
      first.dispose();
      final second = await ready(repo);
      addTearDown(second.dispose);
      final next = second.read(sessionProvider.notifier);
      await expectLater(next.start(1, daily: true), throwsStateError);
      next.restore();
      expect(next.game!.runId, runId);
      expect(next.game!.dailyDate, key);
    },
  );
  test(
    'hint charge persists atomically with hint strength in the checkpoint',
    () async {
      final repo = MemoryProgressRepository();
      final container = await ready(repo);
      addTearDown(container.dispose);
      final controller = container.read(sessionProvider.notifier);
      await controller.start(1);
      reachAnswer(controller.game!);
      final initial = container.read(profileProvider).hints;
      await controller.hint();
      final saved = await repo.load();
      expect(saved.hints, initial - 1);
      expect(saved.activeSession!['hints'], 1);
    },
  );
}
