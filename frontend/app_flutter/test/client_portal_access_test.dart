import 'dart:io';
import 'dart:ui' as ui;
import 'package:app_flutter/main.dart';
import 'package:app_flutter/src/features/portal/client_portal_access.dart';
import 'package:app_flutter/src/features/portal/client_portal_screen.dart';
import 'package:app_flutter/src/features/portal/client_portal_setup_shell.dart';
import 'package:app_flutter/src/features/portal/screens/main_shell_screen.dart';
import 'package:app_flutter/src/features/portal/widgets/creo_bottom_nav.dart';
import 'package:app_flutter/src/features/onboarding/client_onboarding_page.dart';
import 'package:app_flutter/src/core/app_appearance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'session_lifecycle_test.dart' show jsonResponse;
import 'workstation_hub_test.dart' show hubOwner;

/// Explicit server fixtures for tests whose clients have completed setup.
http.Response? readyPortalResponse(http.Request request) {
  if (request.method != 'GET') return null;
  if (request.url.path == '/api/v1/onboarding/status') {
    return jsonResponse({
      'stage': 8,
      'is_complete': true,
      'next_required_stage': 'portal',
    });
  }
  if (request.url.path == '/api/v1/payments/subscription') {
    return jsonResponse({
      'is_active': true,
      'is_expired': false,
      'subscription': {'status': 'active'},
    });
  }
  return null;
}

Future<void> advance(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  test(
    'workspace requires verified email, completed setup and confirmed subscription',
    () {
      for (var stage = 0; stage <= 8; stage++) {
        for (final paid in [false, true]) {
          final access = ClientPortalAccess.fromJson(
            {'stage': stage, 'is_complete': stage == 8},
            subscription: {
              'is_active': paid,
              'subscription': {'status': paid ? 'active' : 'incomplete'},
            },
          );
          expect(access.canUseWorkspace, stage == 8 && paid);
        }
      }
    },
  );

  test('expired and explicitly inactive subscriptions remain locked', () {
    for (final subscription in [
      {
        'is_active': true,
        'is_expired': true,
        'subscription': {'status': 'active'},
      },
      {
        'is_active': false,
        'subscription': {'status': 'active'},
      },
      {
        'is_active': true,
        'subscription': {'status': 'past_due'},
      },
    ]) {
      expect(
        ClientPortalAccess.fromJson({
          'stage': 8,
          'is_complete': true,
        }, subscription: subscription).canUseWorkspace,
        isFalse,
      );
    }
    expect(
      () => ClientPortalAccess.fromJson({'stage': 8, 'is_complete': true}),
      throwsFormatException,
    );
    expect(
      () => ClientPortalAccess.fromJson({'items': []}),
      throwsFormatException,
    );
  });

  for (final stage in [0, 1, 2, 3, 7, 8]) {
    testWidgets(
      'client stage $stage follows verified portal and setup boundaries',
      (tester) async {
        final paths = <String>[];
        final session = await hubOwner((request) async {
          paths.add(request.url.path);
          if (request.url.path == '/api/v1/onboarding/status') {
            return jsonResponse({
              'stage': stage,
              'is_complete': stage == 8,
              'stage_name': 'Saved setup progress',
              'next_required_stage': stage == 0
                  ? 'verify'
                  : stage == 1
                  ? 'terms'
                  : stage == 2
                  ? 'payment'
                  : stage == 3
                  ? 'questionnaire'
                  : stage == 7
                  ? 'complete'
                  : 'portal',
            });
          }
          if (request.url.path == '/api/v1/payments/subscription') {
            return jsonResponse({
              'is_active': true,
              'subscription': {'status': 'active'},
            });
          }
          return jsonResponse({'items': []});
        }, role: 'client');
        addTearDown(session.dispose);
        await tester.pumpWidget(
          MaterialApp(home: ClientPortalScreen(session: session)),
        );
        await advance(tester);
        if (stage == 0) {
          expect(find.byType(ClientOnboardingPage), findsOneWidget);
          expect(find.byType(ClientPortalSetupShell), findsNothing);
        } else if (stage < 8) {
          expect(find.text('Your Creo workspace'), findsOneWidget);
          expect(find.byType(ClientPortalSetupShell), findsOneWidget);
          final nav = find.byType(CreoBottomNavBar);
          await tester.tap(
            find.descendant(of: nav, matching: find.text('Review')),
          );
          await advance(tester);
          expect(find.text('Complete setup to unlock Review'), findsOneWidget);
          expect(paths.where((p) => p.startsWith('/api/v1/portal/')), isEmpty);
          if (stage == 1) {
            await tester.tap(find.text('Review service agreement'));
            await advance(tester);
            expect(find.byType(ClientOnboardingPage), findsOneWidget);
            await tester.scrollUntilVisible(
              find.text('Accept agreement'),
              500,
              scrollable: find.byType(Scrollable).first,
            );
            expect(find.text('Accept agreement'), findsOneWidget);
          }
        } else {
          expect(find.byType(MainShellScreen), findsOneWidget);
          expect(paths, contains('/api/v1/portal/dashboard'));
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'status failure retains the lock and retry unlocks only after server confirmation',
    (tester) async {
      var fail = true;
      var productionReads = 0;
      final session = await hubOwner((request) async {
        if (fail && request.url.path == '/api/v1/onboarding/status') {
          return jsonResponse({'detail': 'Unavailable'}, 503);
        }
        final access = readyPortalResponse(request);
        if (access != null) return access;
        productionReads++;
        return jsonResponse({'items': []});
      }, role: 'client');
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(home: ClientPortalScreen(session: session)),
      );
      await advance(tester);
      expect(productionReads, 0);
      expect(find.byType(MainShellScreen), findsNothing);
      fail = false;
      await tester.tap(find.text('Retry'));
      await advance(tester);
      expect(find.byType(MainShellScreen), findsOneWidget);
      expect(productionReads, greaterThan(0));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('email confirmation refresh opens the locked portal', (
    tester,
  ) async {
    var stage = 0;
    final session = await hubOwner((request) async {
      if (request.url.path == '/api/v1/onboarding/status') {
        return jsonResponse({
          'stage': stage,
          'is_complete': false,
          'next_required_stage': stage == 0 ? 'verify' : 'terms',
        });
      }
      return jsonResponse({});
    }, role: 'client');
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(home: ClientPortalScreen(session: session)),
    );
    await advance(tester);
    expect(find.byType(ClientOnboardingPage), findsOneWidget);
    stage = 1;
    await tester.tap(find.byTooltip('Refresh saved progress'));
    await advance(tester);
    expect(find.byType(ClientPortalSetupShell), findsOneWidget);
    expect(find.byType(MainShellScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'confirmed questionnaire completion restores the session and opens the working portal',
    (tester) async {
      var stage = 7;
      var completions = 0;
      final calls = <String>[];
      final session = await hubOwner((request) async {
        calls.add('${request.method} ${request.url.path} stage=$stage');
        if (request.url.path == '/api/v1/onboarding/status') {
          return jsonResponse({
            'stage': stage,
            'is_complete': stage == 8,
            'stage_name': 'Final setup',
            'next_required_stage': stage == 8 ? 'portal' : 'complete',
          });
        }
        if (request.url.path.endsWith('/questionnaire')) {
          return jsonResponse({
            'core_completed': true,
            'section_a': {
              'brand_name': 'Test brand',
              'one_liner': 'A clearly labeled test brand',
              'instagram_handle': '@testbrand',
              'category': 'other',
              'primary_goal': 'awareness',
              'products': [
                {'name': 'Test product'},
              ],
            },
            'section_b': {
              'ideal_customer': 'Test audience description',
              'problem': 'Test customer problem',
              'why_chosen': 'Test reason to choose us',
              'languages': ['english'],
              'caption_script': 'english',
            },
            'section_c': {
              'voice_words': ['warm', 'clear'],
              'anti_voice_words': ['aggressive'],
            },
            'section_d': {
              'brand_guidelines': 'yes',
              'colours': ['#112233'],
              'visual_direction': ['clean'],
            },
            'section_e': {
              'on_camera': ['founder'],
              'shoot_locations': ['studio'],
              'shoot_city': 'Test city',
              'cta_destination': 'website',
            },
          });
        }
        if (request.url.path.endsWith('/complete')) {
          expect(request.method, 'POST');
          completions++;
          stage = 8;
          return jsonResponse({'status': 'completed'});
        }
        final access = readyPortalResponse(request);
        return access ?? jsonResponse({'items': []});
      }, role: 'client');
      addTearDown(session.dispose);
      final appearance = CreoAppearance(
        read: () async => null,
        write: (_) async {},
      );
      addTearDown(appearance.dispose);
      await tester.pumpWidget(
        CreoApp(
          session: session,
          appearance: appearance,
          initialRoute: '/portal',
        ),
      );
      await advance(tester);
      expect(find.byType(ClientPortalSetupShell), findsOneWidget);
      await tester.tap(find.text('Finalize and launch workspace'));
      await advance(tester);
      await tester.scrollUntilVisible(
        find.text('Complete setup and allocate team'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Complete setup and allocate team'));
      await advance(tester);
      expect(completions, 1);
      expect(
        find.byType(MainShellScreen),
        findsOneWidget,
        reason:
            'calls=$calls phase=${session.phase}, issue=${session.issue?.code}, visible=${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).join(" | ")}',
      );
      expect(find.byType(ClientPortalSetupShell), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('locked portal fits 320px and 200% text in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = await hubOwner(
        (_) async => jsonResponse({'stage': 2, 'is_complete': false}),
        role: 'client',
      );
      addTearDown(session.dispose);
      final appearance = CreoAppearance(
        read: () async => brightness == Brightness.light ? 'light' : 'dark',
        write: (_) async {},
      );
      await appearance.restore();
      addTearDown(appearance.dispose);
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (_, child) => MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 740),
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: CreoAppearanceScope(appearance: appearance, child: child!),
            ),
            home: ClientPortalScreen(session: session),
          ),
        ),
      );
      await advance(tester);
      expect(find.byType(ClientPortalSetupShell), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image = await tester
            .renderObject<RenderRepaintBoundary>(find.byKey(capture))
            .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/client-access-qa').create(recursive: true);
        await File(
          'build/client-access-qa/locked-${brightness.name}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
