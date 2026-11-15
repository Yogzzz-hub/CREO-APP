import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app_flutter/src/core/auth_repository.dart';
import 'package:app_flutter/src/core/auth_session.dart';
import 'package:app_flutter/src/core/google_sign_in_flow.dart';
import 'auth_contract_test.dart' show MemorySessionStore, sessionJson, code;

class FakeGooglePlatform implements GoogleOAuthPlatform {
  final controller = StreamController<Uri>.broadcast(sync: true);
  @override
  Stream<Uri> get links => controller.stream;
  @override
  Future<void> attach() async {}
  @override
  Future<GooglePkcePair> createPkce() async =>
      GooglePkcePair('v' * 43, 'c' * 43);
  void callback(String query) => controller.add(
    Uri.parse('com.creo.app://app/auth/google/callback?$query'),
  );
  @override
  void dispose() {
    unawaited(controller.close());
  }
}

Map<String, dynamic> mobileAuthorization(
  http.Request request, {
  bool supported = true,
}) {
  final parameters = {
    'client_id': 'example.apps.googleusercontent.com',
    'redirect_uri': request.url.queryParameters['redirect_uri']!,
    'state': 'state-one',
    if (supported)
      'code_challenge': request.url.queryParameters['code_challenge']!,
    if (supported) 'code_challenge_method': 'S256',
  };
  return {
    'url': Uri.https(
      'accounts.google.com',
      '/o/oauth2/v2/auth',
      parameters,
    ).toString(),
    'state': 'state-one',
    if (supported) 'pkce_supported': true,
  };
}

http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

void main() {
  Future<void> settle() => Future<void>.delayed(Duration.zero);
  ({
    GoogleSignInFlow flow,
    AuthSession session,
    MemorySessionStore store,
    FakeGooglePlatform platform,
  })
  setup(
    Future<http.Response> Function(http.Request) send, {
    Future<bool> Function(Uri)? launch,
    Duration timeout = const Duration(minutes: 10),
  }) {
    final store = MemorySessionStore(), platform = FakeGooglePlatform();
    final repo = AuthRepository(
      store: store,
      origin: Uri.parse('https://api.example.test'),
      client: MockClient(send),
    );
    final session = AuthSession(store: store, repository: repo);
    return (
      flow: GoogleSignInFlow(
        session: session,
        repository: repo,
        platform: platform,
        launch: launch ?? (_) async => true,
        timeout: timeout,
      ),
      session: session,
      store: store,
      platform: platform,
    );
  }

  test(
    'PKCE browser handoff exchanges once and adopts client through session owner',
    () async {
      var exchanges = 0;
      Uri? browser;
      final x = setup(
        (request) async {
          if (request.method == 'GET')
            return json(mobileAuthorization(request));
          exchanges++;
          expect(request.url.path, '/api/v1/auth/google/callback');
          expect(jsonDecode(request.body), {
            'code': 'google-code',
            'redirect_uri':
                'https://creo.yogalakshmibaskar20.workers.dev/auth/google/callback',
            'code_verifier': 'v' * 43,
          });
          return json(sessionJson());
        },
        launch: (uri) async {
          browser = uri;
          return true;
        },
      );
      final pending = x.flow.signIn();
      await settle();
      expect(browser!.path, '/app-oauth');
      final consent = Uri.parse(browser!.queryParameters['to']!);
      expect(consent.queryParameters['code_challenge'], 'c' * 43);
      expect(consent.queryParameters.containsKey('code_verifier'), false);
      x.platform.callback('code=google-code&state=state-one');
      final user = await pending;
      expect(user.role, 'client');
      expect(exchanges, 1);
      expect(x.store.value, isNotNull);
      x.platform.callback('code=google-code&state=state-one');
      await settle();
      expect(exchanges, 1);
      final generation = x.session.beginReadGeneration;
      x.flow.dispose();
      expect(x.session.isCurrent(generation), true);
      x.session.dispose();
    },
  );
  for (final query in [
    'code=code&state=wrong',
    'code=code&state=state-one&state=duplicate',
    'token=untrusted&state=state-one',
  ]) {
    test(
      'unsolicited/mismatched callback rejected without adoption: $query',
      () async {
        var writes = 0;
        final x = setup((request) async {
          if (request.method == 'GET')
            return json(mobileAuthorization(request));
          writes++;
          return json(sessionJson());
        });
        final pending = x.flow.signIn();
        final check = expectLater(
          pending,
          throwsA(code('GOOGLE_STATE_MISMATCH')),
        );
        await settle();
        x.platform.callback(query);
        await check;
        expect(writes, 0);
        expect(x.store.value, isNull);
        x.flow.dispose();
        x.session.dispose();
      },
    );
  }
  test(
    'provider cancellation and user cancellation retain signed-out state',
    () async {
      final x = setup((request) async => json(mobileAuthorization(request)));
      final pending = x.flow.signIn();
      final check = expectLater(pending, throwsA(code('GOOGLE_CANCELLED')));
      await settle();
      x.platform.callback('error=access_denied&state=state-one');
      await check;
      expect(x.session.current, isNull);
      x.flow.dispose();
      x.session.dispose();
    },
  );
  test('old backend cannot silently downgrade a mobile PKCE flow', () async {
    var launches = 0;
    final x = setup(
      (request) async => json(mobileAuthorization(request, supported: false)),
      launch: (_) async {
        launches++;
        return true;
      },
    );
    await expectLater(
      x.flow.signIn(),
      throwsA(code('GOOGLE_MOBILE_NOT_READY')),
    );
    expect(launches, 0);
    x.flow.dispose();
    x.session.dispose();
  });
  test(
    'logout during code exchange rejects late response and never stores session',
    () async {
      final exchange = Completer<http.Response>();
      final x = setup(
        (request) async => request.method == 'GET'
            ? json(mobileAuthorization(request))
            : exchange.future,
      );
      final pending = x.flow.signIn();
      final check = expectLater(pending, throwsA(code('GOOGLE_CANCELLED')));
      await settle();
      x.platform.callback('code=code&state=state-one');
      await settle();
      await x.session.logout(notifyServer: false);
      await check;
      exchange.complete(json(sessionJson()));
      await settle();
      expect(x.store.value, isNull);
      expect(x.session.current, isNull);
      x.flow.dispose();
      x.session.dispose();
    },
  );
  test(
    'expiry clears pending state and repeated start cannot duplicate browser flow',
    () async {
      final x = setup(
        (request) async => json(mobileAuthorization(request)),
        timeout: const Duration(milliseconds: 10),
      );
      final first = x.flow.signIn();
      final check = expectLater(first, throwsA(code('GOOGLE_CANCELLED')));
      await settle();
      await expectLater(x.flow.signIn(), throwsA(code('REQUEST_PENDING')));
      await check;
      expect(x.store.value, isNull);
      x.flow.dispose();
      x.session.dispose();
    },
  );
  test(
    'existing staff Google account keeps backend role and restricted flag',
    () async {
      final x = setup(
        (request) async => request.method == 'GET'
            ? json(mobileAuthorization(request))
            : json({
                ...sessionJson(role: 'team_lead'),
                'user': {
                  ...sessionJson(role: 'team_lead')['user']
                      as Map<String, dynamic>,
                  'must_reset_password': true,
                },
              }),
      );
      final pending = x.flow.signIn();
      await settle();
      x.platform.callback('code=code&state=state-one');
      final user = await pending;
      expect(user.role, 'team_lead');
      expect(user.mustResetPassword, true);
      x.flow.dispose();
      x.session.dispose();
    },
  );
}
