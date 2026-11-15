import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/src/features/admin/creo_admin/sales_workspace.dart';
import 'package:app_flutter/src/features/admin/creo_admin/save_csv.dart';
import 'package:app_flutter/src/features/admin/creo_admin/admin_api_service.dart';
import 'package:app_flutter/src/features/admin/creo_admin/data.dart' as admin;
import 'package:app_flutter/src/features/workstation/workstation_files.dart';
import 'auth_contract_test.dart' show MemorySessionStore, code;
import 'session_lifecycle_test.dart' show owner, saved, profile, jsonResponse;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'client offboarding requires a loaded UUID and confirmed response',
    () async {
      final store = MemorySessionStore()..value = saved();
      var writes = 0;
      final session = owner(store, (request) async {
        if (request.url.path.endsWith('/auth/me'))
          return jsonResponse({...profile(), 'role': 'admin'});
        if (request.method == 'GET') return jsonResponse([]);
        writes++;
        expect(request.url.path, '/api/v1/admin/clients/client-a/offboard');
        return jsonResponse({'status': 'offboarded', 'client_id': 'client-a'});
      });
      await session.restore();
      final api = AdminApiService(session);
      admin.clients.add(admin.Client(name: 'Example')..serverId = 'client-a');
      addTearDown(admin.clients.clear);
      await expectLater(api.offboardClient('unknown'), throwsStateError);
      await api.offboardClient('client-a');
      expect(writes, 1);
      expect(admin.clients, isEmpty);
    },
  );
  test(
    'CSV export requests an OS save and reports cancellation honestly',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(WorkstationFileTransfer.channel, (
        call,
      ) async {
        expect(call.method, 'save');
        expect(call.arguments['name'], 'transactions.csv');
        expect(call.arguments['mimeType'], 'text/csv');
        expect(utf8.decode(call.arguments['bytes']), 'Name,Amount\nExample,25');
        return false;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          WorkstationFileTransfer.channel,
          null,
        ),
      );
      expect(
        await saveCsv('transactions.csv', 'Name,Amount\nExample,25'),
        'Save cancelled',
      );
    },
  );
  test(
    'admin lead changes use loaded identities and confirmed backend IDs',
    () async {
      final store = MemorySessionStore()..value = saved();
      final session = owner(store, (request) async {
        if (request.url.path.endsWith('/auth/me'))
          return jsonResponse({...profile(), 'role': 'admin'});
        if (request.method == 'GET')
          return jsonResponse([
            {'id': 'lead-a', 'company_name': 'Example', 'status': 'new'},
          ]);
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/v1/bde/leads/lead-a');
        expect(jsonDecode(request.body), {'status': 'contacted'});
        return jsonResponse({'id': 'lead-a', 'status': 'contacted'});
      });
      await session.restore();
      final repo = AdminSalesRepository(session);
      final row = (await repo.load()).single;
      await expectLater(
        repo.update(Map.from(row), 'contacted'),
        throwsA(code('STALE_LEAD')),
      );
      await repo.update(row, 'contacted');
      await session.logout(notifyServer: false);
      await expectLater(repo.load(), throwsA(code('FORBIDDEN')));
    },
  );
  test(
    'unconfirmed lead creation remains blocked across reopened pages',
    () async {
      final store = MemorySessionStore()..value = saved();
      var writes = 0;
      final session = owner(store, (request) async {
        if (request.url.path.endsWith('/auth/me'))
          return jsonResponse({...profile(), 'role': 'super_admin'});
        writes++;
        return jsonResponse({}, 500);
      });
      await session.restore();
      final fields = {
        'name': 'Example',
        'company_name': 'Example',
        'email': 'qa@example.test',
      };
      await expectLater(
        AdminSalesRepository(session).create(fields),
        throwsA(code('WRITE_UNCONFIRMED')),
      );
      await expectLater(
        AdminSalesRepository(session).create(fields),
        throwsA(code('WRITE_UNCONFIRMED')),
      );
      expect(writes, 1);
    },
  );
}
