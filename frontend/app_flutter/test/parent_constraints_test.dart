import 'dart:convert';
import 'package:app_flutter/src/core/auth_repository.dart';
import 'package:app_flutter/src/core/auth_session.dart';
import 'package:app_flutter/src/features/auth/auth_screen.dart';
import 'package:app_flutter/src/core/app_theme.dart';
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
}
