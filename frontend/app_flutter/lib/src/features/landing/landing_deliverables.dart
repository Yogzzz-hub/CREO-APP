import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

const _formats = ['Reels', 'Carousels', 'Stories', 'Meta Ads'];
const _icons = [
  Icons.movie_outlined,
  Icons.view_carousel_outlined,
  Icons.auto_awesome_motion_outlined,
  Icons.campaign_outlined,
];
const _titles = [
  'High-Hook Kinetic Cut',
  'Swipe Anatomy Carousel',
  'Interactive Drop Sequence',
  'UGC Direct Response Ad',
];
const _descriptions = [
  '0:15 Dynamic Pacing • Custom Sound Design',
  '7-Slide Framework • High Retention',
  'Animated Countdown & Sticker Placement',
  'Tested Split Variant • Bold Subtitles',
];

/// Existing format selection, presented as an explicitly illustrative preview.
class LandingDeliverables extends StatelessWidget {
  const LandingDeliverables({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.creo;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'DELIVERABLES',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: colors.accent,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Formats shipped weekly',
            style: TextStyle(
              fontSize: 28,
              height: 1.12,
              letterSpacing: -.8,
              fontWeight: FontWeight.w700,
              color: colors.appInk,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: List.generate(_formats.length, (index) {
              final selected = selectedIndex == index;
              return ChoiceChip(
                key: ValueKey('delivery-format-$index'),
                avatar: Icon(
                  _icons[index],
                  size: 18,
                  color: selected ? colors.onAccent : colors.appMist,
                ),
                label: Text(_formats[index]),
                selected: selected,
                onSelected: (_) => onSelected(index),
                showCheckmark: false,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                selectedColor: colors.accent,
                backgroundColor: colors.appSurface,
                labelStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: selected ? colors.onAccent : colors.appInk,
                ),
                shape: const StadiumBorder(),
                side: BorderSide(
                  color: selected ? colors.accent : colors.appLine,
                ),
              );
            }),
          ),
          const SizedBox(height: 22),
          Container(
            key: const ValueKey('delivery-preview'),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.appSurface, colors.appBento],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.appLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text(
                        'FORMAT PREVIEW',
                        style: TextStyle(
                          fontSize: 14,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                          color: colors.appMist,
                        ),
                      ),
                      Text(
                        _formats[selectedIndex],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                // The art is decorative and does not imply playable video or a
                // private customer asset. Only format selection is interactive.
                ExcludeSemantics(
                  child: AspectRatio(
                    aspectRatio: 1.8,
                    child: AnimatedSwitcher(
                      duration: reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, .045),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: CustomPaint(
                        key: ValueKey(selectedIndex),
                        painter: _FormatArtwork(selectedIndex, colors),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _titles[selectedIndex],
                          key: const ValueKey('delivery-title'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            color: colors.appInk,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _descriptions[selectedIndex],
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.55,
                          color: colors.appMist,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Divider(height: 1, color: colors.appLine),
                      const SizedBox(height: 14),
                      Text(
                        'Illustrative format preview',
                        style: TextStyle(fontSize: 14, color: colors.appMist),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatArtwork extends CustomPainter {
  const _FormatArtwork(this.index, this.colors);
  final int index;
  final CreoPalette colors;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    final scale = math.min(size.width / 320, size.height / 180);
    canvas.scale(scale);
    final glow = const Rect.fromLTWH(-140, -75, 280, 150);
    canvas.drawOval(
      glow,
      Paint()
        ..shader = RadialGradient(
          colors: [
            colors.accent.withValues(alpha: .12),
            colors.accent.withValues(alpha: 0),
          ],
        ).createShader(glow),
    );
    final count = index == 1
        ? 3
        : index == 2
        ? 3
        : 1;
    for (var i = 0; i < count; i++) {
      canvas.save();
      final x = index == 1
          ? (i - 1) * 73.0
          : index == 2
          ? (i - 1) * 49.0
          : 0.0;
      canvas.translate(x, i == 1 ? -3 : 4);
      canvas.rotate(
        index == 2
            ? (i - 1) * .12
            : index == 1
            ? (i - 1) * .04
            : -.055,
      );
      final card = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: index == 1 ? 77 : 100,
          height: 133,
        ),
        const Radius.circular(12),
      );
      canvas.drawRRect(
        card.shift(const Offset(3, 7)),
        Paint()
          ..color = Colors.black.withValues(
            alpha: colors.lightness > .5 ? .09 : .22,
          ),
      );
      canvas.drawRRect(
        card,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(colors.accent, colors.appInk, .13)!,
              Color.lerp(colors.accent, colors.appBase, .32)!,
            ],
          ).createShader(card.outerRect),
      );
      canvas.drawRRect(
        card.deflate(.8),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = colors.appInk.withValues(alpha: .25),
      );
      canvas.save();
      canvas.clipRRect(card);
      canvas.drawCircle(
        const Offset(28, -32),
        46,
        Paint()..color = colors.onAccent.withValues(alpha: .14),
      );
      canvas.drawCircle(
        const Offset(-37, 45),
        44,
        Paint()..color = colors.onAccent.withValues(alpha: .09),
      );
      if (index == 0) {
        for (var bar = 0; bar < 7; bar++) {
          final height = [12.0, 27.0, 38.0, 51.0, 35.0, 24.0, 14.0][bar];
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(-30 + bar * 9, -height / 2, 5, height),
              const Radius.circular(3),
            ),
            Paint()..color = colors.onAccent.withValues(alpha: .8),
          );
        }
      } else if (index == 1) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-25, -35, 50, 50),
            const Radius.circular(6),
          ),
          Paint()..color = colors.onAccent.withValues(alpha: .18),
        );
        canvas.drawCircle(
          Offset((i - 1) * 7.0, -10),
          15,
          Paint()..color = colors.onAccent.withValues(alpha: .55),
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-14, -31, 28, 52),
            const Radius.circular(7),
          ),
          Paint()..color = colors.onAccent.withValues(alpha: .85),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-8, -39, 16, 10),
            const Radius.circular(2),
          ),
          Paint()..color = colors.appBase.withValues(alpha: .8),
        );
        canvas.drawRect(
          const Rect.fromLTWH(-9, -10, 18, 11),
          Paint()..color = colors.accent.withValues(alpha: .4),
        );
      }
      for (var line = 0; line < 2; line++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-30, 37 + line * 9, line == 0 ? 60 : 40, 4),
            const Radius.circular(2),
          ),
          Paint()
            ..color = colors.onAccent.withValues(alpha: line == 0 ? .9 : .45),
        );
      }
      canvas.restore();
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FormatArtwork oldDelegate) =>
      oldDelegate.index != index ||
      oldDelegate.colors.lightness != colors.lightness;
}
