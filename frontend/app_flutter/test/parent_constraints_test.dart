import 'dart:convert';
import 'package:app_flutter/src/core/auth_repository.dart';
import 'package:app_flutter/src/core/auth_session.dart';
import 'package:app_flutter/src/features/auth/auth_screen.dart';
import 'package:app_flutter/src/core/app_theme.dart';
import 'package:app_flutter/src/features/landing/landing_motion.dart';
import 'package:app_flutter/src/features/landing/landing_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'auth_contract_test.dart' show MemorySessionStore;

void main() {
  for (final brightness in Brightness.values) {
    for (final size in [const Size(280, 520), const Size(480, 300)]) {
      testWidgets(
        'auth and long feedback fit parent $size, $brightness, 200% text',
        (tester) async {
          tester.view.physicalSize = const Size(1024, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          const message =
              'Unable to sign in right now. Please check your connection and try again when the service is available.';
          final store = MemorySessionStore();
          final repo = AuthRepository(
            origin: Uri.parse('https://api.example.test'),
            store: store,
            client: MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'error': {'code': 'SERVER_ERROR', 'message': message},
                }),
                503,
              ),
            ),
          );
          final owner = AuthSession(store: store, repository: repo);
          await tester.pumpWidget(
            MaterialApp(
              theme: buildCreoTheme(brightness: brightness),
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(1024, 900),
                  textScaler: TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: Center(
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: AuthScreen(repository: repo, session: owner),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.enterText(
            find.byKey(const Key('login-email')),
            'reader@example.test',
          );
          await tester.enterText(
            find.byKey(const Key('login-password')),
            'fixture-only',
          );
          tester.testTextInput.hide();
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          final submit = find.widgetWithText(ElevatedButton, 'Sign in');
          await Scrollable.ensureVisible(tester.element(submit), alignment: .5);
          await tester.pumpAndSettle();
          await tester.tap(submit);
          await tester.pumpAndSettle();
          expect(find.text(message), findsOneWidget);
          await tester.ensureVisible(find.text(message));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          owner.dispose();
          repo.close();
        },
      );
    }
  }
  for (final size in [const Size(280, 520), const Size(480, 300)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('landing uses actual parent $size with text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1024, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final parent = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildCreoTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(1024, 900),
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: Center(
                child: SizedBox(
                  key: parent,
                  width: size.width,
                  height: size.height,
                  child: const LandingPage(),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final header = tester.widget<SliverPersistentHeader>(
          find.byType(SliverPersistentHeader),
        );
        expect((header.delegate as LandingHeroDelegate).height, size.height);
        final scroll = tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .controller!;
        for (
          double offset = 0;
          offset < scroll.position.maxScrollExtent;
          offset += 600
        ) {
          scroll.jumpTo(offset);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 1400));
          expect(
            tester.takeException(),
            isNull,
            reason: 'parent=$size scale=$scale offset=$offset',
          );
        }
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pump();
        expect(tester.takeException(), isNull);
        final button = find.widgetWithText(
          ElevatedButton,
          'Claim Free Sample Batch',
        );
        await tester.ensureVisible(button);
        await tester.pump();
        final textRect = tester.getRect(find.text('Claim Free Sample Batch'));
        final buttonRect = tester.getRect(button);
        expect(textRect.height, lessThanOrEqualTo(buttonRect.height));
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
