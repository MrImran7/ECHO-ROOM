import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/scene.dart';

/// Original procedural artwork. Every object is drawn in its own 100x100 local
/// artboard. Replace one renderer or provide an asset without touching rules.
class RoomArt {
  static const cream = Color(0xffead4aa);
  static const ink = Color(0xff29322f);
  final Paint _paint = Paint()..isAntiAlias = true;
  final Map<String, ui.Image> images = {};
  final Map<String, TextPainter> _labels = {};

  void rect(
    Canvas c,
    double x,
    double y,
    double w,
    double h,
    Color color, [
    double r = 0,
  ]) {
    _paint
      ..color = color
      ..style = PaintingStyle.fill
      ..shader = null;
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
      _paint,
    );
  }

  void oval(Canvas c, double x, double y, double w, double h, Color color) {
    _paint
      ..color = color
      ..style = PaintingStyle.fill
      ..shader = null;
    c.drawOval(Rect.fromLTWH(x, y, w, h), _paint);
  }

  void line(
    Canvas c,
    double x,
    double y,
    double x2,
    double y2,
    Color color, [
    double width = 2,
  ]) {
    _paint
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..shader = null;
    c.drawLine(Offset(x, y), Offset(x2, y2), _paint);
  }

  void polygon(Canvas c, List<Offset> points, Color color) {
    final p = Path()..addPolygon(points, true);
    _paint
      ..color = color
      ..style = PaintingStyle.fill
      ..shader = null;
    c.drawPath(p, _paint);
  }

  void label(
    Canvas c,
    String text,
    double x,
    double y,
    double size,
    Color color,
  ) {
    final p = _labels.putIfAbsent(
      '$text/$size/$color',
      () => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: size,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
    p.paint(c, Offset(x - p.width / 2, y));
  }

  /// Original vector numerals remain readable at phone scale and in snapshots.
  void noteNumber(Canvas c, String text) {
    const strokes = [
      [0.0, 0.0, 20.0, 0.0],
      [20.0, 0.0, 20.0, 20.0],
      [20.0, 20.0, 20.0, 40.0],
      [0.0, 40.0, 20.0, 40.0],
      [0.0, 20.0, 0.0, 40.0],
      [0.0, 0.0, 0.0, 20.0],
      [0.0, 20.0, 20.0, 20.0],
    ];
    const digits = [
      '012345',
      '12',
      '01643',
      '01236',
      '5612',
      '05632',
      '054326',
      '012',
      '0123456',
      '012356',
    ];
    if (text.length != 2 || int.tryParse(text) == null) {
      label(c, text, 50, 20, 39, ink);
      return;
    }
    for (var i = 0; i < text.length; i++) {
      final x = 22.0 + i * 34;
      for (final segment in digits[int.parse(text[i])].split('')) {
        final stroke = strokes[int.parse(segment)];
        line(
          c,
          x + stroke[0],
          18 + stroke[1],
          x + stroke[2],
          18 + stroke[3],
          ink,
          4,
        );
      }
    }
  }

  void background(Canvas c) {
    const wall = Rect.fromLTWH(0, 0, 400, 300);
    _paint
      ..style = PaintingStyle.fill
      ..color = Colors.white
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff64766b), Color(0xff354c45)],
      ).createShader(wall);
    c.drawRect(wall, _paint);
    _paint.shader = null;
    rect(c, 0, 288, 400, 152, const Color(0xff9a7356));
    for (var y = 302.0; y < 440; y += 28) {
      line(c, 0, y, 400, y, const Color(0xff806148), 1);
      for (var x = ((y ~/ 28) % 2) * 65.0; x < 400; x += 125) {
        line(c, x, y, x - 10, y + 28, const Color(0xff89684c), 1);
      }
    }
    rect(c, 0, 280, 400, 10, const Color(0xffb49c76));
    rect(c, 0, 290, 400, 4, const Color(0xff5e5741));
    for (var x = 22.0; x < 400; x += 52) {
      rect(c, x, 20, 1, 255, const Color(0x0edddfc5));
    }
    oval(c, 47, 320, 306, 100, const Color(0xff796953));
    oval(c, 55, 324, 291, 90, const Color(0xffb3a78a));
    for (var i = 0; i < 5; i++) {
      _paint
        ..color = const Color(0x40746350)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      c.drawOval(
        Rect.fromLTWH(
          64 + i * 5.0,
          329 + i * 3.0,
          271 - i * 10.0,
          78 - i * 6.0,
        ),
        _paint,
      );
    }
  }

  void object(Canvas c, RoomObject o, {double pulse = 1, double shake = 0}) {
    if (!o.visible) return;
    c.save();
    c.translate(o.x * 400 + shake, o.y * 440);
    c.rotate(o.rotation);
    c.scale(o.width * 4 * o.scale * pulse, o.height * 4.4 * o.scale * pulse);
    c.translate(-50, -50);
    final asset = o.asset == null ? null : images[o.asset];
    if (asset != null) {
      c.drawImageRect(
        asset,
        Rect.fromLTWH(0, 0, asset.width.toDouble(), asset.height.toDouble()),
        const Rect.fromLTWH(0, 0, 100, 100),
        Paint(),
      );
    } else {
      drawObject(c, o);
    }
    c.restore();
  }

  void drawObject(Canvas c, RoomObject o) {
    final color = Color(o.color);
    switch (o.art) {
      case 'sofa':
        oval(c, -3, 76, 106, 24, const Color(0x30231c16));
        rect(c, 10, 78, 5, 20, ink, 1);
        rect(c, 85, 78, 5, 20, ink, 1);
        rect(c, 7, 7, 86, 64, color, 10);
        rect(c, 11, 12, 37, 42, const Color(0xffbd855e), 8);
        rect(c, 51, 12, 37, 42, const Color(0xffb17b56), 8);
        rect(c, 5, 54, 90, 30, const Color(0xff97613f), 6);
        rect(c, 0, 39, 12, 42, const Color(0xffc18b63), 5);
        rect(c, 88, 39, 12, 42, const Color(0xffc18b63), 5);
        rect(c, 14, 53, 35, 12, const Color(0xffcf956a), 4);
        rect(c, 51, 53, 35, 12, const Color(0xffc98e61), 4);
        break;
      case 'cushion':
        rect(c, 6, 5, 88, 90, color, 15);
        line(c, 19, 20, 81, 80, const Color(0x40fff2d6), 3);
        line(c, 81, 20, 19, 80, const Color(0x40fff2d6), 3);
        break;
      case 'table':
        rect(c, 14, 39, 6, 52, const Color(0xff4a3b2e), 2);
        rect(c, 79, 39, 6, 52, const Color(0xff4a3b2e), 2);
        rect(c, 43, 49, 5, 48, const Color(0xff5a4533), 2);
        oval(c, 0, 12, 100, 42, const Color(0xff503e2d));
        oval(c, 0, 4, 100, 42, const Color(0xffd2ac78));
        line(c, 20, 22, 80, 22, const Color(0x4065442d), 1);
        break;
      case 'lamp':
        oval(c, 12, 91, 76, 9, const Color(0xff333b30));
        rect(c, 46, 23, 7, 72, const Color(0xffc3ae72), 2);
        polygon(c, const [
          Offset(24, 1),
          Offset(76, 1),
          Offset(97, 32),
          Offset(3, 32),
        ], cream);
        oval(c, 3, 27, 94, 10, const Color(0xfff7d594));
        line(c, 21, 30, 28, 4, const Color(0xffcbb58c), 1);
        line(c, 80, 30, 73, 4, const Color(0xffcbb58c), 1);
        break;
      case 'plant':
        for (var i = 0; i < 6; i++) {
          final x = 18.0 + (i % 3) * 24, y = 3.0 + (i ~/ 3) * 23;
          line(c, 50, 75, x + 10, y + 12, const Color(0xff263e2a), 3);
          oval(
            c,
            x - 4,
            y,
            25,
            23,
            i.isEven ? const Color(0xff779161) : const Color(0xff4c724e),
          );
        }
        polygon(c, [
          const Offset(22, 62),
          const Offset(78, 62),
          const Offset(69, 99),
          const Offset(31, 99),
        ], color);
        rect(c, 20, 61, 60, 9, const Color(0xffdbac85), 2);
        break;
      case 'window':
        rect(c, 0, 0, 100, 100, const Color(0xffb3a886), 2);
        rect(c, 5, 4, 90, 90, const Color(0xff1f3d46));
        oval(c, 62, 13, 17, 15, const Color(0xffe4d5ab));
        if (o.variant == 'double_moon') {
          oval(c, 20, 13, 17, 15, const Color(0xffe4d5ab));
        }
        for (var i = 0; i < 6; i++) {
          rect(
            c,
            7 + i * 14.0,
            62 - (i % 3) * 9.0,
            12,
            32 + (i % 3) * 9.0,
            const Color(0xff172f39),
          );
          rect(c, 10 + i * 14.0, 70, 3, 4, const Color(0xffa39367));
        }
        rect(c, 48, 4, 4, 90, const Color(0xffa99d7c));
        rect(c, 4, 47, 92, 4, const Color(0xffa99d7c));
        rect(c, -5, 96, 110, 5, const Color(0xffd2bf9b), 1);
        break;
      case 'painting':
        rect(c, 2, 3, 98, 97, const Color(0x30202016), 1);
        rect(c, 0, 0, 96, 96, const Color(0xffd2b17a), 1);
        rect(c, 6, 6, 84, 84, const Color(0xfff0dcc1));
        rect(c, 11, 11, 74, 74, const Color(0xff829484));
        oval(
          c,
          o.variant == 'moon' ? 45 : 21,
          20,
          26,
          26,
          o.variant == 'moon'
              ? const Color(0xffeee5c7)
              : const Color(0xffc89062),
        );
        polygon(c, [
          const Offset(11, 85),
          const Offset(11, 68),
          Offset(o.variant == 'inverted' ? 70 : 34, 42),
          const Offset(85, 72),
          const Offset(85, 85),
        ], const Color(0xff35554c));
        polygon(c, const [
          Offset(11, 85),
          Offset(62, 50),
          Offset(85, 65),
          Offset(85, 85),
        ], const Color(0xff536b57));
        break;
      case 'clock':
        oval(c, 2, 3, 98, 97, const Color(0x44242018));
        oval(c, 0, 0, 96, 96, const Color(0xffbb9b68));
        oval(c, 7, 7, 82, 82, const Color(0xffeee0bc));
        for (var i = 0; i < 12; i++) {
          final a = i * math.pi / 6;
          line(
            c,
            48 + math.sin(a) * 33,
            48 - math.cos(a) * 33,
            48 + math.sin(a) * 36,
            48 - math.cos(a) * 36,
            ink,
            1.6,
          );
        }
        line(c, 48, 48, 48, 18, ink, 3);
        line(
          c,
          48,
          48,
          o.variant == 'late' ? 23 : 68,
          o.variant == 'late' ? 57 : 40,
          ink,
          4,
        );
        if (o.variant == 'impossible')
          line(c, 48, 48, 32, 23, const Color(0xffa64b38), 3);
        oval(c, 44, 44, 8, 8, ink);
        break;
      case 'shelf':
        rect(c, 0, 38, 100, 25, const Color(0xffb48b60), 2);
        rect(c, 5, 63, 6, 37, const Color(0xff4b4838));
        rect(c, 89, 63, 6, 37, const Color(0xff4b4838));
        break;
      case 'book':
        rect(c, 5, 0, 90, 100, color, 3);
        rect(c, 12, 5, 4, 90, const Color(0x60ffdfab));
        rect(c, 23, 17, 57, 5, cream, 1);
        rect(c, 23, 77, 57, 3, cream, 1);
        break;
      case 'cup':
        oval(c, 60, 22, 38, 44, color);
        oval(c, 70, 31, 18, 23, const Color(0xffceaa78));
        rect(c, 5, 14, 65, 73, color, 14);
        oval(c, 5, 5, 65, 22, cream);
        oval(c, 13, 10, 49, 12, const Color(0xff533b28));
        if (o.variant == 'striped') {
          rect(c, 8, 40, 59, 9, cream);
          rect(c, 8, 62, 59, 9, cream);
        }
        break;
      case 'chair':
        rect(c, 10, 2, 80, 50, color, 8);
        rect(c, 15, 40, 6, 58, ink);
        rect(c, 79, 40, 6, 58, ink);
        rect(c, 8, 55, 84, 17, const Color(0xffaf8c5e), 3);
        break;
      case 'mirror':
        rect(c, 0, 0, 100, 100, const Color(0xffb7a16e), 40);
        rect(c, 6, 6, 88, 88, const Color(0xff6b8a86), 35);
        polygon(c, const [
          Offset(20, 75),
          Offset(77, 20),
          Offset(86, 38),
          Offset(33, 90),
        ], const Color(0x30d8e6d8));
        rect(c, 18, 69, 64, 5, const Color(0xffc1a17c));
        oval(
          c,
          o.variant == 'other' ? 56 : 26,
          44,
          17,
          25,
          const Color(0xffdcc598),
        );
        if (o.variant == 'echo') {
          rect(c, 27, 56, 15, 6, ink, 1);
        }
        if (o.variant == 'visitor') {
          oval(c, 58, 33, 16, 16, const Color(0xff314d49));
          rect(c, 55, 47, 23, 22, const Color(0xff314d49), 8);
        }
        break;
      case 'shadow':
        polygon(
          c,
          o.variant == 'left'
              ? const [
                  Offset(85, 10),
                  Offset(5, 68),
                  Offset(38, 90),
                  Offset(95, 30),
                ]
              : const [
                  Offset(5, 10),
                  Offset(95, 68),
                  Offset(62, 90),
                  Offset(5, 30),
                ],
          const Color(0x50393025),
        );
        break;
      case 'note':
        rect(c, 0, 0, 100, 100, const Color(0xffe7d6ae), 1);
        noteNumber(c, o.text);
        line(c, 18, 74, 82, 74, const Color(0xffad9675), 2);
        break;
      case 'vase':
        rect(c, 31, 0, 38, 35, color, 5);
        oval(c, 11, 22, 78, 77, color);
        if (o.variant == 'marked') rect(c, 15, 58, 70, 12, cream, 2);
        line(c, 30, 48, 30, 80, const Color(0x30ffffff), 4);
        break;
      case 'key':
        oval(c, 0, 10, 47, 54, const Color(0xffe0b966));
        oval(c, 10, 21, 27, 30, const Color(0xffb59f7c));
        rect(c, 36, 30, 64, 14, const Color(0xffe0b966), 3);
        rect(c, 77, 40, 9, 23, const Color(0xffe0b966));
        break;
      case 'light':
        oval(
          c,
          0,
          0,
          100,
          100,
          o.variant == 'dim'
              ? const Color(0x0dfcdb87)
              : const Color(0x40fcdb87),
        );
        break;
      default:
        rect(c, 0, 0, 100, 100, color, 8);
    }
  }
}
