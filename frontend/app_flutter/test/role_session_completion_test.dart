import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:app_flutter/src/core/auth_repository.dart';
import 'package:app_flutter/src/core/auth_session.dart';
import 'auth_contract_test.dart' show MemorySessionStore, sessionJson, code;
import 'session_lifecycle_test.dart'
    show owner, saved, profile, jsonResponse, jwt;

void main() {
  test(
    'mandatory password uses restricted token and exact password bytes',
    () async {
      final store = MemorySessionStore()..value = saved();
      final session = owner(store, (request) async {
        if (request.url.path.endsWith('/me'))
          return jsonResponse(profile(restricted: true));
        expect(request.url.path, '/api/v1/auth/set-mandatory-password');
        expect(request.headers['authorization'], 'Bearer ${jwt()}');
        expect(jsonDecode(request.body), {'new_password': '  Exact123!  '});
        return jsonResponse({
          ...sessionJson(),
          'access_token': jwt(marker: 'updated'),
        });
      });
      await session.restore();
      await session.setMandatoryPassword('  Exact123!  ');
      expect(session.current!.user.mustResetPassword, isNot(true));
      expect(store.value!.accessToken, jwt(marker: 'updated'));
    },
  );
  test(
    'logout prevents late reset adoption and duplicate reset requests',
    () async {
      final pending = Completer<http.Response>();
      var calls = 0;
      final store = MemorySessionStore()..value = saved();
      final session = owner(store, (request) async {
        if (request.url.path.endsWith('/me'))
          return jsonResponse(profile(restricted: true));
        calls++;
        return pending.future;
      });
      await session.restore();
      final update = session.setMandatoryPassword('Exact123!');
      final rejected = expectLater(update, throwsA(code('SESSION_CANCELLED')));
      await expectLater(
        session.setMandatoryPassword('Other123!'),
        throwsA(code('REQUEST_PENDING')),
      );
      await session.logout(notifyServer: false);
      pending.complete(jsonResponse(sessionJson()));
      await rejected;
      expect(calls, 1);
      expect(store.value, isNull);
      expect(session.current, isNull);
    },
  );
  test(
    'mandatory password renews an expired restricted access token first',
    () async {
      final store = MemorySessionStore()..value = saved(expired: true);
      var refreshes = 0;
      final renewed = jwt(marker: 'renewed');
      final session = owner(store, (request) async {
        if (request.url.path.endsWith('/refresh')) {
          refreshes++;
          return jsonResponse({'access_token': renewed});
        }
        if (request.url.path.endsWith('/me')) {
          expect(request.headers['authorization'], 'Bearer $renewed');
          return jsonResponse(profile(restricted: true));
        }
        expect(request.url.path, '/api/v1/auth/set-mandatory-password');
        expect(request.headers['authorization'], 'Bearer $renewed');
        expect(jsonDecode(request.body), {'new_password': 'Exact123!'});
        return jsonResponse({
          ...sessionJson(),
          'access_token': jwt(marker: 'updated'),
        });
      });
      await session.restore();
      await session.setMandatoryPassword('Exact123!');
      expect(refreshes, 1);
      expect(session.current!.user.mustResetPassword, isNot(true));
    },
  );
  test('resume does not race a pending mandatory password update', () async {
    final pending = Completer<http.Response>();
    final store = MemorySessionStore()..value = saved();
    var profiles = 0;
    final session = owner(store, (request) async {
      if (request.url.path.endsWith('/me')) {
        profiles++;
        return jsonResponse(profile(restricted: true));
      }
      expect(request.url.path, '/api/v1/auth/set-mandatory-password');
      return pending.future;
    });
    await session.restore();
    final update = session.setMandatoryPassword('Exact123!');
    await session.resume();
    expect(profiles, 1);
    pending.complete(
      jsonResponse({...sessionJson(), 'access_token': jwt(marker: 'updated')}),
    );
    await update;
    expect(session.phase, SessionPhase.authenticated);
    expect(session.current!.user.mustResetPassword, isNot(true));
  });
  test(
    'binary GET refreshes once and returns exact authenticated bytes',
    () async {
      final store = MemorySessionStore()..value = saved();
      var downloads = 0, refreshes = 0;
      final session = owner(store, (request) async {
        if (request.url.path.endsWith('/me')) return jsonResponse(profile());
        if (request.url.path.endsWith('/refresh')) {
          refreshes++;
          return jsonResponse({'access_token': jwt(marker: 'renewed')});
        }
        downloads++;
        if (downloads == 1) return jsonResponse({'detail': 'Expired'}, 401);
        expect(
          request.headers['authorization'],
          'Bearer ${jwt(marker: 'renewed')}',
        );
        return http.Response.bytes(
          [80, 75, 3, 4],
          200,
          headers: {
            'content-type': 'application/zip',
            'content-disposition': 'attachment; filename=approved.zip',
          },
        );
      });
      await session.restore();
      final result = await session.requestBytes(
        '/api/v1/portal/deliverables/download-zip',
      );
      expect(result.bytes, [80, 75, 3, 4]);
      expect(result.contentType, 'application/zip');
      expect(refreshes, 1);
      expect(downloads, 2);
    },
  );
  test(
    'custom idempotency header survives safe GET replay; auth overrides rejected',
    () async {
      final store = MemorySessionStore()..value = saved();
      var requests = 0;
      final session = owner(store, (request) async {
        if (request.url.path.endsWith('/me')) return jsonResponse(profile());
        if (request.url.path.endsWith('/refresh'))
          return jsonResponse({'access_token': jwt(marker: 'renewed')});
        expect(request.headers['idempotency-key'], 'operation-a');
        return ++requests == 1
            ? jsonResponse({}, 401)
            : jsonResponse({'ok': true});
      });
      await session.restore();
      await session.request(
        'GET',
        '/api/v1/example',
        headers: {'Idempotency-Key': 'operation-a'},
      );
      expect(requests, 2);
      await expectLater(
        session.request(
          'GET',
          '/api/v1/example',
          headers: {'AUTHORIZATION': 'unsafe'},
        ),
        throwsArgumentError,
      );
    },
  );
  test(
    'destinations distinguish onboarding, reset, lead and unknown roles',
    () {
      AuthUser user(String role, {int stage = 8, bool reset = false}) =>
          AuthUser.fromJson({
            ...sessionJson(role: role)['user'] as Map<String, dynamic>,
            'onboarding_stage': stage,
            'must_reset_password': reset,
          });
      expect(
        DestinationIntent.forUser(user('client', stage: 3)).path,
        '/portal',
      );
      expect(DestinationIntent.forUser(user('client')).path, '/portal');
      expect(DestinationIntent.forUser(user('team_lead')).blocker, isNull);
      expect(
        DestinationIntent.forUser(user('editor', reset: true)).path,
        '/set-mandatory-password',
      );
      expect(DestinationIntent.forUser(user('unknown')).blocker, isNotNull);
      expect(
        DestinationIntent.forUser(user('investor_relations')).blocker,
        isNotNull,
      );
    },
  );
}
