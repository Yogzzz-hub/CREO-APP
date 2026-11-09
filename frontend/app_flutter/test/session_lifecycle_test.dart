import 'dart:async';
import 'dart:convert';
import 'package:app_flutter/src/core/auth_repository.dart';
import 'package:app_flutter/src/core/auth_session.dart';
import 'package:app_flutter/src/core/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'auth_contract_test.dart' show MemorySessionStore, sessionJson, code;

final clock = DateTime.utc(2030);
String jwt({bool expired = false, String marker = 'access'}) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'typ': 'JWT'})}.${encode({'sub': 'account-a', 'marker': marker, 'exp': clock.add(Duration(minutes: expired ? -1 : 30)).millisecondsSinceEpoch ~/ 1000})}.signature';
}

Map<String, dynamic> profile({
  String? access,
  bool restricted = false,
  String id = 'account-a',
}) => {
  ...sessionJson(id: id)['user'] as Map<String, dynamic>,
  'access_token': access,
  'must_reset_password': restricted,
};
http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);
StoredSession saved({
  bool expired = false,
  bool refreshOnly = false,
  String? userId = 'account-a',
}) => StoredSession(
  refreshOnly ? '' : jwt(expired: expired),
  'refresh-unchanged',
  userId,
);
AuthSession owner(
  MemorySessionStore store,
  Future<http.Response> Function(http.Request) send, {
  void Function()? clearCache,
}) => AuthSession(
  store: store,
  now: () => clock,
  clearPrivateData: clearCache,
  repository: AuthRepository(
    store: store,
    origin: Uri.parse('https://api.example.test'),
    client: MockClient(send),
  ),
);

class FaultyStore extends MemorySessionStore {
  bool failRead = false;
  bool failClear = false;
  @override
  Future<StoredSession?> read() async {
    if (failRead) throw const FormatException('corrupt storage');
    return super.read();
  }

  @override
  Future<void> write(StoredSession? session) async {
    if (session == null && failClear) throw StateError('cannot clear');
    return super.write(session);
  }
}

void main() {
  test('T09 cold launch without credentials sends no request', () async {
    final store = MemorySessionStore();
    var calls = 0;
    final session = owner(store, (_) async {
      calls++;
      return jsonResponse({});
    });
    await session.restore();
    expect(calls, 0);
    expect(session.current, null);
    expect(session.phase, SessionPhase.signedOut);
  });
  test(
    'T10 valid saved session uses direct profile and replacement token',
    () async {
      final store = MemorySessionStore()..value = saved();
      final replacement = jwt(marker: 'me');
      final session = owner(store, (r) async {
        expect(r.url.path, '/api/v1/auth/me');
        expect(r.headers['authorization'], 'Bearer ${jwt()}');
        return jsonResponse(profile(access: replacement));
      });
      await session.restore();
      expect(session.phase, SessionPhase.authenticated);
      expect(session.current?.user.id, 'account-a');
      expect(store.value?.accessToken, replacement);
      expect(store.value?.refreshToken, 'refresh-unchanged');
    },
  );
  for (final refreshOnly in [false, true]) {
    test(
      'T11-T12 ${refreshOnly ? 'refresh-only' : 'expired access'} refreshes before me, without rotation',
      () async {
        final store = MemorySessionStore()
          ..value = saved(expired: true, refreshOnly: refreshOnly);
        final paths = <String>[];
        final renewed = jwt(marker: 'renewed');
        final session = owner(store, (r) async {
          paths.add(r.url.path);
          if (r.url.path.endsWith('/refresh')) {
            expect(jsonDecode(r.body), {'refresh_token': 'refresh-unchanged'});
            expect(r.headers['authorization'], null);
            return jsonResponse({
              'access_token': renewed,
              'token_type': 'bearer',
            });
          }
          expect(r.headers['authorization'], 'Bearer $renewed');
          return jsonResponse(profile());
        });
        await session.restore();
        expect(paths, ['/api/v1/auth/refresh', '/api/v1/auth/me']);
        expect(session.current?.accessToken, renewed);
        expect(store.value?.refreshToken, 'refresh-unchanged');
      },
    );
  }
  test(
    'legacy credentials gain identity only after server profile verification',
    () async {
      final store = MemorySessionStore()..value = saved(userId: null);
      final session = owner(store, (_) async => jsonResponse(profile()));
      await session.restore();
      expect(store.value?.userId, 'account-a');
    },
  );
  test('T13 simultaneous requests share one refresh', () async {
    final store = MemorySessionStore()..value = saved(expired: true);
    final refresh = Completer<http.Response>();
    var renewals = 0;
    var reads = 0;
    final session = owner(store, (r) async {
      if (r.url.path.endsWith('/refresh')) {
        renewals++;
        return refresh.future;
      }
      reads++;
      return jsonResponse({'ok': true});
    });
    final requests = List.generate(
      5,
      (_) => session.request('GET', '/api/v1/portal/dashboard'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(renewals, 1);
    refresh.complete(jsonResponse({'access_token': jwt(marker: 'renewed')}));
    await Future.wait(requests);
    expect(renewals, 1);
    expect(reads, 5);
  });
  test(
    'T14 eligible 401 replays only once and second 401 ends session',
    () async {
      final store = MemorySessionStore()..value = saved();
      var reads = 0;
      var renewals = 0;
      final session = owner(store, (r) async {
        if (r.url.path.endsWith('/refresh')) {
          renewals++;
          return jsonResponse({'access_token': jwt(marker: 'new')});
        }
        reads++;
        return jsonResponse({'detail': 'Expired'}, 401);
      });
      await expectLater(
        session.request('GET', '/api/v1/portal/dashboard'),
        throwsA(isA<HttpError>()),
      );
      expect(reads, 2);
      expect(renewals, 1);
      expect(store.value, null);
      expect(session.phase, SessionPhase.signedOut);
    },
  );
  test('T14 eligible 401 renews and returns successful replay', () async {
    final store = MemorySessionStore()..value = saved();
    var reads = 0;
    final session = owner(store, (r) async {
      if (r.url.path.endsWith('/refresh')) {
        return jsonResponse({'access_token': jwt(marker: 'new')});
      }
      return ++reads == 1
          ? jsonResponse({'detail': 'Expired'}, 401)
          : jsonResponse({'ok': true});
    });
    expect(await session.request('GET', '/api/v1/portal/dashboard'), {
      'ok': true,
    });
    expect(reads, 2);
    expect(store.value, isNotNull);
  });
  test(
    'concurrent 401s use shared renewal or the already renewed access token',
    () async {
      final store = MemorySessionStore()..value = saved();
      var renewals = 0;
      final session = owner(store, (r) async {
        if (r.url.path.endsWith('/refresh')) {
          renewals++;
          return jsonResponse({'access_token': jwt(marker: 'new')});
        }
        if (r.headers['authorization'] == 'Bearer ${jwt()}') {
          return jsonResponse({'detail': 'Expired'}, 401);
        }
        return jsonResponse({'ok': true});
      });
      await Future.wait(
        List.generate(
          5,
          (_) => session.request('GET', '/api/v1/portal/dashboard'),
        ),
      );
      expect(renewals, 1);
    },
  );
  test(
    'T15 auth-entry request never refreshes or clears existing session',
    () async {
      for (final path in [
        '/api/v1/auth/login',
        '/api/v1/auth/verify-registration',
        '/api/v1/auth/reset-password',
        '/api/v1/auth/google/callback',
        '/api/v1/auth/refresh',
      ]) {
        final store = MemorySessionStore()..value = saved(expired: true);
        var calls = 0;
        final session = owner(store, (r) async {
          calls++;
          expect(r.url.path, path);
          return jsonResponse({'detail': 'Rejected'}, 401);
        });
        await expectLater(
          session.request('POST', path, body: {}),
          throwsA(isA<HttpError>()),
        );
        expect(calls, 1);
        expect(store.writes, 0);
      }
    },
  );
  for (final status in [401, 403]) {
    test('T16 refresh rejection $status removes credentials', () async {
      final store = MemorySessionStore()..value = saved(expired: true);
      final session = owner(
        store,
        (_) async => jsonResponse({'detail': 'Rejected'}, status),
      );
      await session.restore();
      expect(store.value, null);
      expect(session.current, null);
      expect(session.phase, SessionPhase.signedOut);
    });
  }
  test('T16 refresh timeout retains credentials and Retry restores', () async {
    final store = MemorySessionStore()..value = saved(expired: true);
    var offline = true;
    final session = owner(store, (r) async {
      if (offline) throw TimeoutException('test timeout');
      return r.url.path.endsWith('/refresh')
          ? jsonResponse({'access_token': jwt(marker: 'new')})
          : jsonResponse(profile());
    });
    await session.restore();
    expect(store.value?.refreshToken, 'refresh-unchanged');
    expect(session.phase, SessionPhase.unavailable);
    expect(session.issue?.code, 'TIMEOUT');
    offline = false;
    await session.restore();
    expect(session.phase, SessionPhase.authenticated);
  });
  test('offline me retains credentials without exposing cached user', () async {
    final store = MemorySessionStore()..value = saved();
    final session = owner(
      store,
      (_) async => throw http.ClientException('offline'),
    );
    await session.restore();
    expect(session.phase, SessionPhase.unavailable);
    expect(session.current, null);
    expect(store.value, isNotNull);
  });
  test('T17 resource forbidden is not expired authentication', () async {
    final store = MemorySessionStore()..value = saved();
    final session = owner(
      store,
      (_) async => jsonResponse({
        'error': {'code': 'FORBIDDEN_ROLE', 'message': 'Denied'},
      }, 403),
    );
    await expectLater(
      session.request('GET', '/api/v1/admin/kpis'),
      throwsA(code('FORBIDDEN_ROLE')),
    );
    expect(store.value, isNotNull);
    expect(store.writes, 0);
  });
  for (final ended in ['ACCOUNT_SUSPENDED', 'SESSION_REVOKED']) {
    test('final $ended clears without renewal', () async {
      final store = MemorySessionStore()..value = saved();
      var calls = 0;
      final session = owner(store, (_) async {
        calls++;
        return jsonResponse({
          'error': {'code': ended, 'message': 'Session ended'},
        }, 401);
      });
      await expectLater(
        session.request('GET', '/api/v1/portal/dashboard'),
        throwsA(code(ended)),
      );
      expect(calls, 1);
      expect(store.value, null);
      expect(session.issue?.code, ended);
    });
  }
  test(
    'mandatory-reset profile null token preserves restricted credentials',
    () async {
      final store = MemorySessionStore()..value = saved();
      final session = owner(
        store,
        (_) async => jsonResponse(profile(restricted: true)),
      );
      await session.restore();
      expect(session.current?.user.mustResetPassword, true);
      expect(session.current?.accessToken, jwt());
      expect(store.value?.accessToken, jwt());
      expect(DestinationIntent.forUser(session.current!.user).path, null);
    },
  );
  test(
    'write 401 is not replayed and does not discard a renewable session',
    () async {
      final store = MemorySessionStore()..value = saved();
      var calls = 0;
      final session = owner(store, (_) async {
        calls++;
        return jsonResponse({'detail': 'Expired'}, 401);
      });
      await expectLater(
        session.request(
          'POST',
          '/api/v1/tickets',
          body: {'subject': 'Example'},
        ),
        throwsA(isA<HttpError>()),
      );
      expect(calls, 1);
      expect(store.value, isNotNull);
    },
  );
  test('ambiguous write timeout is never retried', () async {
    final store = MemorySessionStore()..value = saved();
    var calls = 0;
    final session = owner(store, (_) async {
      calls++;
      throw TimeoutException('ambiguous');
    });
    await expectLater(
      session.request('POST', '/api/v1/tickets', body: {}),
      throwsA(code('TIMEOUT')),
    );
    expect(calls, 1);
    expect(store.value, isNotNull);
  });
  test(
    'T27 logout during refresh prevents reauthentication and clears cache immediately',
    () async {
      final store = MemorySessionStore()..value = saved(expired: true);
      final refresh = Completer<http.Response>();
      var cleared = false;
      final session = owner(
        store,
        (r) async => r.url.path.endsWith('/refresh')
            ? refresh.future
            : jsonResponse({'status': 'logged_out'}),
        clearCache: () => cleared = true,
      );
      final restore = session.restore();
      await Future<void>.delayed(Duration.zero);
      final logout = session.logout();
      expect(cleared, true);
      expect(session.current, null);
      expect(session.phase, SessionPhase.clearing);
      await logout;
      refresh.complete(jsonResponse({'access_token': jwt(marker: 'late')}));
      await restore;
      expect(store.value, null);
      expect(session.current, null);
      expect(session.phase, SessionPhase.signedOut);
    },
  );
  test('T27 logout invalidates a pending AS-01 login attempt', () async {
    final store = MemorySessionStore();
    final pending = Completer<http.Response>();
    final session = owner(store, (_) => pending.future);
    final ticket = session.beginAttempt();
    final login = session.repository.loginWithPassword(
      'user@example.test',
      'password',
    );
    await session.logout();
    pending.complete(jsonResponse(sessionJson()));
    expect(await session.adopt(await login, ticket), false);
    expect(store.value, null);
  });
  test(
    'offline logout clears locally without waiting for a pending network call',
    () async {
      final store = MemorySessionStore()..value = saved();
      final logoutReply = Completer<http.Response>();
      final session = owner(
        store,
        (r) async => r.url.path.endsWith('/logout')
            ? logoutReply.future
            : jsonResponse(profile()),
      );
      await session.restore();
      await session.logout();
      expect(store.value, null);
      expect(session.current, null);
      expect(session.navigationEpoch, 1);
      logoutReply.completeError(http.ClientException('offline'));
      await Future<void>.delayed(Duration.zero);
    },
  );
  test(
    'account switch rejects old profile response after explicit sign-out',
    () async {
      final store = MemorySessionStore()..value = saved();
      final oldProfile = Completer<http.Response>();
      final session = owner(store, (_) => oldProfile.future);
      final restoration = session.restore();
      await Future<void>.delayed(Duration.zero);
      await session.logout(notifyServer: false);
      final ticket = session.beginAttempt();
      await session.adopt(
        SessionResponse.fromJson(sessionJson(id: 'account-b')),
        ticket,
      );
      oldProfile.complete(jsonResponse(profile()));
      await restoration;
      expect(session.current?.user.id, 'account-b');
      expect(store.value?.userId, 'account-b');
    },
  );
  test(
    'corrupted storage is explicit, does not send credentials, can clear',
    () async {
      final store = FaultyStore()..failRead = true;
      var calls = 0;
      final session = owner(store, (_) async {
        calls++;
        return jsonResponse({});
      });
      await session.restore();
      expect(session.phase, SessionPhase.storageFailure);
      expect(calls, 0);
      expect(session.issue?.code, 'STORAGE_ERROR');
      await session.logout(notifyServer: false);
      expect(session.phase, SessionPhase.signedOut);
    },
  );
  test(
    'failed credential clearing blocks sign-in until explicit retry succeeds',
    () async {
      final store = FaultyStore()..value = saved();
      store.failClear = true;
      final session = owner(store, (_) async => jsonResponse(profile()));
      await session.restore();
      await session.logout(notifyServer: false);
      expect(session.current, null);
      expect(session.phase, SessionPhase.storageFailure);
      expect(session.issue?.code, 'STORAGE_CLEAR_FAILED');
      await session
          .restore(); // Cannot resurrect credentials after failed sign-out.
      expect(session.phase, SessionPhase.storageFailure);
      expect(session.beginAttempt, throwsA(code('SESSION_UNAVAILABLE')));
      store.failClear = false;
      await session.logout(notifyServer: false);
      expect(store.value, null);
      expect(session.phase, SessionPhase.signedOut);
    },
  );
  test(
    'storage write failure during refresh does not expose an authenticated user',
    () async {
      final store = MemorySessionStore()..value = saved(expired: true);
      store.failNext = true;
      final session = owner(
        store,
        (_) async => jsonResponse({'access_token': jwt(marker: 'new')}),
      );
      await session.restore();
      expect(session.phase, SessionPhase.storageFailure);
      expect(session.current, null);
      expect(store.value?.accessToken, jwt(expired: true));
    },
  );
  test(
    'cold restart and repeated resume calls deduplicate restoration',
    () async {
      final store = MemorySessionStore()..value = saved();
      var calls = 0;
      final first = owner(store, (_) async {
        calls++;
        return jsonResponse(profile());
      });
      await first.restore();
      final pending = Completer<http.Response>();
      final restarted = owner(store, (_) {
        calls++;
        return pending.future;
      });
      expect(restarted.current, null);
      final restore = restarted.restore();
      final resume = restarted.resume();
      final again = restarted.restore();
      expect(identical(restore, resume), true);
      expect(identical(restore, again), true);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
      pending.complete(jsonResponse(profile()));
      await Future.wait([restore, resume, again]);
      expect(restarted.phase, SessionPhase.authenticated);
    },
  );
  test(
    'delayed refresh cannot overwrite a newer profile-validation token',
    () async {
      final store = MemorySessionStore()..value = saved();
      final me = Completer<http.Response>();
      final refresh = Completer<http.Response>();
      final profileAccess = jwt(marker: 'profile-newer');
      final session = owner(store, (r) async {
        if (r.url.path.endsWith('/me')) return me.future;
        if (r.url.path.endsWith('/refresh')) return refresh.future;
        if (r.headers['authorization'] == 'Bearer ${jwt()}') {
          return jsonResponse({'detail': 'expired'}, 401);
        }
        expect(r.headers['authorization'], 'Bearer $profileAccess');
        return jsonResponse({'ok': true});
      });
      final restoration = session.restore();
      await Future<void>.delayed(Duration.zero);
      final request = session.request('GET', '/api/v1/portal/dashboard');
      await Future<void>.delayed(Duration.zero);
      me.complete(jsonResponse(profile(access: profileAccess)));
      await restoration;
      refresh.complete(
        jsonResponse({'access_token': jwt(marker: 'refresh-older')}),
      );
      await request;
      expect(store.value?.accessToken, profileAccess);
      expect(session.current?.accessToken, profileAccess);
    },
  );
  test(
    'malformed profile is a retryable server error, not storage corruption',
    () async {
      final store = MemorySessionStore()..value = saved();
      final session = owner(
        store,
        (_) async => jsonResponse({'user': profile()}),
      );
      await session.restore();
      expect(session.issue?.code, 'INVALID_RESPONSE');
      expect(session.phase, SessionPhase.unavailable);
      expect(store.value, isNotNull);
    },
  );
  test('explicitly empty API origin retains recoverable credentials', () async {
    final store = MemorySessionStore()..value = saved();
    final session = AuthSession(
      store: store,
      now: () => clock,
      repository: AuthRepository(store: store, origin: Uri()),
    );
    await session.restore();
    expect(session.issue?.code, 'API_NOT_CONFIGURED');
    expect(store.value, isNotNull);
    expect(session.phase, SessionPhase.unavailable);
    session.repository.close();
  });
}
