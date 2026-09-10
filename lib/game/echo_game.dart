import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flame/components.dart' show World;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/scene.dart';
import 'room_art.dart';
import 'feedback_motion.dart';
import 'session.dart';

class EchoGame extends FlameGame<World> {
  EchoGame({
    required this.room,
    required this.session,
    required this.onTick,
    required this.onReady,
    this.showHitboxes = false,
  }) : super(world: World());
  final Room room;
  final GameSession? Function() session;
  final void Function(double) onTick;
  final void Function() onReady;
  bool _readySent = false;
  double hitPadding = .025;
  final RoomArt art = RoomArt();
  bool showHitboxes;
  bool reduceMotion = false;
  double _time = 0;
  ui.Picture? _background;
  @override
  Color backgroundColor() => const Color(0xff354c45);
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Procedural rooms load instantly. Replacement images are decoded once here.
    final paths = <String>{
      ...room.objects.map((o) => o.asset).whereType<String>(),
      ...?session()?.changed.objects.map((o) => o.asset).whereType<String>(),
    };
    try {
      for (final path in paths) {
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        art.images[path] = (await codec.getNextFrame()).image;
        codec.dispose();
      }
      final recorder = ui.PictureRecorder();
      art.background(Canvas(recorder));
      _background = recorder.endRecording();
    } catch (_) {
      for (final image in art.images.values) {
        image.dispose();
      }
      art.images.clear();
      rethrow;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_readySent) {
      _readySent = true;
      onReady();
      return;
    }
    if (!(session()?.paused ?? false)) _time += dt;
    onTick(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.save();
    canvas.scale(size.x / 400, size.y / 440);
    canvas.clipRect(const Rect.fromLTWH(0, 0, 400, 440));
    final background = _background;
    if (background != null) {
      canvas.drawPicture(background);
    } else {
      art.background(canvas);
    }
    final s = session();
    final objects = s?.visibleRoom.objects ?? room.objects;
    // Catalog validates stable z-order, so no per-frame sorting is needed.
    for (final o in objects) {
      final selected = s?.lastTapped == o.id;
      final won =
          (s?.activePhase == GamePhase.correct ||
              s?.activePhase == GamePhase.won) &&
          selected;
      art.object(
        canvas,
        o,
        pulse: won ? FeedbackMotion.correctScale(s!.phaseElapsed, reduced: reduceMotion) : 1,
        shake:
            !reduceMotion && selected && !won && (s?.feedbackRemaining ?? 0) > 0
            ? FeedbackMotion.wrongOffset(s!.phaseElapsed, reduced: reduceMotion)
            : 0,
      );
    }
    if (s != null) {
      final hinting = s.hintRemaining > 0 && s.phase == GamePhase.answering;
      if (hinting || s.revealAnswer) {
        final id = s.lastTapped != null && s.targets.contains(s.lastTapped)
            ? s.lastTapped!
            : s.targets.first;
        final o = s.changed.object(id).visible
            ? s.changed.object(id)
            : s.original.object(id);
        final center = Offset(o.x * 400, o.y * 440);
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xfff5e1a6);
        if (hinting && s.hints == 1) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(o.x < .5 ? 100 : 300, o.y < .5 ? 110 : 330),
                width: 194,
                height: 214,
              ),
              const Radius.circular(20),
            ),
            p..color = const Color(0x99f5e1a6),
          );
        } else if (hinting && s.hints == 2) {
          canvas.drawCircle(
            center + const Offset(8, -8),
            34 + (reduceMotion ? 0 : math.sin(_time * 5) * 6),
            p..color = const Color(0xaaf5e1a6),
          );
        } else {
          canvas.drawOval(
            Rect.fromCenter(
              center: center,
              width: math.max(
                36,
                o.width * 400 * o.scale + 16 + (reduceMotion ? 0 : math.sin(_time * 5) * 4),
              ),
              height: math.max(
                36,
                o.height * 440 * o.scale + 16 + (reduceMotion ? 0 : math.sin(_time * 5) * 4),
              ),
            ),
            p,
          );
        }
      }
      if (showHitboxes) {
        for (final region in s.hitTester.regions) {
          final o = region.object, padding = region.padding(hitPadding);
          canvas.save();
          canvas.translate(o.x * 400, o.y * 440);
          canvas.rotate(o.rotation);
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: o.width * 400 * o.scale + 2 * padding * 400,
              height: o.height * 440 * o.scale + 2 * padding * 440,
            ),
            Paint()
              ..color = region.historical ? Colors.orange : Colors.cyan
              ..style = PaintingStyle.stroke,
          );
          canvas.restore();
        }
      }
      double darkness = 0;
      if (s.phase == GamePhase.flicker)
        darkness = FeedbackMotion.darkness(
          s.phaseElapsed / s.duration,
          reduced: reduceMotion,
        );
      if (s.phase == GamePhase.loading ||
          s.phase == GamePhase.blackout ||
          s.paused ||
          s.phase == GamePhase.intro ||
          s.phase == GamePhase.countdown)
        darkness = 1;
      if (darkness > 0)
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 400, 440),
          Paint()..color = Color.fromRGBO(16, 23, 23, darkness),
        );
    }
    canvas.restore();
  }

  @override
  void onRemove() {
    _background?.dispose();
    _background = null;
    for (final image in art.images.values) {
      image.dispose();
    }
    super.onRemove();
  }
}
