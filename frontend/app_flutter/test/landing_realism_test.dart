import 'dart:async';
import 'dart:ui' as ui;

import 'package:app_flutter/src/core/app_theme.dart';
import 'package:app_flutter/src/features/landing/landing_mailbox_3d.dart';
import 'package:app_flutter/src/features/landing/landing_motion.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class DelayedPhoto extends ImageProvider<DelayedPhoto> {
  final result = Completer<ImageInfo>();
  int loads = 0;
  @override
  Future<DelayedPhoto> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    DelayedPhoto key,
    ImageDecoderCallback decode,
  ) {
    loads++;
    return OneFrameImageStreamCompleter(result.future);
  }
}

Widget host(
  Widget child, {
  bool reduced = false,
  Brightness brightness = Brightness.dark,
}) => MaterialApp(
  theme: buildCreoTheme(brightness: brightness),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: child,
    ),
  ),
);

LandingHeroPainter heroPainter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find
                  .descendant(
                    of: find.byType(LandingHero),
                    matching: find.byType(CustomPaint),
                  )
                  .first,
            )
            .painter!
        as LandingHeroPainter;

Future<ui.Image> makeImage() async {
  final recorder = ui.PictureRecorder();
  Canvas(
    recorder,
  ).drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = Colors.amber);
  final picture = recorder.endRecording();
  final image = await picture.toImage(8, 8);
  picture.dispose();
  return image;
}

void main() {
  test('React sequence raises flag before door and depth release', () {
    expect(const MailboxSceneFrame(.15).cycle, 0);
    final early = const MailboxSceneFrame(.38);
    expect(early.flag, greaterThan(early.door));
    expect(early.envelope, 0);
    final end = const MailboxSceneFrame(.7);
    expect(end.flag, 1);
    expect(end.door, 1);
    expect(end.envelope, 1);
    expect(end.doorAngle, 1.45);
    expect(const MailboxSceneFrame(.38).door, early.door);
  });

  for (final brightness in Brightness.values) {
    testWidgets('perspective mesh paints and reverses $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(280, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final pass in [0.0, .2, .38, .48, .56, .7, 1.0, .56, .38, 0.0]) {
        await tester.pumpWidget(
          host(
            CustomPaint(
              painter: MailboxPerspectivePainter(
                frame: MailboxSceneFrame(pass),
                palette: CreoPalette(
                  lightness: brightness == Brightness.light ? 1 : 0,
                ),
              ),
              child: const SizedBox.expand(),
            ),
            brightness: brightness,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'mesh pass=$pass');
      }
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);
    });
  }

  testWidgets(
    'image streams are reused across scroll, fail safely and reject late replacement',
    (tester) async {
      final first = List.generate(3, (_) => DelayedPhoto());
      final second = List.generate(3, (_) => DelayedPhoto());
      final image = await tester.runAsync(makeImage);
      for (final progress in [.2, .4, .58, .7, .4]) {
        await tester.pumpWidget(
          host(
            LandingHero(
              progress: progress,
              onContinue: () {},
              imageProviders: first,
            ),
          ),
        );
        await tester.pump();
      }
      expect(first.map((provider) => provider.loads), [1, 1, 1]);
      await tester.pumpWidget(
        host(
          LandingHero(progress: .58, onContinue: () {}, imageProviders: second),
        ),
      );
      for (final old in first) {
        old.result.complete(ImageInfo(image: image!.clone()));
      }
      await tester.pump();
      expect(heroPainter(tester).photos.whereType<ui.Image>(), isEmpty);
      second[0].result.complete(ImageInfo(image: image!.clone()));
      second[1].result.completeError(StateError('fixture decode failure'));
      await tester.pump();
      await tester.pump();
      expect(heroPainter(tester).photos.whereType<ui.Image>().length, 1);
      await tester.pumpWidget(const SizedBox());
      second[2].result.complete(ImageInfo(image: image.clone()));
      await tester.pump();
      expect(tester.takeException(), isNull);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      image.dispose();
    },
  );

  testWidgets('reduced motion does not start decorative photo decoding', (
    tester,
  ) async {
    final providers = List.generate(3, (_) => DelayedPhoto());
    await tester.pumpWidget(
      host(
        LandingHero(progress: .4, onContinue: () {}, imageProviders: providers),
        reduced: true,
      ),
    );
    await tester.pump();
    expect(providers.map((provider) => provider.loads), [0, 0, 0]);
    expect(heroPainter(tester).frame.progress, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'bundled pictures decode once and remain present on scroll reversal',
    (tester) async {
      await tester.pumpWidget(
        host(LandingHero(progress: .58, onContinue: () {})),
      );
      for (
        var attempt = 0;
        attempt < 60 &&
            heroPainter(tester).photos.whereType<ui.Image>().length < 3;
        attempt++
      ) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();
      }
      final images = heroPainter(tester).photos;
      expect(images.whereType<ui.Image>().length, 3);
      expect(
        images.every((image) => image!.width <= 512 && image.height <= 512),
        true,
      );
      await tester.pumpWidget(
        host(LandingHero(progress: .25, onContinue: () {})),
      );
      await tester.pump();
      expect(heroPainter(tester).photos, images);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
