import 'dart:async';
import 'dart:convert';
import 'package:app_flutter/src/features/portal/portal_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'auth_contract_test.dart' show MemorySessionStore, code;
import 'session_lifecycle_test.dart' show owner, saved, profile, jsonResponse;
import 'workstation_hub_test.dart' show hubOwner;

void main() {
  test(
    'profile, password, ticket and calendar contracts use real paths and fields',
    () async {
      final requests = <http.Request>[];
      final session = await hubOwner((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/comment')) {
          return jsonResponse({'status': 'comment_received'});
        }
        return jsonResponse({'status': 'success', 'id': 'saved'});
      }, role: 'client');
      addTearDown(session.dispose);
      final repo = PortalRepository(session);
      await repo.saveProfile({
        'full_name': 'Updated client',
        'phone': '+910000000000',
      });
      expect(requests.last.method, 'PUT');
      expect(jsonDecode(requests.last.body)['phone'], '+910000000000');
      await repo.changePassword(' old password ', ' new password ');
      expect(jsonDecode(requests.last.body), {
        'current_password': ' old password ',
        'new_password': ' new password ',
      });
      await repo.createTicket('Support', 'Need assistance', 'medium');
      expect(requests.last.url.path, '/api/v1/tickets');
      expect(jsonDecode(requests.last.body), {
        'title': 'Support',
        'description': 'Need assistance',
        'priority': 'medium',
      });
      await repo.commentCycle('cycle-a', 'Change caption', slot: 'slot-a');
      expect(requests.last.url.path, '/api/v1/portal/cycles/cycle-a/comment');
      expect(jsonDecode(requests.last.body), {
        'body': 'Change caption',
        'slot_id': 'slot-a',
      });
    },
  );

  test('HTTP 200 application error never becomes a success', () async {
    final session = await hubOwner(
      (_) async => jsonResponse({
        'status': 'error',
        'message': 'Current password is incorrect.',
      }),
      role: 'client',
    );
    addTearDown(session.dispose);
    await expectLater(
      PortalRepository(session).changePassword('wrong', 'next password'),
      throwsA(code('VALIDATION_FAILED')),
    );
  });

  test(
    'concurrent and uncertain writes are blocked across reopened repositories',
    () async {
      var writes = 0;
      final pending = Completer<http.Response>();
      final session = await hubOwner((_) {
        writes++;
        return pending.future;
      }, role: 'client');
      addTearDown(session.dispose);
      final first = PortalRepository(
        session,
      ).createTicket('Help', 'Please assist', 'medium');
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        PortalRepository(
          session,
        ).createTicket('Help', 'Please assist', 'medium'),
        throwsA(code('WRITE_UNCONFIRMED')),
      );
      pending.complete(jsonResponse({'detail': 'Unavailable'}, 503));
      await expectLater(first, throwsA(code('WRITE_UNCONFIRMED')));
      await expectLater(
        PortalRepository(
          session,
        ).createTicket('Help', 'Please assist', 'medium'),
        throwsA(code('WRITE_UNCONFIRMED')),
      );
      expect(writes, 1);
    },
  );

  test('portal rejects staff access and stale account reads', () async {
    var reads = 0;
    final staff = await hubOwner((_) async {
      reads++;
      return jsonResponse({});
    });
    await expectLater(
      PortalRepository(staff).profile(),
      throwsA(code('PORTAL_FORBIDDEN')),
    );
    expect(reads, 0);
    staff.dispose();
    final result = Completer<http.Response>();
    final store = MemorySessionStore()..value = saved();
    final session = owner(
      store,
      (request) async => request.url.path.endsWith('/auth/me')
          ? jsonResponse({...profile(), 'role': 'client'})
          : result.future,
    );
    await session.restore();
    final read = PortalRepository(session).profile();
    final assertion = expectLater(read, throwsA(anything));
    await session.logout(notifyServer: false);
    result.complete(jsonResponse({'full_name': 'Late private data'}));
    await assertion;
    session.dispose();
  });
}
