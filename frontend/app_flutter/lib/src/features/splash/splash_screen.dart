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
  late final _ctrl =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      });
  bool _started = false, _navigated = false;
  void _finish() {
    if (_navigated) return;
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pushReplacementNamed(widget.next);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl.stop();
      _finish();
    } else if (!_started) {
      _started = true;
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            final progress = Curves.easeOutCubic.transform(_ctrl.value);
            return Opacity(
              opacity: progress,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - progress)),
                child: child,
              ),
            );
          },
          child: Semantics(
            label: 'Creo. Opening sign in.',
            child: ExcludeSemantics(child: CreoWordmark(fontSize: 54)),
          ),
        ),
      ),
    ),
  );
}

/// Product wordmark with the shared warm accent on its dot.
class CreoWordmark extends StatelessWidget {
  const CreoWordmark({super.key, this.fontSize = 26});
  final double fontSize;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: 'creo',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF2B1E15),
          ),
        ),
        const TextSpan(
          text: '.',
          style: TextStyle(color: Color(0xFFD2965A)),
        ),
      ],
    ),
    semanticsLabel: 'Creo',
    style: TextStyle(
      fontFamily: 'Inter',
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: -1,
    ),
  );
}

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
