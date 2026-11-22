import 'package:app_flutter/src/core/auth_repository.dart';
import 'package:app_flutter/src/features/admin/creo_admin/admin_api_service.dart';
import 'package:app_flutter/src/features/admin/creo_admin/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'auth_contract_test.dart' show MemorySessionStore;
import 'session_lifecycle_test.dart' show owner, saved, profile, jsonResponse;

void main() {
  test(
    'staff provisioning sends the stable backend role and supports mail suppression',
    () async {
      final store = MemorySessionStore()..value = saved();
      final seen = <http.Request>[];
      final session = owner(store, (request) async {
        if (request.url.path.endsWith('/auth/me')) {
          return jsonResponse(profile());
        }
        seen.add(request);
        return jsonResponse({
          'id': 'staff-1',
          'email_delivered': false,
          'credentials': {'password': 'temporary-secret'},
        });
      });
      await session.restore();
      final api = AdminApiService(session);

      final result = await api.createStaff({
        'full_name': 'Casey Member',
        'email': 'casey@example.test',
        'role': 'designer',
        'send_email': false,
      });

      expect(seen.single.method, 'POST');
      expect(seen.single.url.path, '/api/v1/admin/teams');
      expect(seen.single.body, contains('"role":"designer"'));
      expect(seen.single.body, contains('"send_email":false'));
      expect(result['credentials'], contains('password'));
      expect(
        api.team,
        isEmpty,
      ); // Provision responses are not stored in the roster cache.
      session.dispose();
    },
  );

  test(
    'an ambiguous create is blocked until a successful roster refresh',
    () async {
      final store = MemorySessionStore()..value = saved();
      var failCreate = true;
      final session = owner(store, (request) async {
        if (request.url.path.endsWith('/auth/me')) {
          return jsonResponse(profile());
        }
        if (request.url.path == '/api/v1/admin/teams' &&
            request.method == 'POST' &&
            failCreate) {
          return jsonResponse({'detail': 'upstream timeout'}, 500);
        }
        if (request.url.path == '/api/v1/admin/teams' &&
            request.method == 'GET') {
          return jsonResponse(<Object>[]);
        }
        if (request.url.path == '/api/v1/admin/teams' &&
            request.method == 'POST') {
          return jsonResponse({'id': 'staff-2', 'email_delivered': false});
        }
        return jsonResponse({});
      });
      await session.restore();
      final api = AdminApiService(session);
      final body = {
        'full_name': 'Casey Member',
        'email': 'casey@example.test',
        'role': 'editor',
        'send_email': false,
      };

      await expectLater(api.createStaff(body), throwsA(isA<HttpError>()));
      await expectLater(api.createStaff(body), throwsA(isA<StateError>()));
      failCreate = false;
      await api.fetchTeam();
      expect((await api.createStaff(body))['id'], 'staff-2');
      session.dispose();
    },
  );

  test('an empty server client list clears stale local client rows', () async {
    final store = MemorySessionStore()..value = saved();
    final session = owner(store, (request) async {
      if (request.url.path.endsWith('/auth/me')) return jsonResponse(profile());
      if (request.url.path == '/api/v1/admin/clients') {
        return jsonResponse(<Object>[]);
      }
      return jsonResponse({});
    });
    await session.restore();
    clients.add(Client(name: 'stale account'));
    await AdminApiService(session).fetchClients();
    expect(clients, isEmpty);
    session.dispose();
  });
}
