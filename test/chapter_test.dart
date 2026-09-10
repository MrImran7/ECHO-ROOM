import 'dart:io';
import 'dart:ui' as ui;

import 'package:echo_room/core/config.dart';
import 'package:echo_room/game/room_art.dart';
import 'package:echo_room/game/session.dart';
import 'package:echo_room/levels/catalog.dart';
import 'package:echo_room/models/scene.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  test(
    'chapter grows in detail without reducing observation or answer time',
    () {
      final catalog = loadCatalog();
      catalog.validate();
      final counts = [1, 6, 11, 16].map((id) {
        final level = catalog.level(id);
        return catalog.rooms[level.roomId]!.objects
            .where((o) => o.visible)
            .length;
      }).toList();
      expect(counts, [17, 20, 23, 26]);
      for (var id = 2; id <= 20; id++) {
        expect(
          catalog.level(id).observationDuration,
          greaterThanOrEqualTo(catalog.level(id - 1).observationDuration),
        );
        expect(
          catalog.level(id).answerDuration,
          greaterThanOrEqualTo(catalog.level(id - 1).answerDuration),
        );
      }
      expect(
        catalog.levels.take(5).map((l) => l.changes.first.type).toSet().length,
        5,
      );
      expect(
        catalog.levels
            .expand((l) => l.changes)
            .map((c) => c.type)
            .toSet()
            .length,
        9,
      );
    },
  );

  for (var id = 1; id <= 20; id++) {
    test('room $id has fair hits, hidden transition, hints and clean replay', () {
      final s = session(level: id);
      final original = s.original.objects.map((o) => o.toJson()).toList();
      s.advance(
        GameConfig.introSeconds +
            GameConfig.countdownSeconds +
            s.level.observationDuration +
            GameConfig.flickerSeconds,
      );
      expect(s.phase, GamePhase.blackout);
      expect(identical(s.visibleRoom, s.original), true);
      expect(s.tap(.5, .5), TapResult.ignored);
      s.advance(GameConfig.blackoutSeconds);
      expect(s.phase, GamePhase.answering);
      expect(identical(s.visibleRoom, s.changed), true);
      for (final width in [230.0, 320.0, 400.0]) {
        final padding = GameConfig.minimumTouchSize / 2 / width;
        for (final target in s.targets) {
          final o = s.changed.object(target).visible
              ? s.changed.object(target)
              : s.original.object(target);
          expect(
            s.targets.contains(
              s.hitTester.resolve(o.x, o.y, minimumPadding: padding),
            ),
            true,
            reason: 'Room $id: target $target at width $width',
          );
        }
        final targetLayer = s.targets
            .map((id) => s.changed.object(id).z)
            .reduce((a, b) => a < b ? a : b);
        for (final o in s.changed.objects.where(
          (o) => o.visible && o.z >= targetLayer && !s.targets.contains(o.id),
        )) {
          // Foreground neighbors must stay distinct; supporting furniture may
          // share an expanded touch region with the small object on top of it.
          if (s.hitTester.resolve(o.x, o.y, minimumPadding: 0) != o.id)
            continue;
          expect(
            s.targets.contains(
              s.hitTester.resolve(o.x, o.y, minimumPadding: padding),
            ),
            false,
            reason: 'Room $id: nearby ${o.id} must not count as the answer',
          );
        }
      }
      expect(s.useHint(), true);
      expect(s.useHint(), true);
      expect(s.useHint(), true);
      expect(s.hintRemaining, greaterThan(0));
      win(s);
      expect(s.phase, GamePhase.won);
      final replay = session(level: id);
      expect(replay.original.objects.map((o) => o.toJson()).toList(), original);
      expect(replay.hints, 0);
      expect(replay.mistakes, 0);
      expect(replay.answerElapsed, 0);
      expect(replay.phase, GamePhase.intro);
    });
  }

  test('invalid room, empty hint and invisible/no-op changes are rejected', () {
    final catalog = loadCatalog();
    final level = catalog.level(1);
    for (final patch in <Json>[
      {'roomId': 'missing'},
      {
        'hints': ['', 'nearby', 'answer'],
      },
      {'observationDuration': double.nan},
      {
        'changes': [
          const Change(
            type: 'OBJECT_ADDED',
            objectId: 'lamp',
            values: {},
          ).toJson(),
        ],
      },
      {
        'changes': [
          const Change(
            type: 'TEXT_CHANGED',
            objectId: 'note',
            values: {'text': '12'},
          ).toJson(),
        ],
      },
    ]) {
      final invalid = LevelDefinition.fromJson({...level.toJson(), ...patch});
      expect(
        () => GameCatalog(rooms: catalog.rooms, levels: [invalid]).validate(),
        throwsFormatException,
      );
    }
  });

  testWidgets('all 20 original and changed scenes visibly differ', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final output = Directory('build/chapter-review')
        ..createSync(recursive: true);
      final art = RoomArt();
      for (var id = 1; id <= 20; id++) {
        final s = session(level: id);
        Future<ui.Image> render(RoomState room) async {
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder);
          art.background(canvas);
          for (final object in room.objects) {
            art.object(canvas, object);
          }
          final picture = recorder.endRecording();
          final image = await picture.toImage(400, 440);
          picture.dispose();
          return image;
        }

        final before = await render(s.original),
            after = await render(s.changed);
        final a = (await before.toByteData())!.buffer.asUint8List();
        final b = (await after.toByteData())!.buffer.asUint8List();
        var visiblePixels = 0;
        for (var i = 0; i < a.length; i += 4) {
          final difference =
              (a[i] - b[i]).abs() +
              (a[i + 1] - b[i + 1]).abs() +
              (a[i + 2] - b[i + 2]).abs();
          if (difference > 30) visiblePixels++;
        }
        expect(
          visiblePixels,
          greaterThan(25),
          reason: 'Room $id has no readable visual change',
        );
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawImage(before, ui.Offset.zero, ui.Paint());
        canvas.drawImage(after, const ui.Offset(400, 0), ui.Paint());
        final picture = recorder.endRecording();
        final pair = await picture.toImage(800, 440);
        final png = (await pair.toByteData(format: ui.ImageByteFormat.png))!;
        await File('${output.path}/room-${id.toString().padLeft(2, '0')}.png')
            .writeAsBytes(
              png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
            );
        before.dispose();
        after.dispose();
        pair.dispose();
        picture.dispose();
      }
    });
  });
}
