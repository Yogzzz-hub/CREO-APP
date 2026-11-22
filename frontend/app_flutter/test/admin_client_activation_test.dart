import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:app_flutter/src/features/admin/creo_admin/admin_api_service.dart';
import 'package:app_flutter/src/features/admin/creo_admin/client_access_page.dart';
import 'package:app_flutter/src/features/admin/creo_admin/data.dart' as admin;
import 'auth_contract_test.dart' show MemorySessionStore;
import 'session_lifecycle_test.dart' show owner, saved, profile, jsonResponse;

const clientId = 'client-a';
const planId = 'plan-a';
Map<String, dynamic> detail({bool active = false}) => {
  'client_id': clientId,
  'email': 'client@example.test',
  'onboarding_completed_at': null,
  'subscription': active
      ? {'status': 'active', 'plan_display_name': 'Server plan'}
      : null,
};
final plans = [
  {
    'id': planId,
    'name': 'server',
    'display_name': 'Server plan',
    'monthly_price': '1200.00',
  },
];
void main() {
  tearDown(admin.clients.clear);
  test(
    'roster uses backend client_id, plan and price without sample defaults',
    () async {
      final session = owner(MemorySessionStore()..value = saved(), (
        request,
      ) async {
        if (request.url.path.endsWith('/auth/me')) {
          return jsonResponse({...profile(), 'role': 'admin'});
        }
        return jsonResponse([
          {
            'client_id': clientId,
            'email': 'client@example.test',
            'plan_display_name': 'Server plan',
            'monthly_price': '1200.00',
            'derived_onboarding_stage': 3,
          },
        ]);
      });
      await session.restore();
      final existing = admin.Client(name: 'Old label')..serverId = clientId;
      admin.clients.add(existing);
      await AdminApiService(session).fetchClients();
      expect(identical(admin.clients.single, existing), isTrue);
      expect(admin.clients.single.serverId, clientId);
      expect(admin.clients.single.plan, 'Server plan');
      expect(admin.clients.single.fee, 1200);
      expect(admin.clients.single.paid, isTrue);
      session.dispose();
    },
  );

  test(
    'activation sends existing server contract once and needs loaded plan',
    () async {
      var writes = 0;
      final pending = Completer<http.Response>();
      final session = owner(MemorySessionStore()..value = saved(), (
        request,
      ) async {
        if (request.url.path.endsWith('/auth/me')) {
          return jsonResponse({...profile(), 'role': 'admin'});
        }
        if (request.method == 'POST') {
          writes++;
          expect(
            request.url.path,
            '/api/v1/admin/clients/client-a/bypass-payment',
          );
          expect(jsonDecode(request.body), {
            'plan_id': planId,
            'payment_method': 'test_access',
            'notes': 'Test only',
          });
          return pending.future;
        }
        if (request.url.path.endsWith('/plans')) {
          expect(request.url.queryParameters['client_id'], clientId);
          return jsonResponse(plans);
        }
        if (request.url.path.endsWith('/clients')) return jsonResponse([]);
        return jsonResponse(detail());
      });
      await session.restore();
      final api = AdminApiService(session);
      await expectLater(
        api.activateClient(clientId, planId, 'test_access', 'Test only'),
        throwsStateError,
      );
      await api.clientAccess(clientId);
      final first = api.activateClient(
        clientId,
        planId,
        'test_access',
        'Test only',
      );
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        api.activateClient(clientId, planId, 'test_access', 'Test only'),
        throwsStateError,
      );
      pending.complete(
        jsonResponse({
          'status': 'success',
          'client_id': clientId,
          'subscription_id': 'subscription-a',
        }),
      );
      await first;
      await expectLater(
        api.activateClient(clientId, planId, 'test_access', 'Test only'),
        throwsStateError,
      );
      expect(writes, 1);
      session.dispose();
    },
  );

  test(
    'unconfirmed response blocks duplicate activation and staff is rejected',
    () async {
      var writes = 0;
      var role = 'admin';
      final session = owner(MemorySessionStore()..value = saved(), (
        request,
      ) async {
        if (request.url.path.endsWith('/auth/me')) {
          return jsonResponse({...profile(), 'role': role});
        }
        if (request.method == 'POST') {
          writes++;
          return jsonResponse({});
        }
        return jsonResponse(
          request.url.path.endsWith('/plans') ? plans : detail(),
        );
      });
      await session.restore();
      final api = AdminApiService(session);
      await api.clientAccess(clientId);
      await expectLater(
        api.activateClient(clientId, planId, 'cash', 'Reference'),
        throwsStateError,
      );
      await expectLater(
        api.activateClient(clientId, planId, 'cash', 'Reference'),
        throwsStateError,
      );
      expect(writes, 1);
      role = 'editor';
      await session.restore();
      await expectLater(
        AdminApiService(session).clientAccess(clientId),
        throwsStateError,
      );
      session.dispose();
    },
  );

  test(
    'server activation remains active after logout and a new admin login',
    () async {
      var serverActive = false, writes = 0;
      Future<http.Response> transport(http.Request request) async {
        if (request.url.path.endsWith('/auth/me')) {
          return jsonResponse({...profile(), 'role': 'admin'});
        }
        if (request.method == 'POST') {
          writes++;
          serverActive = true;
          return jsonResponse({
            'status': 'success',
            'client_id': clientId,
            'subscription_id': 'sub-a',
          });
        }
        if (request.url.path.endsWith('/plans')) return jsonResponse(plans);
        if (request.url.path.endsWith('/clients')) {
          return jsonResponse([
            {
              'client_id': clientId,
              'email': 'client@example.test',
              'subscription_status': serverActive ? 'active' : null,
              'derived_onboarding_stage': 2,
            },
          ]);
        }
        return jsonResponse(detail(active: serverActive));
      }

      final first = owner(MemorySessionStore()..value = saved(), transport);
      await first.restore();
      final api = AdminApiService(first);
      await api.fetchClients();
      expect(admin.clients.single.paid, isFalse);
      await api.clientAccess(clientId);
      await api.activateClient(clientId, planId, 'test_access', 'Test access');
      expect(admin.clients.single.paid, isTrue);
      await first.logout(notifyServer: false);
      first.dispose();
      admin.clients.clear();
      final next = owner(MemorySessionStore()..value = saved(), transport);
      await next.restore();
      await AdminApiService(next).fetchClients();
      expect(admin.clients.single.paid, isTrue);
      expect(writes, 1);
      next.dispose();
    },
  );

  for (final status in ['canceled', 'incomplete', 'past_due', null]) {
    test(
      'explicit subscription status $status overrides stale onboarding progress',
      () async {
        final session = owner(MemorySessionStore()..value = saved(), (
          request,
        ) async {
          if (request.url.path.endsWith('/auth/me')) {
            return jsonResponse({...profile(), 'role': 'admin'});
          }
          return jsonResponse([
            {
              'client_id': clientId,
              'subscription_status': status,
              'derived_onboarding_stage': 8,
            },
          ]);
        });
        await session.restore();
        await AdminApiService(session).fetchClients();
        expect(admin.clients.single.paid, isFalse);
        session.dispose();
      },
    );
  }

  testWidgets(
    'test activation requires explicit confirmation and shows server status',
    (tester) async {
      var active = false, writes = 0;
      final session = owner(MemorySessionStore()..value = saved(), (
        request,
      ) async {
        if (request.url.path.endsWith('/auth/me')) {
          return jsonResponse({...profile(), 'role': 'admin'});
        }
        if (request.method == 'POST') {
          writes++;
          expect(
            jsonDecode(request.body)['notes'],
            startsWith('TEST ACCESS - NO PAYMENT RECEIVED.'),
          );
          active = true;
          return jsonResponse({
            'status': 'success',
            'client_id': clientId,
            'subscription_id': 'sub-a',
          });
        }
        if (request.url.path.endsWith('/plans')) return jsonResponse(plans);
        if (request.url.path.endsWith('/clients')) return jsonResponse([]);
        return jsonResponse(detail(active: active));
      });
      await session.restore();
      await tester.pumpWidget(
        MaterialApp(
          home: ClientAccessPage(
            api: AdminApiService(session),
            clientId: clientId,
            email: 'client@example.test',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Server plan · ₹1200.00').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<String>).last,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test access — no payment received').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'QA requested');
      await tester.ensureVisible(find.text('Review activation'));
      await tester.tap(find.text('Review activation'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(
        find.textContaining('sends a payment-approved email'),
        findsOneWidget,
      );
      await tester.tap(find.text('Confirm activation'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.text('Subscription active'), findsOneWidget);
      expect(
        find.textContaining('Activation confirmed by the server.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
