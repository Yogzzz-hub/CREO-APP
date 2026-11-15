import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app_flutter/src/core/auth_repository.dart';
import 'package:app_flutter/src/core/auth_session.dart';
import 'package:app_flutter/src/core/app_theme.dart';
import 'package:app_flutter/src/features/auth/auth_screen.dart';
import 'google_flow_test.dart' show FakeGooglePlatform, mobileAuthorization;
import 'auth_contract_test.dart' show MemorySessionStore, code;

Map<String, dynamic> authorization({
  String callback = 'https://app.example.test/auth/google/callback',
  String host = 'accounts.google.com',
  String state = 'attempt-state',
}) => {
  'state': state,
  'url': Uri.https(host, '/o/oauth2/v2/auth', {
    'client_id': 'example.apps.googleusercontent.com',
    'state': state,
    'redirect_uri': callback,
    'response_type': 'code',
  }).toString(),
};
AuthRepository repository(
  Future<http.Response> Function(http.Request) handler,
) => AuthRepository(
  store: MemorySessionStore(),
  origin: Uri.parse('https://api.example.test'),
  client: MockClient(handler),
);
http.Response response(Object body) => http.Response(jsonEncode(body), 200);

void main() {
  test(
    'default Google request uses backend configuration without creo.agency override',
    () async {
      final repo = repository((request) async {
        expect(request.url.path, '/api/v1/auth/google/url');
        expect(request.url.queryParameters, isEmpty);
        expect(request.headers.containsKey('authorization'), false);
        return response(authorization());
      });
      expect(
        Uri.parse(
          await repo.getGoogleAuthUrl(),
        ).queryParameters['redirect_uri'],
        'https://app.example.test/auth/google/callback',
      );
    },
  );
  test(
    'explicit registered callback is sent and must be reflected exactly',
    () async {
      const callback = 'https://mobile.example.test/auth/google/callback';
      final repo = repository((request) async {
        expect(request.url.queryParameters['redirect_uri'], callback);
        return response(authorization(callback: callback));
      });
      expect(
        Uri.parse(
          await repo.getGoogleAuthUrl(callback),
        ).queryParameters['redirect_uri'],
        callback,
      );
      final mismatch = repository((_) async => response(authorization()));
      await expectLater(
        mismatch.getGoogleAuthUrl(callback),
        throwsA(code('GOOGLE_CONFIGURATION_ERROR')),
      );
    },
  );
  test(
    'untrusted provider URLs, insecure callbacks and inconsistent states are rejected',
    () async {
      for (final body in [
        authorization(host: 'phishing.example.test'),
        authorization(callback: 'http://insecure.example.test/callback'),
        {...authorization(), 'state': 'other-state'},
        {'url': 'invalid', 'state': 'test'},
      ]) {
        await expectLater(
          repository((_) async => response(body)).getGoogleAuthUrl(),
          throwsA(code('GOOGLE_CONFIGURATION_ERROR')),
        );
      }
    },
  );
  Future<void> mount(
    WidgetTester tester,
    AuthRepository repo,
    AuthSession session,
    Future<bool> Function(Uri) launcher,
  ) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCreoTheme(),
        home: AuthScreen(
          repository: repo,
          session: session,
          googleLauncher: launcher,
          googlePlatform: FakeGooglePlatform(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue with Google'));
    await tester.pumpAndSettle();
  }

  testWidgets('Google launch failure is visible and form input is retained', (
    tester,
  ) async {
    final repo = repository(
      (request) async => response(mobileAuthorization(request)),
    );
    final session = AuthSession(store: repo.store, repository: repo);
    await mount(tester, repo, session, (_) async => false);
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'user@example.test',
    );
    await tester.ensureVisible(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Google sign-in could not open your browser. Please try again.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('login-email')))
          .controller!
          .text,
      'user@example.test',
    );
    expect(session.current, isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
  testWidgets(
    'duplicate Google taps send one request and ended attempts cannot launch browser',
    (tester) async {
      final pending = Completer<http.Response>();
      var calls = 0, launches = 0;
      final repo = repository((_) async {
        calls++;
        return pending.future;
      });
      final session = AuthSession(store: repo.store, repository: repo);
      await mount(tester, repo, session, (_) async {
        launches++;
        return true;
      });
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      expect(calls, 1);
      await session.logout(notifyServer: false);
      pending.complete(
        response(
          mobileAuthorization(
            http.Request(
              'GET',
              Uri.parse(
                'https://api.example.test/api/v1/auth/google/url?redirect_uri=https%3A%2F%2Fcreo.yogalakshmibaskar20.workers.dev%2Fauth%2Fgoogle%2Fcallback&code_challenge=ccccccccccccccccccccccccccccccccccccccccccc',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(launches, 0);
      expect(session.current, isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
