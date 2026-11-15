import 'package:app_flutter/main.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:app_flutter/src/core/android_google_sign_in_flow.dart';
import 'package:app_flutter/src/core/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'auth_contract_test.dart' show MemorySessionStore, sessionJson, code;
import 'session_lifecycle_test.dart' show owner, jsonResponse, jwt;

const androidClient =
    '810637569983-889eplhero9p1mt5afno54u4h18rn74g.apps.googleusercontent.com';
const serverClient =
    '810637569983-c6evh2ce0evjkgdmsgcicghl4lmnvfer.apps.googleusercontent.com';

class Identity implements AndroidGoogleIdentity {
  Identity(this.select);
  final Future<String> Function(String) select;
  @override
  Future<String> serverCode(String client) => select(client);
}

void main() {
  testWidgets(
    'normal Android app Google button uses native configuration endpoint',
    (tester) async {
      final paths = <String>[];
      final session = owner(MemorySessionStore(), (request) async {
        paths.add(request.url.path);
        return jsonResponse({'detail': 'Not found'}, 404);
      });
      await session.restore();
      await tester.pumpWidget(
        CreoApp(session: session, initialRoute: '/login'),
      );
      await tester.pumpAndSettle();
      final button = find.text('Continue with Google');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(paths, ['/api/v1/auth/google/android/config']);
      expect(
        find.textContaining('Android Google sign-in needs the server update'),
        findsOneWidget,
      );
      expect(session.current, isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  test(
    'native SDK server code is verified by backend then adopted once',
    () async {
      final store = MemorySessionStore();
      final paths = <String>[];
      final session = owner(store, (request) async {
        paths.add(request.url.path);
        if (request.method == 'GET') {
          return jsonResponse({'server_client_id': serverClient});
        }
        expect(request.url.path, '/api/v1/auth/google/android/callback');
        expect(jsonDecode(request.body), {'code': 'one-use-native-code'});
        return jsonResponse({
          ...sessionJson(role: 'client'),
          'access_token': jwt(),
        });
      });
      final flow = AndroidGoogleSignInFlow(
        session: session,
        repository: session.repository,
        identity: Identity((client) async {
          expect(client, serverClient);
          return 'one-use-native-code';
        }),
        loadRegistration: () async => jsonEncode({'client_id': androidClient}),
      );
      expect((await flow.signIn()).role, 'client');
      expect(store.writes, 1);
      expect(paths, [
        '/api/v1/auth/google/android/config',
        '/api/v1/auth/google/android/callback',
      ]);
      flow.dispose();
      expect(session.current?.user.role, 'client');
      session.dispose();
    },
  );

  for (final invalidate in ['cancel', 'logout', 'dispose']) {
    test(
      '$invalidate rejects late account selection without exchanging a code',
      () async {
        final selected = Completer<String>();
        final entered = Completer<void>();
        var posts = 0;
        final session = owner(MemorySessionStore(), (request) async {
          if (request.method == 'POST') posts++;
          return jsonResponse({'server_client_id': serverClient});
        });
        final flow = AndroidGoogleSignInFlow(
          session: session,
          repository: session.repository,
          identity: Identity((_) {
            entered.complete();
            return selected.future;
          }),
          loadRegistration: () async =>
              jsonEncode({'client_id': androidClient}),
        );
        final result = flow.signIn();
        final failure = expectLater(result, throwsA(code('GOOGLE_CANCELLED')));
        await entered.future;
        await expectLater(flow.signIn(), throwsA(code('REQUEST_PENDING')));
        if (invalidate == 'logout') {
          await session.logout(notifyServer: false);
        } else if (invalidate == 'dispose') {
          flow.dispose();
        } else {
          flow.cancel();
        }
        await failure;
        selected.complete('late-code');
        await Future<void>.delayed(Duration.zero);
        expect(posts, 0);
        expect(session.current, isNull);
        flow.dispose();
        session.dispose();
      },
    );
  }

  test('cancel during backend exchange rejects the late session', () async {
    final pending = Completer<http.Response>();
    final entered = Completer<void>();
    final session = owner(MemorySessionStore(), (request) async {
      if (request.method == 'GET') {
        return jsonResponse({'server_client_id': serverClient});
      }
      entered.complete();
      return pending.future;
    });
    final flow = AndroidGoogleSignInFlow(
      session: session,
      repository: session.repository,
      identity: Identity((_) async => 'code'),
      loadRegistration: () async => jsonEncode({'client_id': androidClient}),
    );
    final result = flow.signIn();
    final failure = expectLater(result, throwsA(code('GOOGLE_CANCELLED')));
    await entered.future;
    flow.cancel();
    await failure;
    pending.complete(jsonResponse({...sessionJson(), 'access_token': jwt()}));
    await Future<void>.delayed(Duration.zero);
    expect(session.current, isNull);
    flow.dispose();
    session.dispose();
  });

  test('different OAuth projects fail before opening account picker', () async {
    var picks = 0;
    final session = owner(
      MemorySessionStore(),
      (_) async => jsonResponse({'server_client_id': serverClient}),
    );
    final flow = AndroidGoogleSignInFlow(
      session: session,
      repository: session.repository,
      identity: Identity((_) async {
        picks++;
        return 'code';
      }),
      loadRegistration: () async =>
          jsonEncode({'client_id': '9999-other.apps.googleusercontent.com'}),
    );
    await expectLater(
      flow.signIn(),
      throwsA(code('GOOGLE_CONFIGURATION_ERROR')),
    );
    expect(picks, 0);
    flow.dispose();
    session.dispose();
  });

  test(
    'old backend reports native setup pending and never opens picker',
    () async {
      var picks = 0;
      final session = owner(
        MemorySessionStore(),
        (_) async => jsonResponse({'detail': 'Not found'}, 404),
      );
      final flow = AndroidGoogleSignInFlow(
        session: session,
        repository: session.repository,
        identity: Identity((_) async {
          picks++;
          return 'code';
        }),
        loadRegistration: () async => jsonEncode({'client_id': androidClient}),
      );
      await expectLater(
        flow.signIn(),
        throwsA(code('GOOGLE_ANDROID_NOT_READY')),
      );
      expect(picks, 0);
      flow.dispose();
      session.dispose();
    },
  );

  test('native provider cancellation creates no session', () async {
    final session = owner(
      MemorySessionStore(),
      (_) async => jsonResponse({'server_client_id': serverClient}),
    );
    final flow = AndroidGoogleSignInFlow(
      session: session,
      repository: session.repository,
      identity: Identity(
        (_) async => throw const HttpError(
          status: 0,
          code: 'GOOGLE_CANCELLED',
          message: 'Cancelled',
        ),
      ),
      loadRegistration: () async => jsonEncode({'client_id': androidClient}),
    );
    await expectLater(flow.signIn(), throwsA(code('GOOGLE_CANCELLED')));
    expect(session.current, isNull);
    flow.dispose();
    session.dispose();
  });

  test(
    'timeout retains no session and ignores a later account selection',
    () async {
      final selected = Completer<String>();
      var posts = 0;
      final session = owner(MemorySessionStore(), (request) async {
        if (request.method == 'POST') posts++;
        return jsonResponse({'server_client_id': serverClient});
      });
      final flow = AndroidGoogleSignInFlow(
        session: session,
        repository: session.repository,
        timeout: const Duration(milliseconds: 10),
        identity: Identity((_) => selected.future),
        loadRegistration: () async => jsonEncode({'client_id': androidClient}),
      );
      await expectLater(flow.signIn(), throwsA(code('GOOGLE_CANCELLED')));
      selected.complete('late');
      await Future<void>.delayed(Duration.zero);
      expect(posts, 0);
      flow.dispose();
      session.dispose();
    },
  );

  test(
    'mandatory reset response stays restricted after native sign-in',
    () async {
      final session = owner(
        MemorySessionStore(),
        (request) async => request.method == 'GET'
            ? jsonResponse({'server_client_id': serverClient})
            : jsonResponse({
                ...sessionJson(),
                'access_token': jwt(),
                'user': {
                  ...sessionJson()['user'] as Map,
                  'must_reset_password': true,
                },
              }),
      );
      final flow = AndroidGoogleSignInFlow(
        session: session,
        repository: session.repository,
        identity: Identity((_) async => 'code'),
        loadRegistration: () async => jsonEncode({'client_id': androidClient}),
      );
      expect((await flow.signIn()).mustResetPassword, isTrue);
      expect(session.current?.user.mustResetPassword, isTrue);
      flow.dispose();
      session.dispose();
    },
  );
}
