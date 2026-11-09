import 'package:app_flutter/src/core/app_theme.dart';
import 'package:app_flutter/src/features/landing/landing_motion.dart';
import 'package:app_flutter/src/features/landing/landing_page.dart';
import 'package:app_flutter/src/features/landing/landing_portal_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget shell(Widget child, {bool reduced = false, double scale = 1}) =>
    MaterialApp(
      theme: buildCreoTheme(),
      routes: {
        '/login': (_) => const Scaffold(body: Text('Sign-in test boundary')),
        '/signup': (_) => const Scaffold(body: Text('Sign-up test boundary')),
      },
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(scale),
          ),
          child: child,
        ),
      ),
    );

Future<void> viewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  // Viewport measurement is post-frame; establish the newly started ticker's
  // first frame before advancing its elapsed animation time.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pump();
}

void main() {
  test(
    'hero uses actual scroll ranges, exponential dot and opening/dive stages',
    () {
      expect(const LandingHeroFrame(0).dotScale, 1);
      expect(const LandingHeroFrame(.12).dotScale, closeTo(170, .00001));
      expect(const LandingHeroFrame(.045).glyphOpacity, 0);
      expect(const LandingHeroFrame(.165).introOpacity, 0);
      expect(const LandingHeroFrame(.34).open, 0);
      expect(const LandingHeroFrame(.58).open, 1);
      expect(const LandingHeroFrame(.6).dive, 0);
      expect(const LandingHeroFrame(.82).dive, 1);
      expect(const LandingHeroFrame(.88).subtitle, 0);
      expect(const LandingHeroFrame(.95).subtitle, 1);
      expect(const LandingHeroFrame(.76).screenDim, 0);
      expect(const LandingHeroFrame(.85).screenDim, 1);
      expect(const LandingHeroFrame(.9).propsVisible, false);
    },
  );

  testWidgets('detailed laptop paints closed, opening, open and dive frames', (
    tester,
  ) async {
    await viewport(tester, const Size(320, 740));
    for (final progress in [.08, .17, .34, .46, .58, .7, .8, .85]) {
      await tester.pumpWidget(
        shell(
          CustomPaint(
            painter: LandingHeroPainter(LandingHeroFrame(progress)),
            size: const Size(320, 740),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'laptop progress=$progress',
      );
    }
  });

  testWidgets('hero scrubs forward/back and elapsed time cannot restart it', (
    tester,
  ) async {
    await viewport(tester, const Size(393, 852));
    await tester.pumpWidget(shell(const LandingPage()));
    await settle(tester);
    final scroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final header = tester.widget<SliverPersistentHeader>(
      find.byType(SliverPersistentHeader),
    );
    final delegate = header.delegate as LandingHeroDelegate;
    final heroStart = tester.getTopLeft(find.byType(LandingHero)).dy;
    scroll.jumpTo(heroStart + (delegate.maxExtent - delegate.minExtent) * .5);
    await tester.pump();
    expect(
      tester.widget<LandingHero>(find.byType(LandingHero)).progress,
      closeTo(.5, .001),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(
      tester.widget<LandingHero>(find.byType(LandingHero)).progress,
      closeTo(.5, .001),
    );
    scroll.jumpTo(heroStart);
    await tester.pump();
    expect(
      tester.widget<LandingHero>(find.byType(LandingHero)).progress,
      closeTo(0, .001),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets(
    'viewport reveal plays once and stays finished on reverse scroll',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await viewport(tester, const Size(393, 852));
      await tester.pumpWidget(
        shell(
          SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: [
                const SizedBox(height: 1100),
                LandingReveal(scroll: scroll, child: const Text('Once reveal')),
                const SizedBox(height: 1100),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final opacityFinder = find.descendant(
        of: find.byType(LandingReveal),
        matching: find.byType(Opacity),
      );
      expect(tester.widget<Opacity>(opacityFinder).opacity, 0);
      scroll.jumpTo(800);
      await settle(tester);
      expect(tester.widget<Opacity>(opacityFinder).opacity, 1);
      scroll.jumpTo(0);
      await tester.pump();
      scroll.jumpTo(800);
      await tester.pump();
      expect(tester.widget<Opacity>(opacityFinder).opacity, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'role transition coalesces rapid choices and reduced motion interrupts',
    (tester) async {
      var role = 'one';
      var reduced = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MediaQuery(
                data: MediaQueryData(disableAnimations: reduced),
                child: LandingRoleDescription(
                  role: role,
                  description: '$role description',
                ),
              );
            },
          ),
        ),
      );
      update(() => role = 'two');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      update(() => role = 'three');
      await tester.pump();
      update(() => reduced = true);
      await tester.pump();
      expect(find.text('three description'), findsOneWidget);
      expect(
        tester
            .widget<Opacity>(
              find.descendant(
                of: find.byType(LandingRoleDescription),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        1,
      );
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets(
    'portal demo approves requests changes and undoes without API calls',
    (tester) async {
      await viewport(tester, const Size(393, 852));
      await tester.pumpWidget(
        shell(
          const SingleChildScrollView(child: LandingPortalDemo()),
          reduced: true,
        ),
      );
      expect(
        find.text('1 of 3 approved • On track: 2 days early'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('approve-0')));
      await tester.tap(find.byKey(const ValueKey('approve-0')));
      await settle(tester);
      expect(
        find.text('2 of 3 approved • On track: 2 days early'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('undo-0')));
      await tester.tap(find.byKey(const ValueKey('undo-0')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('change-0')));
      await settle(tester);
      expect(find.text('Revision requested'), findsOneWidget);
      expect(
        find.text('1 of 3 approved • On track: 2 days early'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 740),
    const Size(393, 852),
    const Size(852, 393),
  ]) {
    for (final reduced in [false, true]) {
      testWidgets('landing responsive $size reduced=$reduced at 200% text', (
        tester,
      ) async {
        await viewport(tester, size);
        // MediaQueryData here intentionally carries the concrete viewport too.
        await tester.pumpWidget(
          MaterialApp(
            theme: buildCreoTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2),
                disableAnimations: reduced,
              ),
              child: const LandingPage(),
            ),
          ),
        );
        await settle(tester);
        if (!reduced) {
          final cue = tester.getRect(find.textContaining('Scroll to dive in'));
          expect(cue.top, greaterThanOrEqualTo(0));
          expect(cue.bottom, lessThanOrEqualTo(size.height));
        }
        final scroll = tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .controller!;
        // Visit every section, including both directions and the headline stage.
        for (
          double offset = 0;
          offset < scroll.position.maxScrollExtent;
          offset += size.height * .7
        ) {
          scroll.jumpTo(offset);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 900));
          expect(tester.takeException(), isNull, reason: 'offset=$offset');
        }
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await settle(tester);
        expect(tester.takeException(), isNull);
        scroll.jumpTo(0);
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        await settle(tester);
      });
    }
  }

  for (final reduced in [false, true]) {
    testWidgets('FAQ repeated toggles remain safe reduced=$reduced', (
      tester,
    ) async {
      await viewport(tester, const Size(393, 852));
      await tester.pumpWidget(shell(const LandingPage(), reduced: reduced));
      await settle(tester);
      final toggle = find.byKey(const ValueKey('faq-toggle-0'));
      await tester.scrollUntilVisible(
        toggle,
        500,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
        maxScrolls: 80,
      );
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      final header = tester.getRect(
        find.byKey(const ValueKey('landing-navigation')),
      );
      scroll.jumpTo(
        (scroll.offset - header.height - 24).clamp(
          0,
          scroll.position.maxScrollExtent,
        ),
      );
      await settle(tester);
      for (var i = 0; i < 3; i++) {
        await tester.tap(toggle);
        await tester.pump(const Duration(milliseconds: 80));
      }
      await settle(tester);
      expect(
        tester
            .widget<AnimatedRotation>(
              find.descendant(
                of: toggle,
                matching: find.byType(AnimatedRotation),
              ),
            )
            .turns,
        0,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Pricing anchor leaves heading below wrapped header at ${scale * 100}%',
      (tester) async {
        await viewport(tester, const Size(393, 852));
        await tester.pumpWidget(shell(const LandingPage(), scale: scale));
        await settle(tester);
        await tester.tap(find.text('Pricing'));
        await settle(tester);
        final header = tester.getRect(
          find.byKey(const ValueKey('landing-navigation')),
        );
        final heading = tester.getRect(find.text('TIERS & TURNAROUND'));
        final scroll = tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .controller!;
        expect(scroll.offset, greaterThan(852 * 3.6));
        expect(heading.top, greaterThanOrEqualTo(header.bottom - 1));
        expect(heading.top, lessThan(852));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await settle(tester);
      },
    );
  }

  testWidgets(
    'auth named destinations preserve pop and rapid tap does not duplicate',
    (tester) async {
      await viewport(tester, const Size(393, 852));
      await tester.pumpWidget(shell(const LandingPage(), reduced: true));
      await settle(tester);
      await tester.tap(find.text('Sign in'));
      await tester.tap(find.text('Sign in'), warnIfMissed: false);
      await settle(tester);
      expect(find.text('Sign-in test boundary'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await settle(tester);
      expect(find.text('Sign in'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    },
  );
}
