import 'package:app_flutter/src/core/app_theme.dart';
import 'package:app_flutter/src/features/landing/landing_deliverables.dart';
import 'package:app_flutter/src/features/landing/landing_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'formats stay readable and switch safely $brightness scale=$scale',
        (tester) async {
          tester.view.physicalSize = const Size(280, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var selected = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: buildCreoTheme(brightness: brightness),
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: scale == 2,
                  ),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      child: StatefulBuilder(
                        builder: (context, update) => LandingDeliverables(
                          selectedIndex: selected,
                          onSelected: (index) => update(() => selected = index),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final index in [1, 2, 3, 0, 3]) {
            final chip = find.byKey(ValueKey('delivery-format-$index'));
            await Scrollable.ensureVisible(tester.element(chip), alignment: .5);
            await tester.pump();
            await tester.tap(chip);
            await tester.pump(const Duration(milliseconds: 45));
            expect(tester.widget<ChoiceChip>(chip).selected, true);
          }
          await tester.pumpAndSettle();
          expect(find.text('UGC Direct Response Ad'), findsOneWidget);
          expect(
            find.text('Tested Split Variant • Bold Subtitles'),
            findsOneWidget,
          );
          await tester.ensureVisible(find.text('Illustrative format preview'));
          await tester.pumpAndSettle();
          expect(find.text('Illustrative format preview'), findsOneWidget);
          expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );

      testWidgets(
        'mailbox scrolls forward and back without looping $brightness reduced=${scale == 2}',
        (tester) async {
          tester.view.physicalSize = const Size(280, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final scroll = ScrollController();
          await tester.pumpWidget(
            MaterialApp(
              theme: buildCreoTheme(brightness: brightness),
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: scale == 2),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      controller: scroll,
                      child: Column(
                        children: [
                          const SizedBox(height: 380),
                          LandingScene(
                            scroll: scroll,
                            kind: LandingProp.mailbox,
                          ),
                          const SizedBox(height: 600),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          for (final offset in [0.0, 150.0, 300.0, 500.0, 250.0, 0.0]) {
            scroll.jumpTo(offset);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 20));
            expect(
              tester.takeException(),
              isNull,
              reason: 'mailbox offset=$offset',
            );
          }
          await tester.pump(const Duration(seconds: 2));
          expect(tester.binding.transientCallbackCount, 0);
          await tester.pumpWidget(const SizedBox());
          scroll.dispose();
        },
      );
    }
  }
}
