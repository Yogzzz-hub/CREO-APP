import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'landing_mailbox_3d.dart';

const landingLaptopPictures = <ImageProvider>[
  AssetImage('assets/landing/fitness.jpg'),
  AssetImage('assets/landing/bakery.jpg'),
  AssetImage('assets/landing/beauty.jpg'),
];

// HomePage.tsx / ScrollFlipText.tsx use function transforms, not elapsed time.
double landingRamp(double value, double start, double end) =>
    ((value - start) / (end - start)).clamp(0.0, 1.0);
double _smooth(double start, double end, double value) {
  final t = landingRamp(value, start, end);
  return t * t * (3 - 2 * t);
}

const landingExpo = Cubic(0.16, 1, 0.3, 1);

@immutable
class LandingHeroFrame {
  const LandingHeroFrame(this.progress);
  final double progress;
  double get dotScale =>
      math.pow(170, landingRamp(progress, 0, .12)).toDouble();
  double get glyphOpacity => 1 - landingRamp(progress, 0, .045);
  double get introOpacity => 1 - landingRamp(progress, .12, .165);
  double get open => _smooth(.34, .58, progress);
  double get dive => _smooth(.6, .82, progress);
  double get screenDim => _smooth(.76, .85, progress);
  double get subtitle => landingRamp(progress, .88, .95);
  bool get propsVisible => progress >= .08 && progress <= .86;
}

/// A source-derived per-letter flip. Words stay intact when wrapping and the
/// screen reader sees one heading, not separate animated character nodes.
class LandingFlipText extends StatelessWidget {
  const LandingFlipText({
    super.key,
    required this.text,
    required this.progress,
    required this.style,
    this.from = 0,
    this.to = 1,
    this.center = false,
  });
  final String text;
  final double progress;
  final TextStyle style;
  final double from;
  final double to;
  final bool center;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(
        text,
        style: style,
        textAlign: center ? TextAlign.center : null,
      );
    }
    final total = text.replaceAll(' ', '').length;
    final span = to - from;
    var index = 0;
    return Semantics(
      label: text,
      header: true,
      child: ExcludeSemantics(
        child: Wrap(
          alignment: center ? WrapAlignment.center : WrapAlignment.start,
          spacing: (style.fontSize ?? 32) * .24,
          children: text.split(' ').map((word) {
            return Wrap(
              children: word.characters.map((character) {
                final start = from + (index++ / math.max(total, 1)) * span * .6;
                final end = start + span * .4;
                final amount = landingRamp(progress, start, end);
                return Opacity(
                  opacity: landingRamp(
                    progress,
                    start,
                    start + (end - start) * .7,
                  ),
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 1 / 700)
                      ..translate(
                        0.0,
                        (style.fontSize ?? 32) * .42 * (1 - amount),
                      )
                      ..rotateX(-100 * math.pi / 180 * (1 - amount)),
                    child: Text(character, style: style),
                  ),
                );
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Once-on-viewport reveal: React's 28px / 850ms expo and -12% bottom margin.
/// No polling ticker runs before the element enters; scroll work is coalesced.
class LandingReveal extends StatefulWidget {
  const LandingReveal({
    super.key,
    required this.scroll,
    required this.child,
    this.delay = Duration.zero,
    this.mask = false,
  });
  final ScrollController scroll;
  final Widget child;
  final Duration delay;
  final bool mask;
  @override
  State<LandingReveal> createState() => _LandingRevealState();
}

class _LandingRevealState extends State<LandingReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.mask
        ? const Duration(milliseconds: 1300)
        : const Duration(milliseconds: 850),
  );
  bool _played = false;
  bool _scheduled = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_checkLater);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _generation++;
      _played = true;
      _controller.value = 1;
    } else {
      _checkLater();
    }
  }

  @override
  void didUpdateWidget(LandingReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scroll != widget.scroll) {
      oldWidget.scroll.removeListener(_checkLater);
      widget.scroll.addListener(_checkLater);
    }
    _checkLater();
  }

  void _checkLater() {
    if (_scheduled || _played) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _played) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final top = box.localToGlobal(Offset.zero).dy;
      final viewport = MediaQuery.sizeOf(context).height;
      if (top < viewport * .88 && top + box.size.height > 0) {
        _played = true;
        final generation = ++_generation;
        if (widget.delay == Duration.zero) {
          _controller.forward();
        } else {
          Future<void>.delayed(widget.delay, () {
            if (mounted && generation == _generation) _controller.forward();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _generation++;
    widget.scroll.removeListener(_checkLater);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final t = landingExpo.transform(_controller.value);
      if (widget.mask) {
        return ClipRect(
          clipper: _CenterRevealClipper(t),
          child: Transform.scale(scale: 1.06 - .06 * t, child: child),
        );
      }
      return Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 28 * (1 - t)),
          child: child,
        ),
      );
    },
  );
}

class _CenterRevealClipper extends CustomClipper<Rect> {
  const _CenterRevealClipper(this.progress);
  final double progress;
  @override
  Rect getClip(Size size) => Rect.fromCenter(
    center: size.center(Offset.zero),
    width: size.width,
    height: size.height * progress,
  );
  @override
  bool shouldReclip(_CenterRevealClipper oldClipper) =>
      oldClipper.progress != progress;
}

/// Element scroll progress: start at 95% viewport, settle at 40% (React defaults).
class LandingScrollHeading extends StatefulWidget {
  const LandingScrollHeading({
    super.key,
    required this.scroll,
    required this.text,
    required this.style,
  });
  final ScrollController scroll;
  final String text;
  final TextStyle style;
  @override
  State<LandingScrollHeading> createState() => _LandingScrollHeadingState();
}

class _LandingScrollHeadingState extends State<LandingScrollHeading> {
  double _progress = 0;
  bool _scheduled = false;
  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_measure);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _measure();
  }

  @override
  void didUpdateWidget(LandingScrollHeading oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scroll != widget.scroll) {
      oldWidget.scroll.removeListener(_measure);
      widget.scroll.addListener(_measure);
    }
    _measure();
  }

  void _measure() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final h = MediaQuery.sizeOf(context).height;
      final p = ((h * .95 - box.localToGlobal(Offset.zero).dy) / (h * .55))
          .clamp(0.0, 1.0);
      if (p != _progress) setState(() => _progress = p);
    });
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_measure);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final preferred = widget.style.fontSize ?? 32;
      final width = constraints.hasBoundedWidth ? constraints.maxWidth : 640.0;
      return LandingFlipText(
        text: widget.text,
        progress: _progress,
        style: widget.style.copyWith(
          fontSize: (width / 10).clamp(math.min(28.0, preferred), preferred),
        ),
      );
    },
  );
}

/// Native equivalent of the 460svh sticky hero. SliverMainAxisGroup limits the
/// pinned header to its own section, so it never covers following content.
class LandingHeroDelegate extends SliverPersistentHeaderDelegate {
  LandingHeroDelegate({
    required this.height,
    required this.reduced,
    required this.onContinue,
  });
  final double height;
  final bool reduced;
  final VoidCallback onContinue;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height * (reduced ? 1 : 4.6);
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = reduced
        ? 1.0
        : (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: height,
        child: LandingHero(progress: progress, onContinue: onContinue),
      ),
    );
  }

  @override
  bool shouldRebuild(LandingHeroDelegate oldDelegate) =>
      height != oldDelegate.height ||
      reduced != oldDelegate.reduced ||
      onContinue != oldDelegate.onContinue;
}

class LandingHero extends StatefulWidget {
  const LandingHero({
    super.key,
    required this.progress,
    required this.onContinue,
    this.imageProviders = landingLaptopPictures,
  });
  final double progress;
  final VoidCallback onContinue;
  final List<ImageProvider> imageProviders;
  @override
  State<LandingHero> createState() => _LandingHeroState();
}

class _LandingHeroState extends State<LandingHero> {
  final _streams = <ImageStream>[];
  final _listeners = <ImageStreamListener>[];
  final _photos = List<ImageInfo?>.filled(3, null);
  bool _resolved = false;
  int _imageEpoch = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolvePictures();
  }

  @override
  void didUpdateWidget(LandingHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.imageProviders, widget.imageProviders)) {
      _releasePictures();
      _resolved = false;
    }
    _resolvePictures();
  }

  void _resolvePictures() {
    if (_resolved || MediaQuery.disableAnimationsOf(context)) return;
    _resolved = true;
    final epoch = _imageEpoch;
    for (var i = 0; i < math.min(3, widget.imageProviders.length); i++) {
      final slot = i;
      final stream = ResizeImage(
        widget.imageProviders[i],
        width: 512,
        height: 512,
        policy: ResizeImagePolicy.fit,
      ).resolve(createLocalImageConfiguration(context));
      final listener = ImageStreamListener(
        (info, synchronous) {
          if (!mounted || epoch != _imageEpoch) {
            info.dispose();
            return;
          }
          final old = _photos[slot];
          setState(() => _photos[slot] = info);
          if (old != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
          }
        },
        onError: (Object error, StackTrace? stack) {
          // Keep the current neutral illustration when an asset cannot decode.
        },
      );
      _streams.add(stream);
      _listeners.add(listener);
      stream.addListener(listener);
    }
  }

  void _releasePictures() {
    _imageEpoch++;
    for (var i = 0; i < _streams.length; i++) {
      _streams[i].removeListener(_listeners[i]);
    }
    _streams.clear();
    _listeners.clear();
    for (var i = 0; i < _photos.length; i++) {
      _photos[i]?.dispose();
      _photos[i] = null;
    }
  }

  @override
  void dispose() {
    _releasePictures();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final frame = LandingHeroFrame(reduced ? 1 : widget.progress);
    return LayoutBuilder(
      builder: (context, constraints) => ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: CustomPaint(
                painter: LandingHeroPainter(
                  frame,
                  photos: _photos
                      .map((photo) => photo?.image)
                      .toList(growable: false),
                ),
              ),
            ),
            if (!reduced && frame.introOpacity > 0)
              Positioned(
                bottom: 32,
                left: 20,
                right: 20,
                child: Opacity(
                  opacity: frame.glyphOpacity,
                  child: const Text(
                    '↓  Scroll to dive in',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: CreoColors.appMist, fontSize: 16),
                  ),
                ),
              ),
            // Hidden copy cannot intercept taps or create duplicate semantic nodes.
            IgnorePointer(
              ignoring: frame.subtitle < .95,
              child: ExcludeSemantics(
                excluding: frame.subtitle == 0,
                child: Center(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 28,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LandingFlipText(
                            text: 'Content that ships every week.',
                            progress: frame.progress,
                            from: .8,
                            to: .95,
                            center: true,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize:
                                  ((math.min(constraints.maxWidth, 868) - 48) *
                                          .105)
                                      .clamp(32.0, 82.0),
                              fontWeight: FontWeight.w500,
                              height: .98,
                              letterSpacing: -1.8,
                              color: CreoColors.appInk,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Opacity(
                            opacity: frame.subtitle,
                            child: Transform.translate(
                              offset: Offset(0, 24 * (1 - frame.subtitle)),
                              child: Column(
                                children: [
                                  const Text(
                                    'A creative pod for D2C brands: a lead, editor and designer who deliver reels, carousels and stories to a portal you approve in one click.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 18,
                                      height: 1.5,
                                      color: CreoColors.appMist,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  LandingPressFeedback(
                                    child: IconButton.filled(
                                      tooltip: 'Scroll to how we work',
                                      style: IconButton.styleFrom(
                                        backgroundColor: CreoColors.appInk,
                                        foregroundColor: CreoColors.onAccent,
                                        minimumSize: const Size(56, 56),
                                      ),
                                      onPressed: widget.onContinue,
                                      icon: const Icon(Icons.arrow_downward),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The source's hover 1.05 / active .95 transform adapted to touch down/cancel.
class LandingPressFeedback extends StatefulWidget {
  const LandingPressFeedback({super.key, required this.child});
  final Widget child;
  @override
  State<LandingPressFeedback> createState() => _LandingPressFeedbackState();
}

class _LandingPressFeedbackState extends State<LandingPressFeedback> {
  bool _pressed = false;
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() {
      _hovered = false;
      _pressed = false;
    }),
    child: Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: MediaQuery.disableAnimationsOf(context)
            ? 1
            : (_pressed
                  ? .95
                  : _hovered
                  ? 1.05
                  : 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        child: widget.child,
      ),
    ),
  );
}

/// Canvas approximation of the source Three.js scene. No shaders, blur layers,
/// image decoding, or perpetual tickers are needed to scrub its geometric props.
class LandingHeroPainter extends CustomPainter {
  const LandingHeroPainter(this.frame, {this.photos = const []});
  final LandingHeroFrame frame;
  final List<ui.Image?> photos;
  @override
  void paint(Canvas canvas, Size size) {
    final p = frame.progress;
    final bg = p < .115
        ? CreoColors.appBase
        : Color.lerp(
            CreoColors.accent,
            CreoColors.appBase,
            _smooth(.6, .8, p),
          )!;
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    if (frame.propsVisible) {
      final appear = _smooth(.1, .32, p);
      final scale = (.55 + .45 * appear) * (1 + frame.dive * 6);
      canvas.save();
      canvas.translate(size.width / 2, size.height * .49 + 35 * (1 - appear));
      canvas.scale(math.min(size.width / 400, size.height / 580) * scale);
      canvas.rotate((1 - _smooth(.12, .58, p)) * -.3);
      final fade = 1 - _smooth(.8, .86, p);
      final body = Paint()
        ..color = const Color(0xFF33332F).withValues(alpha: fade);
      // Centre the camera on the display during the dive, rather than zooming
      // into the keyboard. Every detail derives from the same scroll frame.
      canvas.translate(0, (10 + 170 * frame.open) * .5 * frame.dive);
      _laptop(canvas, frame, fade, photos);
      if (frame.dive < .85) {
        for (final side in [-1, 1]) {
          canvas.save();
          canvas.translate(side * 104.0, side * 180.0);
          canvas.rotate(side * .12);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-27, -52, 54, 104),
              const Radius.circular(9),
            ),
            body,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-23, -47, 46, 94),
              const Radius.circular(6),
            ),
            Paint()..color = CreoColors.accent.withValues(alpha: fade),
          );
          _label(
            canvas,
            'creo.',
            const Offset(-16, -10),
            15,
            CreoColors.onAccent.withValues(alpha: fade),
          );
          canvas.restore();
        }
      }
      canvas.restore();
      if (frame.dive < .9) {
        canvas.save();
        canvas.translate(size.width * .51, size.height * .28);
        canvas.rotate(-.25 + p * 1.1);
        final mark = Rect.fromCircle(
          center: Offset.zero,
          radius: 31 * (1 + frame.dive * .8),
        );
        canvas.drawArc(
          mark,
          .65,
          math.pi * 1.58,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 13
            ..strokeCap = StrokeCap.round
            ..shader = const LinearGradient(
              colors: [Color(0xFF777A7B), Color(0xFFF5EEE3), Color(0xFF8E9090)],
            ).createShader(mark),
        );
        canvas.drawCircle(
          const Offset(40, 21),
          8,
          Paint()..color = CreoColors.appInk,
        );
        canvas.restore();
      }
    }
    // The routed React scene frames the opening mark with stars before the
    // laptop appears. Keep those props independent of its .08 visibility gate.
    if (p < .86) {
      for (var i = 0; i < 4; i++) {
        canvas.save();
        canvas.translate(
          size.width * [.12, .85, .2, .89][i],
          size.height * [.18, .32, .76, .82][i] - frame.dive * 70,
        );
        canvas.rotate(p * (i.isEven ? 1 : -1));
        final star = Path()
          ..moveTo(0, -16)
          ..quadraticBezierTo(2, -2, 16, 0)
          ..quadraticBezierTo(2, 2, 0, 16)
          ..quadraticBezierTo(-2, 2, -16, 0)
          ..quadraticBezierTo(-2, -2, 0, -16)
          ..close();
        canvas.drawPath(
          star,
          Paint()
            ..color = (i == 1 ? CreoColors.accent : CreoColors.appInk)
                .withValues(alpha: 1 - frame.dive),
        );
        canvas.restore();
      }
    }
    if (frame.introOpacity > 0) {
      final ink = CreoColors.accent.withValues(alpha: frame.introOpacity);
      final center = Offset(size.width / 2, size.height / 2);
      canvas.drawArc(
        Rect.fromCircle(center: center.translate(-16, 0), radius: 31),
        .8,
        math.pi * 1.5,
        false,
        Paint()
          ..color = ink.withValues(
            alpha: frame.glyphOpacity * frame.introOpacity,
          )
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
      canvas.drawCircle(
        center.translate(44, 25),
        14 * frame.dotScale,
        Paint()..color = ink,
      );
    }
  }

  static void _laptop(
    Canvas canvas,
    LandingHeroFrame frame,
    double opacity,
    List<ui.Image?> photos,
  ) {
    final screenH = 10 + 170 * frame.open;
    final screen = Rect.fromLTRB(-145, -screenH, 145, 0);
    final bezel = RRect.fromRectAndRadius(
      screen.inflate(9),
      const Radius.circular(9),
    );
    Color ink(int value) => Color(value).withValues(alpha: opacity);

    // Soft contact shadow without a blur layer; brushed aluminium bezel.
    final shadow = const Rect.fromLTWH(-200, 50, 400, 54);
    canvas.drawOval(
      shadow,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black.withValues(alpha: opacity * .26),
            Colors.transparent,
          ],
        ).createShader(shadow),
    );
    canvas.drawRRect(
      bezel,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ink(0xFFB6B5AE),
            ink(0xFF484A49),
            ink(0xFF858780),
            ink(0xFF292B29),
          ],
          stops: const [0, .32, .7, 1],
        ).createShader(bezel.outerRect),
    );
    canvas.drawRRect(
      bezel.deflate(.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = ink(0xFFD7D9D0),
    );
    final glass = RRect.fromRectAndRadius(screen, const Radius.circular(3));
    canvas.drawRRect(glass, Paint()..color = ink(0xFF090B0D));
    if (frame.open > .15) {
      canvas.save();
      canvas.clipRRect(glass);
      _portal(canvas, screen, opacity * _smooth(.15, .38, frame.open), photos);
      // A restrained diagonal reflection changes angle with the opening lid.
      final reflection = Path()
        ..moveTo(-145, -screenH)
        ..lineTo(-95 + 100 * frame.open, -screenH)
        ..lineTo(145, -screenH * .18)
        ..lineTo(145, 0)
        ..close();
      canvas.drawPath(
        reflection,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: opacity * .12),
              Colors.transparent,
            ],
          ).createShader(screen),
      );
      canvas.drawRect(
        screen,
        Paint()
          ..color = CreoColors.appBase.withValues(
            alpha: frame.screenDim * opacity,
          ),
      );
      canvas.restore();
      canvas.drawCircle(
        Offset(0, -screenH - 4.5),
        1.6,
        Paint()..color = ink(0xFF101714),
      );
      canvas.drawCircle(
        Offset(0, -screenH - 4.5),
        .65,
        Paint()..color = ink(0xFF5E827C),
      );
    }
    // Hinge caps and deck have separate highlights, providing readable depth.
    for (final x in [-115.0, 80.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 1, 35, 5),
          const Radius.circular(2),
        ),
        Paint()..color = ink(0xFF262827),
      );
    }
    final deck = Path()
      ..moveTo(-154, 8)
      ..lineTo(154, 8)
      ..lineTo(186, 78)
      ..lineTo(-186, 78)
      ..close();
    canvas.drawPath(
      deck,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ink(0xFF777C78), ink(0xFFB7BBB4), ink(0xFF717773)],
        ).createShader(const Rect.fromLTWH(-186, 8, 372, 70)),
    );
    final lip = Path()
      ..moveTo(-186, 78)
      ..lineTo(186, 78)
      ..lineTo(181, 83)
      ..lineTo(-181, 83)
      ..close();
    canvas.drawPath(lip, Paint()..color = ink(0xFF414743));
    canvas.drawLine(
      const Offset(-184, 78),
      const Offset(184, 78),
      Paint()
        ..strokeWidth = 1
        ..color = ink(0xFFD8D9CD),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-18, 77, 36, 3),
        const Radius.circular(1.5),
      ),
      Paint()..color = ink(0xFF606560),
    );

    // Tapered keyboard rows, keycap highlights and legends stay inexpensive.
    for (var row = 0; row < 5; row++) {
      final spread = 1 + row * .035;
      for (var column = 0; column < 12; column++) {
        final key = Rect.fromLTWH(
          (-116 + column * 19.6) * spread,
          13 + row * 6.5,
          16.5 * spread,
          4.5,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(key, const Radius.circular(1)),
          Paint()..color = ink(0xFF1C211F),
        );
        canvas.drawLine(
          key.topLeft + const Offset(1, .6),
          key.topRight - const Offset(1, -.6),
          Paint()
            ..strokeWidth = .5
            ..color = ink(0xFF5F6964),
        );
        if (row > 0 && column > 0 && column < 11) {
          canvas.drawLine(
            key.centerLeft + const Offset(3, 0),
            key.centerLeft + const Offset(5, 0),
            Paint()
              ..strokeWidth = .6
              ..color = ink(0xFFBDC7BC),
          );
        }
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-42, 47, 84, 4),
        const Radius.circular(1),
      ),
      Paint()..color = ink(0xFF202621),
    );
    final trackpad = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-42, 56, 84, 17),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(trackpad, Paint()..color = ink(0xFF9FA79F));
    canvas.drawRRect(
      trackpad,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .65
        ..color = ink(0xFF5B665E),
    );
    for (final side in [-1.0, 1.0]) {
      for (var row = 0; row < 12; row++) {
        canvas.drawLine(
          Offset(side * 143, 15 + row * 3.2),
          Offset(side * 149, 15 + row * 3.2),
          Paint()
            ..strokeWidth = .7
            ..color = ink(0xFF59665B),
        );
      }
    }
  }

  static void _portal(
    Canvas canvas,
    Rect rect,
    double opacity,
    List<ui.Image?> photos,
  ) {
    canvas.save();
    canvas.translate(rect.left, rect.top);
    canvas.scale(rect.width / 290, rect.height / 180);
    Color color(Color value) => value.withValues(alpha: value.a * opacity);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 290, 180),
      Paint()..color = color(CreoColors.appBase),
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 60, 180),
      Paint()..color = color(CreoColors.appSurface),
    );
    _label(canvas, 'creo.', const Offset(9, 12), 15, color(CreoColors.appInk));
    const sections = ['Overview', 'My batches', 'Brand DNA', 'Files'];
    for (var i = 0; i < sections.length; i++) {
      if (i == 1) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5, 53, 50, 16),
            const Radius.circular(3),
          ),
          Paint()..color = color(CreoColors.accent.withValues(alpha: .2)),
        );
      }
      _label(
        canvas,
        sections[i],
        Offset(10, 39 + i * 21),
        6.5,
        color(i == 1 ? CreoColors.accent : CreoColors.appMist),
      );
    }
    _label(
      canvas,
      'Batch 04',
      const Offset(70, 12),
      12,
      color(CreoColors.appInk),
    );
    _label(
      canvas,
      'Active review',
      const Offset(70, 28),
      7,
      color(CreoColors.appMist),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(70, 44, 210, 3),
        const Radius.circular(1.5),
      ),
      Paint()..color = color(CreoColors.appLine),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(70, 44, 70, 3),
        const Radius.circular(1.5),
      ),
      Paint()..color = color(CreoColors.accent),
    );
    const titles = ['Brand launch', 'Product feature', 'Serum launch'];
    for (var i = 0; i < 3; i++) {
      final tile = Rect.fromLTWH(70 + i * 72, 58, 65, 104);
      canvas.drawRRect(
        RRect.fromRectAndRadius(tile, const Radius.circular(4)),
        Paint()..color = color(CreoColors.appSurface),
      );
      final preview = Rect.fromLTWH(tile.left + 4, 62, 57, 57);
      canvas.drawRRect(
        RRect.fromRectAndRadius(preview, const Radius.circular(2)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color(CreoColors.accent), color(const Color(0xFF554A43))],
          ).createShader(preview),
      );
      // Product/story artwork is an illustration within this decorative demo,
      // never a screenshot of private customer content or a functional portal.
      final photo = i < photos.length ? photos[i] : null;
      if (photo != null) {
        canvas.save();
        canvas.clipRRect(
          RRect.fromRectAndRadius(preview, const Radius.circular(2)),
        );
        final input = Size(photo.width.toDouble(), photo.height.toDouble());
        final fit = applyBoxFit(BoxFit.cover, input, preview.size);
        canvas.drawImageRect(
          photo,
          Alignment.center.inscribe(fit.source, Offset.zero & input),
          preview,
          Paint()
            ..filterQuality = FilterQuality.medium
            ..color = Colors.white.withValues(alpha: opacity),
        );
        canvas.restore();
      } else if (i == 2) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: preview.center, width: 16, height: 30),
            const Radius.circular(3),
          ),
          Paint()..color = color(CreoColors.appInk),
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: preview.center.translate(0, -18),
            width: 9,
            height: 6,
          ),
          Paint()..color = color(CreoColors.appVoid),
        );
      } else {
        canvas.drawCircle(
          preview.center,
          16,
          Paint()
            ..color = color(CreoColors.appInk.withValues(alpha: .75 * opacity)),
        );
        canvas.drawLine(
          preview.topLeft + const Offset(6, 46),
          preview.topRight + const Offset(-6, 12),
          Paint()
            ..strokeWidth = 5
            ..color = color(CreoColors.appBase),
        );
      }
      _label(
        canvas,
        titles[i],
        Offset(tile.left + 4, 125),
        6,
        color(CreoColors.appInk),
      );
      _label(
        canvas,
        i == 2 ? 'Approved' : 'Awaiting review',
        Offset(tile.left + 4, 136),
        5.5,
        color(CreoColors.appMist),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(tile.left + 4, 148, 57, 9),
          const Radius.circular(4),
        ),
        Paint()..color = color(CreoColors.accent),
      );
      _label(
        canvas,
        i == 2 ? 'Queued' : 'Approve',
        Offset(tile.left + 18, 150),
        5,
        color(CreoColors.onAccent),
      );
    }
    canvas.restore();
  }

  static void _label(
    Canvas canvas,
    String label,
    Offset at,
    double size,
    Color color,
  ) {
    (TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: size,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout()).paint(canvas, at);
  }

  @override
  bool shouldRepaint(LandingHeroPainter oldDelegate) =>
      oldDelegate.frame.progress != frame.progress ||
      !listEquals(oldDelegate.photos, photos);
}

enum LandingProp { blocks, mailbox, megaphone, device }

/// Scene slots are driven by their own pass across the viewport, like stage.ts.
class LandingScene extends StatefulWidget {
  const LandingScene({
    super.key,
    required this.scroll,
    required this.kind,
    this.height = 280,
  });
  final ScrollController scroll;
  final LandingProp kind;
  final double height;
  @override
  State<LandingScene> createState() => _LandingSceneState();
}

class _LandingSceneState extends State<LandingScene> {
  double _pass = 0;
  bool _scheduled = false;
  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_measure);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _measure();
  }

  void _measure() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final viewport = MediaQuery.sizeOf(context).height;
      final p =
          ((viewport - box.localToGlobal(Offset.zero).dy) /
                  (viewport + box.size.height))
              .clamp(0.0, 1.0);
      if (p != _pass) setState(() => _pass = p);
    });
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_measure);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: widget.height,
      width: double.infinity,
      child: CustomPaint(
        painter: _LandingPropPainter(
          widget.kind,
          MediaQuery.disableAnimationsOf(context) ? .65 : _pass,
          context.creo,
        ),
      ),
    ),
  );
}

class _LandingPropPainter extends CustomPainter {
  const _LandingPropPainter(this.kind, this.pass, this.palette);
  final LandingProp kind;
  final double pass;
  final CreoPalette palette;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(math.min(size.width / 340, size.height / 240));
    final ivory = Paint()..color = palette.appInk;
    final amber = Paint()..color = palette.accent;
    final dark = Paint()..color = palette.appSurface;
    if (kind == LandingProp.blocks) {
      final p = _smooth(.12, .8, pass);
      final burst = _smooth(.75, .925, p);
      canvas.rotate(p * .7 - .35);
      if (burst < .999) {
        for (var i = 0; i < 8; i++) {
          final x = (i % 2 - .5) * (56 + 140 * (1 - _smooth(0, .2375, p)));
          final y =
              ((i ~/ 2) % 2 - .5) * (56 + 120 * (1 - _smooth(0, .2375, p)));
          canvas.save();
          canvas.translate(x, y);
          canvas.scale(1 - burst * .9);
          final top = i < 4;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                -25 + (top ? 0 : 12),
                -25 + (top ? 0 : -12),
                50,
                50,
              ),
              const Radius.circular(7),
            ),
            Paint()
              ..color = Color.lerp(
                palette.appInk,
                palette.accent,
                _smooth(.5, .675, p),
              )!.withValues(alpha: top ? 1 : .4),
          );
          canvas.restore();
        }
      }
      if (burst > 0) {
        for (var i = 0; i < 7; i++) {
          final angle = i * math.pi * 2 / 7;
          final center = Offset(
            math.cos(angle) * 100 * burst,
            math.sin(angle) * 65 * burst,
          );
          canvas.drawOval(
            Rect.fromCenter(center: center, width: 43, height: 27),
            amber,
          );
          canvas.drawOval(
            Rect.fromCenter(center: center, width: 34, height: 20),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = palette.onAccent,
          );
        }
      }
    } else if (kind == LandingProp.mailbox) {
      canvas.restore();
      MailboxPerspectivePainter(
        frame: MailboxSceneFrame(pass),
        palette: palette,
      ).paint(canvas, size);
      return;
    } else if (kind == LandingProp.megaphone) {
      canvas.rotate(.12 + (pass - .5) * .25);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-58, 30, 24, 63),
          const Radius.circular(8),
        ),
        amber,
      );
      final cone = Path()
        ..moveTo(-70, -25)
        ..lineTo(70, -76)
        ..lineTo(70, 68)
        ..lineTo(-70, 23)
        ..close();
      canvas.drawPath(cone, ivory);
      canvas.drawOval(const Rect.fromLTWH(43, -76, 55, 144), amber);
      canvas.drawOval(const Rect.fromLTWH(52, -62, 35, 116), dark);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-95, -28, 32, 58),
          const Radius.circular(10),
        ),
        amber,
      );
    } else {
      canvas.translate(0, 38 * (1 - _smooth(.05, .8, pass)));
      canvas.rotate(-.06 + .12 * pass);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-57, -103, 114, 216),
          const Radius.circular(19),
        ),
        dark,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-50, -94, 100, 198),
          const Radius.circular(13),
        ),
        ivory,
      );
      LandingHeroPainter._label(
        canvas,
        'creo.',
        const Offset(-38, -72),
        23,
        palette.onAccent,
      );
      LandingHeroPainter._label(
        canvas,
        'Your weekly batch',
        const Offset(-38, -29),
        11,
        palette.onAccent,
      );
      for (var i = 0; i < 3; i++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-38, i * 31.0 - 7, 76, 23),
            const Radius.circular(5),
          ),
          amber,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LandingPropPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.pass != pass ||
      oldDelegate.palette.lightness != palette.lightness;
}
