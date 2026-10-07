import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Bitmaps registered with MapLibre via `addImage`. Drawn in code so there are
/// no asset files to ship; [scale] is the device pixel ratio.
class MapImages {
  MapImages._();

  static const selectedBlue = Color(0xFF1A73E8);

  /// Google-style navigation arrow pointing north, white outline.
  static Future<Uint8List> puck(double scale) {
    const size = 44.0;
    return _render(const Size(size, size), scale, (canvas) {
      final arrow = Path()
        ..moveTo(size / 2, 3)
        ..lineTo(size - 7, size - 6)
        ..lineTo(size / 2, size - 15)
        ..lineTo(7, size - 6)
        ..close();
      canvas.drawShadow(arrow, Colors.black, 3, true);
      canvas.drawPath(
        arrow,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(arrow, Paint()..color = selectedBlue);
    });
  }

  /// Small white dot with a blue ring, for a focused step.
  static Future<Uint8List> stepDot(double scale) {
    const size = 20.0;
    return _render(const Size(size, size), scale, (canvas) {
      const c = Offset(size / 2, size / 2);
      canvas.drawCircle(c, 9, Paint()..color = selectedBlue);
      canvas.drawCircle(c, 6, Paint()..color = Colors.white);
    });
  }

  /// Start of the route: white dot, dark ring.
  static Future<Uint8List> origin(double scale) {
    const size = 18.0;
    return _render(const Size(size, size), scale, (canvas) {
      const c = Offset(size / 2, size / 2);
      canvas.drawCircle(c, 8, Paint()..color = const Color(0xFF202124));
      canvas.drawCircle(c, 4.5, Paint()..color = Colors.white);
    });
  }

  /// Red map pin; the tip is at the bottom centre (anchor 'bottom').
  static Future<Uint8List> destinationPin(double scale) {
    const w = 28.0, h = 38.0;
    return _render(const Size(w, h), scale, (canvas) {
      final pin = Path()
        ..moveTo(w / 2, h)
        ..cubicTo(w / 2 - 3, h - 10, 1, h - 18, 1, 13)
        ..arcToPoint(const Offset(w - 1, 13), radius: const Radius.circular(13))
        ..cubicTo(w - 1, h - 18, w / 2 + 3, h - 10, w / 2, h)
        ..close();
      canvas.drawShadow(pin, Colors.black, 2, false);
      canvas.drawPath(pin, Paint()..color = const Color(0xFFEA4335));
      canvas.drawCircle(
        const Offset(w / 2, 13),
        4.5,
        Paint()..color = const Color(0xFFA50E0E),
      );
    });
  }

  /// Rounded label like Google's route callouts: "49 min" over "32 km".
  static Future<Uint8List> etaBubble({
    required String eta,
    required String distance,
    required bool selected,
    required double scale,
  }) {
    final fg = selected ? Colors.white : const Color(0xFF202124);
    final bg = selected ? selectedBlue : Colors.white;
    final title = _text(eta, 15, FontWeight.w700, fg);
    final sub = _text(distance, 12, FontWeight.w500, fg.withValues(alpha: 0.8));
    const padH = 10.0, padV = 6.0, tail = 7.0;
    final w =
        [title.width, sub.width].reduce((a, b) => a > b ? a : b) + padH * 2;
    final h = title.height + sub.height + padV * 2;
    return _render(Size(w, h + tail), scale, (canvas) {
      final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, h),
        const Radius.circular(8),
      );
      final shape = Path()
        ..addRRect(body)
        ..moveTo(w / 2 - tail, h)
        ..lineTo(w / 2, h + tail)
        ..lineTo(w / 2 + tail, h)
        ..close();
      canvas.drawShadow(shape, Colors.black, 2, false);
      canvas.drawPath(shape, Paint()..color = bg);
      title.paint(canvas, Offset((w - title.width) / 2, padV));
      sub.paint(canvas, Offset((w - sub.width) / 2, padV + title.height));
    });
  }

  static TextPainter _text(String s, double size, FontWeight weight, Color c) {
    return TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, fontWeight: weight, color: c),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  static Future<Uint8List> _render(
    Size logical,
    double scale,
    void Function(Canvas canvas) paint,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    paint(canvas);
    final image = await recorder.endRecording().toImage(
      (logical.width * scale).ceil(),
      (logical.height * scale).ceil(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }
}
