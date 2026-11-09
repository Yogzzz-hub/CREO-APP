import 'dart:async';
import 'dart:convert';

import 'package:app_flutter/src/core/auth_repository.dart';
import 'package:app_flutter/src/core/auth_session.dart';
import 'package:app_flutter/src/core/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemorySessionStore implements SessionStore {
  StoredSession? value;
  int writes = 0;
  Completer<void>? pause;
  bool failNext = false;

  @override
  Future<StoredSession?> read() async => value;
  @override
  Future<void> write(StoredSession? session) async {
    writes++;
    if (failNext) {
      failNext = false;
      throw StateError('storage unavailable');
    }
    value = session;
    final pending = pause;
    pause = null;
    if (pending != null) await pending.future;
  }
}

Map<String, dynamic> sessionJson({
  String id = 'account-a',
  String role = 'client',
}) => {
  'access_token': 'opaque-access',
  'refresh_token': 'opaque-refresh',
  'user': {
    'id': id,
    'email': 'user@example.test',
    'full_name': 'Example',
    'role': role,
    'account_status': 'active',
    'onboarding_stage': 8,
  },
};

TypeMatcher<HttpError> code(String value) =>
    isA<HttpError>().having((e) => e.code, 'code', value);

void main() {
  final origin = Uri.parse('https://api.example.test');

  test(
    'T01-T04 login trims email only, POST JSON, no token side effects',
    () async {
      final store = MemorySessionStore();
      final repo = AuthRepository(
        origin: origin,
        store: store,
        client: MockClient((r) async {
          expect(r.method, 'POST');
          expect(
            r.url.toString(),
            'https://api.example.test/api/v1/auth/login',
          );
          expect(r.headers['content-type'], contains('application/json'));
          expect(jsonDecode(r.body), {
            'email': 'user@example.test',
            'password': '  pass word  ',
          });
          expect(r.headers.containsKey('authorization'), false);
          return http.Response(jsonEncode(sessionJson()), 200);
        }),
      );
      final result = await repo.loginWithPassword(
        ' user@example.test ',
        '  pass word  ',
      );
      expect(result.user.id, 'account-a');
      expect(store.writes, 0);
    },
  );

  for (final errorCode in [
    'INVALID_CREDENTIALS',
    'PASSWORD_NOT_SET',
    'ACCOUNT_EXISTS',
  ]) {
    test('T05-T08 structured $errorCode and nested methods', () async {
      final repo = AuthRepository(
        origin: origin,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {
                'code': errorCode,
                'message': 'Action required',
                'details': {
                  'sign_in_methods': ['google'],
                },
              },
            }),
            errorCode == 'ACCOUNT_EXISTS' ? 409 : 401,
          ),
        ),
      );
      await expectLater(
        repo.loginWithPassword('user@example.test', 'x'),
        throwsA(
          code(
            errorCode,
          ).having((e) => e.details['sign_in_methods'], 'methods', ['google']),
        ),
      );
    });
  }

  test('FastAPI detail arrays retain field locations', () async {
    final repo = AuthRepository(
      origin: origin,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'detail': [
              {
                'loc': ['body', 'email'],
                'msg': 'Invalid email',
              },
            ],
          }),
          422,
        ),
      ),
    );
    await expectLater(
      repo.loginWithPassword('invalid', 'x'),
      throwsA(
        code(
          'VALIDATION_ERROR',
        ).having((e) => e.message, 'message', 'email: Invalid email'),
      ),
    );
  });

  test('detail object and string are normalized', () async {
    for (final detail in [
      <String, dynamic>{'code': 'CUSTOM', 'message': 'Denied'},
      'Denied',
    ]) {
      final repo = AuthRepository(
        origin: origin,
        client: MockClient(
          (_) async => http.Response(jsonEncode({'detail': detail}), 403),
        ),
      );
      await expectLater(
        repo.loginWithPassword('user@example.test', 'x'),
        throwsA(isA<HttpError>().having((e) => e.message, 'message', 'Denied')),
      );
    }
  });

  for (final status in [429, 503]) {
    test('non-JSON $status produces actionable error', () async {
      final repo = AuthRepository(
        origin: origin,
        client: MockClient((_) async => http.Response('Unavailable', status)),
      );
      await expectLater(
        repo.loginWithPassword('user@example.test', 'x'),
        throwsA(code(status == 429 ? 'RATE_LIMITED' : 'HTTP_ERROR')),
      );
    });
  }

  test('network failure does not become invalid credentials', () async {
    final repo = AuthRepository(
      origin: origin,
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(
      repo.loginWithPassword('user@example.test', 'x'),
      throwsA(code('NETWORK_ERROR')),
    );
  });
  test('timeout is bounded and login is not retried', () async {
    var requests = 0;
    final pending = Completer<http.Response>();
    final repo = AuthRepository(
      origin: origin,
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) {
        requests++;
        return pending.future;
      }),
    );
    await expectLater(
      repo.loginWithPassword('user@example.test', 'x'),
      throwsA(code('TIMEOUT')),
    );
    pending.complete(http.Response(jsonEncode(sessionJson()), 200));
    expect(requests, 1);
  });
  test(
    'default mobile origin reaches existing login contract without build flags',
    () async {
      final repo = AuthRepository(
        client: MockClient((request) async {
          expect(
            request.url,
            Uri.parse(
              'https://creo-api-singapore.onrender.com/api/v1/auth/login',
            ),
          );
          expect(request.method, 'POST');
          expect(
            request.headers.keys.any(
              (name) => name.toLowerCase().startsWith('x-razorpay-'),
            ),
            isFalse,
          );
          return http.Response(jsonEncode(sessionJson()), 200);
        }),
      );
      addTearDown(repo.close);
      final result = await repo.loginWithPassword(
        'user@example.test',
        'fixture-only',
      );
      expect(result.user.id, 'account-a');
    },
  );
  test('empty or unsafe explicit origin never sends credentials', () async {
    var requests = 0;
    for (final uri in [
      Uri(),
      Uri.parse('http://api.example.test'),
      Uri.parse('https://api.example.test/path'),
      Uri.parse('https://name:secret@api.example.test'),
    ]) {
      final repo = AuthRepository(
        origin: uri,
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        repo.loginWithPassword('user@example.test', 'x'),
        throwsA(code('API_NOT_CONFIGURED')),
      );
    }
    expect(requests, 0);
  });
  test('malformed success cannot be adopted', () async {
    for (final body in [
      'not json',
      '{}',
      jsonEncode({'access_token': '', 'user': {}}),
    ]) {
      final repo = AuthRepository(
        origin: origin,
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        repo.loginWithPassword('user@example.test', 'x'),
        throwsA(code('INVALID_RESPONSE')),
      );
    }
  });

  test('adopt once commits a complete secure record', () async {
    final store = MemorySessionStore();
    final owner = AuthSession(store: store);
    final response = SessionResponse.fromJson(sessionJson());
    expect(await owner.adopt(response, owner.beginAttempt()), true);
    expect(store.value?.userId, 'account-a');
    expect(owner.current, response);
  });
  test('cancelled response cannot touch storage', () async {
    final store = MemorySessionStore();
    final owner = AuthSession(store: store);
    final attempt = owner.beginAttempt();
    owner.cancel(attempt);
    expect(
      await owner.adopt(SessionResponse.fromJson(sessionJson()), attempt),
      false,
    );
    expect(store.writes, 0);
  });
  test(
    'another account or unidentified legacy session is never replaced',
    () async {
      for (final id in ['account-b', null]) {
        final store = MemorySessionStore()
          ..value = StoredSession('previous', 'previous-refresh', id);
        final owner = AuthSession(store: store);
        await expectLater(
          owner.adopt(
            SessionResponse.fromJson(sessionJson()),
            owner.beginAttempt(),
          ),
          throwsA(code('SESSION_EXISTS')),
        );
        expect(store.value?.accessToken, 'previous');
        expect(store.writes, 0);
      }
    },
  );
  test(
    'cancellation during commit rolls back before a successor commits',
    () async {
      final store = MemorySessionStore();
      final pause = Completer<void>();
      store.pause = pause;
      final owner = AuthSession(store: store);
      final first = owner.beginAttempt();
      final a = owner.adopt(SessionResponse.fromJson(sessionJson()), first);
      await Future<void>.delayed(Duration.zero);
      final second = owner.beginAttempt();
      final b = owner.adopt(
        SessionResponse.fromJson(sessionJson(id: 'account-b')),
        second,
      );
      pause.complete();
      expect(await a, false);
      expect(await b, true);
      expect(store.value?.userId, 'account-b');
      expect(owner.current?.user.id, 'account-b');
    },
  );
  test(
    'storage failure leaves existing record unchanged, no adopted user',
    () async {
      final old = StoredSession('previous', 'refresh', 'account-a');
      final store = MemorySessionStore()..value = old;
      store.failNext = true;
      final owner = AuthSession(store: store);
      await expectLater(
        owner.adopt(
          SessionResponse.fromJson(sessionJson()),
          owner.beginAttempt(),
        ),
        throwsStateError,
      );
      expect(store.value, old);
      expect(owner.current, null);
    },
  );
  test(
    'destination intents follow confirmed roles without email elevation',
    () {
      const homes = {
        'client': '/portal',
        'admin': '/admin',
        'super_admin': '/admin',
        'sales': '/bde',
        'bde': '/bde',
        'bde_head': '/bde/crm/overview',
        'team_lead': '/admin/pod-dashboard',
        'editor': '/workstation',
        'designer': '/workstation',
        'freelancer': '/freelancer/tasks',
        'investor_relations': '/admin/reports',
      };
      for (final role in homes.keys) {
        final intent = DestinationIntent.forUser(
          SessionResponse.fromJson(sessionJson(role: role)).user,
        );
        expect(intent.path, homes[role]);
        expect(intent.blocker, isNotNull);
      }
      expect(
        DestinationIntent.forUser(
          SessionResponse.fromJson(sessionJson(role: 'unconfirmed')).user,
        ).path,
        null,
      );
      final restricted = sessionJson();
      (restricted['user'] as Map)['must_reset_password'] = true;
      expect(
        DestinationIntent.forUser(
          SessionResponse.fromJson(restricted).user,
        ).path,
        null,
      );
    },
  );
}
