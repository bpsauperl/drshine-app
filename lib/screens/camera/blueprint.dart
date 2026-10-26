import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

/// The outline drawn over the camera for each photo slot.
enum Blueprint {
  faceFront,
  faceFrontSmile,
  profileLeft,
  profileRight,
  threeQuarterLeft,
  threeQuarterRight,
  frontArches,
  buccalLeft,
  buccalRight,
  occlusalUpper,
  occlusalLower,
  overjet,
  xray;

  bool get isFace => index <= Blueprint.threeQuarterRight.index;
}

/// The outline for a slot. The slot is the most precise (`left_bite` vs
/// `right_bite`); the API's `guide` key is the fallback for slots the app
/// doesn't know yet.
Blueprint blueprintFor(String slot, [String guide = '']) {
  final bySlot = switch (slot) {
    'frontal' => Blueprint.faceFront,
    'frontal_smile' => Blueprint.faceFrontSmile,
    'left_profile' || 'left_profile_smile' => Blueprint.profileLeft,
    'right_profile' || 'right_profile_smile' => Blueprint.profileRight,
    'left_front_45' || 'left_front_45_smile' => Blueprint.threeQuarterLeft,
    'right_front_45' || 'right_front_45_smile' => Blueprint.threeQuarterRight,
    'front_arches' => Blueprint.frontArches,
    'left_bite' => Blueprint.buccalLeft,
    'right_bite' => Blueprint.buccalRight,
    'occlusal_upper' => Blueprint.occlusalUpper,
    'occlusal_lower' => Blueprint.occlusalLower,
    'overjet' => Blueprint.overjet,
    'panoramic_xray' || 'lateral_cephalometric' => Blueprint.xray,
    _ => null,
  };
  if (bySlot != null) {
    return bySlot;
  }
  return switch (guide) {
    'frontal-smile' || 'face-front-smile' => Blueprint.faceFrontSmile,
    'face-left' || 'profile-left' || 'left-profile' => Blueprint.profileLeft,
    'face-right' || 'profile-right' || 'right-profile' => Blueprint.profileRight,
    'face-left45' || 'left-45' => Blueprint.threeQuarterLeft,
    'face-right45' || 'right-45' => Blueprint.threeQuarterRight,
    'bite' || 'front-arches' => Blueprint.frontArches,
    'left-bite' => Blueprint.buccalLeft,
    'right-bite' => Blueprint.buccalRight,
    'occlusal-upper' => Blueprint.occlusalUpper,
    'occlusal-lower' => Blueprint.occlusalLower,
    'overjet' => Blueprint.overjet,
    'xray' || 'x-ray' => Blueprint.xray,
    _ when guide.startsWith('face') => Blueprint.faceFront,
    _ => Blueprint.faceFront,
  };
}

/// The short instruction under the camera's title.
String instructionFor(String slot, Blueprint blueprint) {
  final smiling = slot.contains('smile');
  return switch (blueprint) {
    Blueprint.faceFront => 'Straight on, lips relaxed, eyes on the line.',
    Blueprint.faceFrontSmile => 'Straight on, a natural full smile.',
    Blueprint.profileLeft || Blueprint.profileRight =>
      smiling ? 'Side on, smiling, chin level.' : 'Side on, lips relaxed, chin level.',
    Blueprint.threeQuarterLeft || Blueprint.threeQuarterRight =>
      smiling ? 'Head turned 45°, smiling.' : 'Head turned 45°, lips relaxed.',
    Blueprint.frontArches => 'Retractors in, teeth together.',
    Blueprint.buccalLeft || Blueprint.buccalRight => 'Retractors in, cheek pulled back, teeth together.',
    Blueprint.occlusalUpper => 'Mirror in, mouth wide open, whole upper arch.',
    Blueprint.occlusalLower => 'Mirror in, mouth wide open, whole lower arch.',
    Blueprint.overjet => 'From the side, teeth together, front teeth in the frame.',
    Blueprint.xray => 'Fill the frame with the X-ray, no glare.',
  };
}

/// Draws the faded outline of what to capture, as thin white strokes.
///
/// Every drawing lives in a unit box (0..1 × 0..1) fitted into the middle of
/// the canvas, so it looks the same on any screen.
class BlueprintPainter extends CustomPainter {
  BlueprintPainter(this.blueprint, {this.color = Colors.white, this.opacity = 0.35, this.strokeWidth = 2.2, this.fill = 0.82});

  final Blueprint blueprint;
  final Color color;
  final double opacity;
  final double strokeWidth;

  /// How much of the canvas width the drawing may take.
  final double fill;

  /// The drawing's height / width.
  double get aspect => switch (blueprint) {
        Blueprint.frontArches || Blueprint.buccalLeft || Blueprint.buccalRight => 0.72,
        Blueprint.occlusalUpper || Blueprint.occlusalLower => 0.95,
        Blueprint.overjet => 1.1,
        Blueprint.xray => 0.7,
        _ => 1.3,
      };

  /// The box the drawing fills on a canvas of [size].
  Rect frameFor(Size size) {
    var width = size.width * fill;
    var height = width * aspect;
    final maxHeight = size.height * 0.72;
    if (height > maxHeight) {
      height = maxHeight;
      width = height / aspect;
    }
    return Rect.fromCenter(center: size.center(Offset.zero), width: width, height: height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final frame = frameFor(size);
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final faint = Paint()
      ..color = color.withValues(alpha: opacity * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.7
      ..strokeCap = StrokeCap.round;

    final base = Matrix4.identity()
      ..translateByDouble(frame.left, frame.top, 0, 1)
      ..scaleByDouble(frame.width, frame.height, 1, 1);
    final d = _Draw(canvas, paint, faint, base, frame.height / frame.width);

    switch (blueprint) {
      case Blueprint.faceFront:
        d.faceFront(smiling: false);
      case Blueprint.faceFrontSmile:
        d.faceFront(smiling: true);
      case Blueprint.profileRight:
        d.profile();
      case Blueprint.profileLeft:
        d.mirrored(d.profile);
      case Blueprint.threeQuarterRight:
        d.threeQuarter();
      case Blueprint.threeQuarterLeft:
        d.mirrored(d.threeQuarter);
      case Blueprint.frontArches:
        d.frontArches();
      case Blueprint.buccalLeft:
        d.buccal();
      case Blueprint.buccalRight:
        d.mirrored(d.buccal);
      case Blueprint.occlusalUpper:
        d.occlusal();
      case Blueprint.occlusalLower:
        d.flipped(d.occlusal);
      case Blueprint.overjet:
        d.overjet();
      case Blueprint.xray:
        d.xray();
    }
  }

  @override
  bool shouldRepaint(BlueprintPainter old) =>
      old.blueprint != blueprint || old.color != color || old.opacity != opacity || old.strokeWidth != strokeWidth;
}

/// The drawings, in unit coordinates. Paths are built in the unit box and
/// mapped to pixels before stroking, so strokes keep their pixel width.
class _Draw {
  _Draw(this.canvas, this.paint, this.faint, this.matrix, this.aspect);

  final Canvas canvas;
  final Paint paint;
  final Paint faint;

  /// Unit box → pixels (plus any mirroring or rotation in effect).
  Matrix4 matrix;

  /// The frame's height / width, to keep shapes round in the stretched box.
  final double aspect;

  void within(Matrix4 transform, void Function() draw) {
    final saved = matrix;
    matrix = saved.multiplied(transform);
    draw();
    matrix = saved;
  }

  void mirrored(void Function() draw) => within(
        Matrix4.identity()
          ..translateByDouble(1, 0, 0, 1)
          ..scaleByDouble(-1, 1, 1, 1),
        draw,
      );

  void flipped(void Function() draw) => within(
        Matrix4.identity()
          ..translateByDouble(0, 1, 0, 1)
          ..scaleByDouble(1, -1, 1, 1),
        draw,
      );

  void stroke(Path path, [Paint? with_]) => canvas.drawPath(path.transform(matrix.storage), with_ ?? paint);

  void line(Offset a, Offset b, [Paint? with_]) => stroke(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy),
        with_,
      );

  void dashed(Offset a, Offset b, {double dash = 10, double gap = 8}) => dashedPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy),
        dash: dash,
        gap: gap,
      );

  /// Dashes measured in pixels.
  void dashedPath(Path path, {double dash = 10, double gap = 8}) {
    for (final PathMetric metric in path.transform(matrix.storage).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), faint);
        distance = end + gap;
      }
    }
  }

  void oval(double cx, double cy, double w, double h, [Paint? with_]) =>
      stroke(Path()..addOval(Rect.fromCenter(center: Offset(cx, cy), width: w, height: h)), with_);

  void tooth(Rect rect, {double round = 0.35}) {
    final r = Radius.elliptical(rect.width * round, rect.height * round * 0.6);
    stroke(Path()..addRRect(RRect.fromRectAndRadius(rect, r)));
  }

  // ------------------------------------------------------------------ face

  void faceFront({required bool smiling}) {
    oval(0.5, 0.48, 0.72, 0.9);
    // Midline.
    dashed(const Offset(0.5, 0.0), const Offset(0.5, 0.96));
    if (!smiling) {
      // Eye line with the eyes on it.
      dashed(const Offset(0.04, 0.40), const Offset(0.96, 0.40));
      oval(0.34, 0.40, 0.13, 0.045);
      oval(0.66, 0.40, 0.13, 0.045);
      // Relaxed lips: the smile line.
      final lips = Path()
        ..moveTo(0.37, 0.715)
        ..quadraticBezierTo(0.5, 0.735, 0.63, 0.715);
      stroke(lips, paint);
    } else {
      dashed(const Offset(0.14, 0.40), const Offset(0.86, 0.40));
      // A full smile: upper and lower lip lines and the teeth between.
      final smile = Path()
        ..moveTo(0.33, 0.69)
        ..quadraticBezierTo(0.5, 0.725, 0.67, 0.69)
        ..quadraticBezierTo(0.5, 0.82, 0.33, 0.69)
        ..close();
      stroke(smile, paint);
      final teeth = Path()
        ..moveTo(0.36, 0.705)
        ..quadraticBezierTo(0.5, 0.775, 0.64, 0.705);
      stroke(teeth, faint);
      for (final x in [0.42, 0.46, 0.5, 0.54, 0.58]) {
        final top = 0.71 + (x - 0.5).abs() * -0.05;
        line(Offset(x, top), Offset(x, top + 0.03), faint);
      }
    }
  }

  /// A side face looking to the right of the image.
  void profile() {
    final front = Path()
      ..moveTo(0.42, 0.04)
      ..cubicTo(0.62, 0.03, 0.72, 0.14, 0.72, 0.28)
      ..cubicTo(0.72, 0.33, 0.745, 0.35, 0.73, 0.375)
      ..cubicTo(0.76, 0.44, 0.82, 0.5, 0.83, 0.535)
      ..cubicTo(0.8, 0.56, 0.765, 0.56, 0.75, 0.57)
      ..cubicTo(0.77, 0.6, 0.775, 0.62, 0.755, 0.637)
      ..lineTo(0.735, 0.645)
      ..cubicTo(0.765, 0.66, 0.765, 0.69, 0.735, 0.705)
      ..cubicTo(0.71, 0.72, 0.72, 0.745, 0.74, 0.775)
      ..cubicTo(0.75, 0.81, 0.71, 0.845, 0.65, 0.85)
      ..cubicTo(0.58, 0.86, 0.54, 0.86, 0.52, 0.9)
      ..lineTo(0.54, 1.0);
    stroke(front, paint);
    final back = Path()
      ..moveTo(0.42, 0.04)
      ..cubicTo(0.24, 0.05, 0.15, 0.22, 0.17, 0.4)
      ..cubicTo(0.19, 0.55, 0.26, 0.62, 0.3, 0.7)
      ..lineTo(0.28, 1.0);
    stroke(back, paint);
    // Ear and eye.
    oval(0.4, 0.45, 0.08, 0.13);
    final eye = Path()
      ..moveTo(0.63, 0.395)
      ..quadraticBezierTo(0.66, 0.385, 0.69, 0.4);
    stroke(eye, paint);
    // The eye-ear line keeps the head level.
    dashed(const Offset(0.1, 0.4), const Offset(0.95, 0.4));
  }

  /// A face turned 45°, looking to the right of the image.
  void threeQuarter() {
    oval(0.47, 0.48, 0.64, 0.9);
    final midline = Path()
      ..moveTo(0.6, 0.06)
      ..quadraticBezierTo(0.7, 0.47, 0.61, 0.92);
    dashedPath(midline);
    dashed(const Offset(0.08, 0.4), const Offset(0.9, 0.4));
    oval(0.42, 0.4, 0.13, 0.045);
    oval(0.71, 0.4, 0.08, 0.04);
    final nose = Path()
      ..moveTo(0.64, 0.37)
      ..quadraticBezierTo(0.69, 0.47, 0.75, 0.55)
      ..quadraticBezierTo(0.71, 0.575, 0.66, 0.565);
    stroke(nose, paint);
    final mouth = Path()
      ..moveTo(0.49, 0.705)
      ..quadraticBezierTo(0.6, 0.735, 0.69, 0.7);
    stroke(mouth, paint);
    oval(0.2, 0.46, 0.06, 0.13);
  }

  // ------------------------------------------------------------- intraoral

  /// The occlusal plane, rising a little toward the back teeth.
  double _plane(double x) => 0.5 - 0.09 * math.pow((x - 0.5) / 0.45, 2);

  void frontArches() {
    // The retracted lips.
    oval(0.5, 0.5, 0.98, 0.86);
    dashed(const Offset(0.5, 0.1), const Offset(0.5, 0.9));
    const upperW = [0.088, 0.07, 0.072, 0.064, 0.06, 0.055];
    const upperH = [0.21, 0.18, 0.21, 0.17, 0.15, 0.13];
    const lowerW = [0.058, 0.06, 0.068, 0.064, 0.064, 0.058];
    const lowerH = [0.16, 0.16, 0.18, 0.16, 0.14, 0.12];
    for (final side in [-1, 1]) {
      var x = 0.5;
      for (var i = 0; i < upperW.length; i++) {
        final w = upperW[i];
        final cx = x + side * w / 2;
        final y = _plane(cx);
        tooth(Rect.fromLTWH(cx - w / 2 + 0.003, y - upperH[i], w - 0.006, upperH[i]));
        x += side * w;
      }
      x = 0.5;
      for (var i = 0; i < lowerW.length; i++) {
        final w = lowerW[i];
        final cx = x + side * w / 2;
        final y = _plane(cx) + 0.012;
        tooth(Rect.fromLTWH(cx - w / 2 + 0.003, y, w - 0.006, lowerH[i]));
        x += side * w;
      }
    }
  }

  /// The left side of the bite: front teeth to the left of the image.
  void buccal() {
    oval(0.5, 0.5, 0.98, 0.86);
    double plane(double x) => 0.5 + 0.05 * math.pow((x - 0.55) / 0.5, 2);
    final line = Path()..moveTo(0.06, plane(0.06));
    for (var x = 0.08; x <= 0.96; x += 0.02) {
      line.lineTo(x, plane(x));
    }
    dashedPath(line);
    const upperW = [0.07, 0.09, 0.095, 0.095, 0.16, 0.15];
    const upperH = [0.17, 0.23, 0.18, 0.18, 0.17, 0.15];
    const lowerW = [0.065, 0.085, 0.095, 0.095, 0.165, 0.15];
    const lowerH = [0.16, 0.19, 0.17, 0.17, 0.16, 0.14];
    var x = 0.1;
    for (var i = 0; i < upperW.length; i++) {
      final y = plane(x + upperW[i] / 2);
      tooth(Rect.fromLTWH(x + 0.003, y - upperH[i], upperW[i] - 0.006, upperH[i]), round: i >= 4 ? 0.22 : 0.35);
      x += upperW[i];
    }
    x = 0.07;
    for (var i = 0; i < lowerW.length; i++) {
      final y = plane(x + lowerW[i] / 2) + 0.012;
      tooth(Rect.fromLTWH(x + 0.003, y, lowerW[i] - 0.006, lowerH[i]), round: i >= 4 ? 0.22 : 0.35);
      x += lowerW[i];
    }
  }

  /// The upper arch from below: a U with the front teeth at the top.
  void occlusal() {
    // A U: round at the front, the back teeth slightly apart.
    const reach = 0.43 * math.pi;
    final depth = 1 - math.cos(reach);
    Offset at(double t) {
      final theta = t * reach;
      return Offset(0.5 + 0.41 * math.sin(theta), 0.1 + 0.8 * (1 - math.cos(theta)) / depth);
    }

    // Sample the arch to place the teeth along its length.
    const samples = 240;
    final points = [for (var i = 0; i <= samples; i++) at(-1 + 2 * i / samples)];
    final lengths = <double>[0];
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      lengths.add(lengths.last + math.sqrt(math.pow(b.dx - a.dx, 2) + math.pow((b.dy - a.dy) * aspect, 2)));
    }
    final half = lengths.last / 2;
    // Central, lateral, canine, two premolars, two molars.
    const widths = [0.85, 0.68, 0.78, 0.72, 0.7, 1.05, 0.98];
    const depths = [0.085, 0.08, 0.1, 0.12, 0.12, 0.15, 0.145];
    final scale = half * 0.97 / widths.reduce((a, b) => a + b);

    Offset pointAt(double s) {
      var i = lengths.indexWhere((l) => l >= s);
      if (i <= 0) {
        i = 1;
      }
      final f = (s - lengths[i - 1]) / math.max(lengths[i] - lengths[i - 1], 1e-9);
      return Offset.lerp(points[i - 1], points[i], f)!;
    }

    // The arch line.
    final arch = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      arch.lineTo(point.dx, point.dy);
    }
    dashedPath(arch);

    for (final side in [-1, 1]) {
      var s = half;
      for (var i = 0; i < widths.length; i++) {
        final w = widths[i] * scale;
        final mid = half + side * ((s - half).abs() + w / 2);
        final a = pointAt((mid - w / 2).clamp(0, lengths.last));
        final b = pointAt((mid + w / 2).clamp(0, lengths.last));
        final center = pointAt(mid);
        // Work in an un-stretched space so the teeth stay square.
        final angle = math.atan2((b.dy - a.dy) * aspect, b.dx - a.dx);
        final depth = depths[i];
        within(
          Matrix4.identity()
            ..translateByDouble(center.dx, center.dy, 0, 1)
            ..scaleByDouble(1, 1 / aspect, 1, 1)
            ..rotateZ(angle),
          () => tooth(Rect.fromCenter(center: Offset.zero, width: w * 0.94, height: depth), round: i >= 3 ? 0.3 : 0.45),
        );
        s = half + side * ((s - half).abs() + w);
      }
    }
  }

  /// The front teeth from the side: the upper incisor over the lower one,
  /// lip side to the right.
  void overjet() {
    // Drawn narrow around x = 0.53, then widened to fill the frame.
    within(
      Matrix4.identity()
        ..translateByDouble(0.5, 0, 0, 1)
        ..scaleByDouble(2.1, 1, 1, 1)
        ..translateByDouble(-0.53, 0, 0, 1),
      () {
        // Gums.
        stroke(
          Path()
            ..moveTo(0.33, 0.13)
            ..quadraticBezierTo(0.5, 0.09, 0.71, 0.12),
          faint,
        );
        stroke(
          Path()
            ..moveTo(0.35, 0.89)
            ..quadraticBezierTo(0.5, 0.93, 0.7, 0.88),
          faint,
        );
        // Upper incisor: cingulum on the tongue side, edge forward and down.
        stroke(
          Path()
            ..moveTo(0.4, 0.12)
            ..cubicTo(0.4, 0.26, 0.47, 0.3, 0.52, 0.4)
            ..cubicTo(0.56, 0.47, 0.6, 0.55, 0.63, 0.6)
            ..quadraticBezierTo(0.66, 0.615, 0.67, 0.59)
            ..cubicTo(0.665, 0.45, 0.6, 0.25, 0.56, 0.1),
        );
        // Lower incisor behind it, its edge on the upper's tongue side.
        stroke(
          Path()
            ..moveTo(0.45, 0.9)
            ..cubicTo(0.46, 0.72, 0.5, 0.56, 0.535, 0.465)
            ..quadraticBezierTo(0.55, 0.44, 0.567, 0.468)
            ..cubicTo(0.59, 0.58, 0.6, 0.74, 0.6, 0.9),
        );
      },
    );
    // The overjet: lower lip-side surface to the upper edge.
    dashed(const Offset(0.6, 0.53), const Offset(0.8, 0.53), dash: 5, gap: 4);
  }

  // ---------------------------------------------------------------- x-ray

  void xray() {
    final rect = const Rect.fromLTWH(0, 0, 1, 1).deflate(0.01);
    stroke(Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.elliptical(0.03, 0.03 / aspect))), faint);
    // Corner brackets.
    const l = 0.12;
    final lv = l / aspect;
    for (final corner in [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight]) {
      final sx = corner.dx < 0.5 ? 1 : -1;
      final sy = corner.dy < 0.5 ? 1 : -1;
      line(corner, corner + Offset(sx * l, 0), paint);
      line(corner, corner + Offset(0, sy * lv), paint);
    }
  }
}

/// The outline over the camera (or over the placeholder on web).
class BlueprintOverlay extends StatelessWidget {
  const BlueprintOverlay({super.key, required this.blueprint, this.color = Colors.white, this.opacity = 0.35});

  final Blueprint blueprint;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        key: const Key('blueprint'),
        painter: BlueprintPainter(blueprint, color: color, opacity: opacity),
        size: Size.infinite,
      ),
    );
  }
}
