import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Loading screen: the Creo "C." mark, then straight to sign-in.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.next = '/login'});
  final String next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // 0-30% fade in, 30-50% hold, 50-100% zoom through the "C" toward the viewer.
  late final _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );
  late final _fadeIn = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0, .3, curve: Curves.easeOut),
  );
  late final _zoom = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(.5, 1, curve: Curves.easeInCubic),
  );
  late final _fadeOut = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(.8, 1),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward().whenComplete(() {
      if (mounted) Navigator.of(context).pushReplacementNamed(widget.next);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF171614),
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) => Opacity(
            opacity: _fadeIn.value * (1 - _fadeOut.value),
            child: Transform.scale(
              // Centre of the "C" so the camera flies through its opening.
              alignment: const Alignment(-.36, 0),
              scale: 0.9 + 0.1 * _fadeIn.value + 30 * _zoom.value,
              child: child,
            ),
          ),
          child: const CreoMark(height: 64),
        ),
      ),
    );
  }
}

/// The "C." mark, drawn in code so it stays sharp at any size.
class CreoMark extends StatelessWidget {
  const CreoMark({super.key, this.height = 64});
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Creo',
    child: CustomPaint(
      size: Size(height * 100 / 64, height),
      painter: _LogoPainter(),
    ),
  );
}

class _LogoPainter extends CustomPainter {
  static const _amber = Color(0xFFD2965A);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final stroke = h * 0.26;
    final r = (h - stroke) / 2;
    final arc = Paint()
      ..color = _amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    // "C": circle open on the right.
    canvas.drawArc(
      Rect.fromCircle(center: Offset(h / 2, h / 2), radius: r),
      math.pi / 4,
      math.pi * 1.5,
      false,
      arc,
    );
    // ".": dot at the baseline.
    final dot = h * 0.2;
    canvas.drawCircle(
      Offset(size.width - dot, h - dot),
      dot,
      Paint()..color = _amber,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
