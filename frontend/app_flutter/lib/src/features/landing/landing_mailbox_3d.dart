import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

double _stage(double value, double start, double end) {
  final t = ((value - start) / (end - start)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// React scenes.ts maps slot pass before models.ts stages the moving parts.
@immutable
class MailboxSceneFrame {
  const MailboxSceneFrame(this.pass);
  final double pass;
  double get cycle => _stage(pass, .15, .7);
  double get flag => _stage(cycle, .15, .45);
  double get door => _stage(cycle, .35, .6);
  double get envelope => _stage(cycle, .5, .8);
  double get doorAngle => door * 1.45;
  double get cameraYaw => .85 - .55 * pass.clamp(0.0, 1.0);
}

class _V {
  const _V(this.x, this.y, this.z);
  final double x, y, z;
  _V operator -(_V other) => _V(x - other.x, y - other.y, z - other.z);
  _V cross(_V b) => _V(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x);
  double dot(_V b) => x * b.x + y * b.y + z * b.z;
  _V get unit {
    final length = math.sqrt(dot(this));
    return length < .00001
        ? const _V(0, 0, 1)
        : _V(x / length, y / length, z / length);
  }
}

class _Face {
  const _Face(
    this.points,
    this.color, {
    this.metal = false,
    this.paper = false,
  });
  final List<_V> points;
  final Color color;
  final bool metal, paper;
}

class _ProjectedFace {
  const _ProjectedFace(this.face, this.points, this.depth, this.color);
  final _Face face;
  final List<Offset> points;
  final double depth;
  final Color color;
}

/// Small, bounded 3D mesh rendered with perspective and depth-sorted faces.
/// There is no elapsed-time loop, image decoding or external renderer here.
class MailboxPerspectivePainter extends CustomPainter {
  const MailboxPerspectivePainter({required this.frame, required this.palette});
  final MailboxSceneFrame frame;
  final CreoPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final faces = <_Face>[];
    const shell = Color(0xFFE6DECC);
    const brass = Color(0xFFD2965A);
    const steel = Color(0xFF8D8F82);
    const dark = Color(0xFF22251F);
    const front = 80.0;
    const back = -90.0;
    const hingeY = 38.0;
    const hingeZ = 83.0;

    List<_V> profile(double radius, double bottom, double z) => [
      _V(-radius, bottom, z),
      for (var i = 0; i <= 18; i++)
        _V(
          radius * math.cos(math.pi - i * math.pi / 18),
          -12 - radius * math.sin(math.pi - i * math.pi / 18),
          z,
        ),
      _V(radius, bottom, z),
    ];

    void box(_V a, _V b, Color color, {_V Function(_V)? transform}) {
      _V p(double x, double y, double z) =>
          transform?.call(_V(x, y, z)) ?? _V(x, y, z);
      final left = [
        p(a.x, a.y, a.z),
        p(a.x, a.y, b.z),
        p(a.x, b.y, b.z),
        p(a.x, b.y, a.z),
      ];
      final right = [
        p(b.x, a.y, b.z),
        p(b.x, a.y, a.z),
        p(b.x, b.y, a.z),
        p(b.x, b.y, b.z),
      ];
      final top = [
        p(a.x, a.y, a.z),
        p(b.x, a.y, a.z),
        p(b.x, a.y, b.z),
        p(a.x, a.y, b.z),
      ];
      final bottom = [
        p(a.x, b.y, b.z),
        p(b.x, b.y, b.z),
        p(b.x, b.y, a.z),
        p(a.x, b.y, a.z),
      ];
      final rear = [
        p(b.x, a.y, a.z),
        p(a.x, a.y, a.z),
        p(a.x, b.y, a.z),
        p(b.x, b.y, a.z),
      ];
      final forward = [
        p(a.x, a.y, b.z),
        p(b.x, a.y, b.z),
        p(b.x, b.y, b.z),
        p(a.x, b.y, b.z),
      ];
      for (final quad in [left, right, top, bottom, rear, forward]) {
        faces.add(_Face(quad, color, metal: true));
      }
    }

    // Extruded arched shell: roof strips, side walls, bottom and rear cap.
    final outerFront = profile(45, 38, front);
    final outerBack = profile(45, 38, back);
    final innerFront = profile(39, 32, front + .5);
    final innerBack = profile(39, 32, front - 46);
    for (var i = 0; i < outerFront.length; i++) {
      final j = (i + 1) % outerFront.length;
      faces.add(
        _Face(
          [outerFront[i], outerBack[i], outerBack[j], outerFront[j]],
          shell,
          metal: true,
        ),
      );
      faces.add(
        _Face(
          [outerFront[i], outerFront[j], innerFront[j], innerFront[i]],
          const Color(0xFFB8AA8C),
          metal: true,
        ),
      );
      faces.add(
        _Face([
          innerFront[j],
          innerBack[j],
          innerBack[i],
          innerFront[i],
        ], const Color(0xFF393A2E)),
      );
    }
    faces.add(_Face(outerBack.reversed.toList(), shell));
    faces.add(_Face(innerBack, const Color(0xFF11140F)));
    box(const _V(-10, 38, -27), const _V(10, 138, -7), shell);
    box(const _V(-26, 136, -39), const _V(26, 142, 5), steel);
    box(const _V(-47, 35, 78), const _V(47, 41, 87), steel);

    // Every door vertex, bevel and handle uses the same bottom hinge transform.
    _V doorPoint(_V point) {
      final y = point.y - hingeY, z = point.z - hingeZ;
      final c = math.cos(frame.doorAngle), s = math.sin(frame.doorAngle);
      return _V(point.x, hingeY + y * c + z * s, hingeZ - y * s + z * c);
    }

    final doorFront = profile(43, 37, 86).map(doorPoint).toList();
    final doorBack = profile(43, 37, 82).map(doorPoint).toList();
    faces.add(_Face(doorFront, brass, metal: true));
    faces.add(
      _Face(doorBack.reversed.toList(), const Color(0xFFBCA277), metal: true),
    );
    for (var i = 0; i < doorFront.length; i++) {
      final j = (i + 1) % doorFront.length;
      faces.add(
        _Face(
          [doorFront[i], doorFront[j], doorBack[j], doorBack[i]],
          const Color(0xFF8D7149),
          metal: true,
        ),
      );
    }
    box(
      const _V(-12, -34, 86),
      const _V(12, -29, 91),
      dark,
      transform: doorPoint,
    );
    for (final x in [-34.0, 24.0]) {
      box(_V(x, 35, 85), _V(x + 10, 41, 90), brass);
    }

    // Side flag rotates about its real mount before the door opens.
    box(const _V(-50, -20, -36), const _V(-45, 1, -21), steel);
    final flagAngle = frame.flag * math.pi / 2;
    _V flagPoint(_V point) {
      final y = point.y, z = point.z;
      return _V(
        point.x,
        -9 + y * math.cos(flagAngle) - z * math.sin(flagAngle),
        -28 + y * math.sin(flagAngle) + z * math.cos(flagAngle),
      );
    }

    box(
      const _V(-52, -2, 0),
      const _V(-49, 2, 42),
      brass,
      transform: flagPoint,
    );
    box(
      const _V(-53, -18, 26),
      const _V(-48, 2, 43),
      const Color(0xFFC77D3D),
      transform: flagPoint,
    );

    // Envelopes move through the depth axis and occlude inside the cavity.
    for (var i = 0; i < 3; i++) {
      final travel = _stage(frame.cycle, .5 + i * .025, .8);
      final z = 42 + travel * (129 + i * 8);
      final y = 8 - travel * (15 + i * 7);
      final roll = (-.13 + i * .12) * travel;
      _V paper(double x, double dy, double dz) => _V(
        x * math.cos(roll) - dy * math.sin(roll) + (i - 1) * 4 * travel,
        y + x * math.sin(roll) + dy * math.cos(roll),
        z + dz - x * travel * .1,
      );
      final frontPaper = [
        paper(-29, -18, 1),
        paper(29, -18, 1),
        paper(29, 18, 1),
        paper(-29, 18, 1),
      ];
      final rearPaper = [
        paper(-29, -18, -1),
        paper(29, -18, -1),
        paper(29, 18, -1),
        paper(-29, 18, -1),
      ];
      final paperColor = Color.lerp(
        const Color(0xFFE4D7BD),
        const Color(0xFFFFFAEE),
        i / 2,
      )!;
      faces.add(_Face(rearPaper.reversed.toList(), const Color(0xFFC9B99B)));
      faces.add(_Face(frontPaper, paperColor, paper: true));
      for (var side = 0; side < 4; side++) {
        final next = (side + 1) % 4;
        faces.add(
          _Face([
            frontPaper[side],
            frontPaper[next],
            rearPaper[next],
            rearPaper[side],
          ], const Color(0xFFBBAB8F)),
        );
      }
    }

    final yaw = frame.cameraYaw, pitch = .24;
    _V view(_V p) {
      final x = p.x * math.cos(yaw) + p.z * math.sin(yaw);
      final z = -p.x * math.sin(yaw) + p.z * math.cos(yaw);
      return _V(
        x,
        p.y * math.cos(pitch) + z * math.sin(pitch),
        -p.y * math.sin(pitch) + z * math.cos(pitch),
      );
    }

    Offset project(_V point) {
      final v = view(point);
      final factor = 760 / (760 - v.z);
      return Offset(v.x * factor, v.y * factor);
    }

    final light = const _V(-.5, -.85, .65).unit;
    Color shaded(_Face face) {
      final normal = (face.points[1] - face.points[0])
          .cross(face.points[2] - face.points[0])
          .unit;
      final diffuse = math.max(0.0, normal.dot(light));
      final specular = face.metal
          ? .13 *
                math.pow(
                  math.max(0.0, normal.dot(const _V(-.25, -.6, .9).unit)),
                  18,
                )
          : 0.0;
      final amount = .62 + .4 * diffuse + specular;
      int channel(double c) => (c * 255 * amount).round().clamp(0, 255);
      return Color.fromARGB(
        255,
        channel(face.color.r),
        channel(face.color.g),
        channel(face.color.b),
      );
    }

    final projected =
        faces
            .map(
              (face) => _ProjectedFace(
                face,
                face.points.map(project).toList(),
                face.points.map((p) => view(p).z).reduce((a, b) => a + b) /
                    face.points.length,
                shaded(face),
              ),
            )
            .toList()
          ..sort((a, b) => a.depth.compareTo(b.depth));

    canvas.save();
    canvas.translate(size.width / 2, size.height * .43);
    canvas.scale(math.min(size.width / 390, size.height / 310));
    final foot = project(const _V(0, 144, -17));
    canvas.save();
    canvas.translate(foot.dx, foot.dy);
    canvas.scale(82, 10);
    canvas.drawCircle(
      Offset.zero,
      1,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black.withValues(alpha: palette.lightness > .5 ? .2 : .42),
            Colors.transparent,
          ],
        ).createShader(const Rect.fromLTWH(-1, -1, 2, 2)),
    );
    canvas.restore();
    for (final face in projected) {
      final path = Path()..addPolygon(face.points, true);
      final paint = Paint()..color = face.color;
      if (face.face.metal) {
        paint.shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(face.color, Colors.white, .07)!,
            face.color,
            Color.lerp(face.color, Colors.black, .04)!,
          ],
        ).createShader(path.getBounds());
      }
      canvas.drawPath(path, paint);
      // A matching hairline closes anti-alias cracks between roof segments.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .45
          ..color = face.color,
      );
      if (face.face.paper) _paperDetails(canvas, face.points);
    }
    canvas.restore();
  }

  static void _paperDetails(Canvas canvas, List<Offset> corners) {
    Offset uv(double u, double v) => Offset.lerp(
      Offset.lerp(corners[0], corners[1], u)!,
      Offset.lerp(corners[3], corners[2], u)!,
      v,
    )!;
    final fold = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(uv(.5, .57).dx, uv(.5, .57).dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..moveTo(corners[3].dx, corners[3].dy)
      ..lineTo(uv(.35, .48).dx, uv(.35, .48).dy)
      ..moveTo(corners[2].dx, corners[2].dy)
      ..lineTo(uv(.65, .48).dx, uv(.65, .48).dy);
    canvas.drawPath(
      fold,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..color = const Color(0xFFAE9874),
    );
    canvas.drawPath(
      Path()..addPolygon([
        uv(.76, .12),
        uv(.9, .12),
        uv(.9, .36),
        uv(.76, .36),
      ], true),
      Paint()..color = const Color(0xFFCBA66D),
    );
    for (var i = 0; i < 2; i++) {
      canvas.drawLine(
        uv(.12, .7 + i * .1),
        uv(.42, .7 + i * .1),
        Paint()
          ..strokeWidth = .7
          ..color = const Color(0xFFB8A78B),
      );
    }
  }

  @override
  bool shouldRepaint(MailboxPerspectivePainter oldDelegate) =>
      oldDelegate.frame.pass != frame.pass ||
      oldDelegate.palette.lightness != palette.lightness;
}
