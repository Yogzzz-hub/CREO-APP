import 'dart:async';
import 'dart:convert';

import 'package:app_flutter/main.dart';
import 'package:app_flutter/src/core/app_appearance.dart';
import 'package:app_flutter/src/features/admin/creo_admin/admin_shell.dart';
import 'package:app_flutter/src/features/bde/creo_bde/bde_shell.dart';
import 'package:app_flutter/src/features/bde/creo_bde/data.dart' as bde;
import 'package:app_flutter/src/features/freelancer/freelancer_workspace_page.dart';
import 'package:app_flutter/src/features/portal/client_api_service.dart';
import 'package:app_flutter/src/features/portal/client_portal_screen.dart';
import 'package:app_flutter/src/features/portal/portal_repository.dart';
import 'package:app_flutter/src/features/portal/screens/settings/account_settings_screen.dart';
import 'package:app_flutter/src/features/team_lead/team_lead_page.dart';
import 'package:app_flutter/src/features/workstation/member_workspace_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'auth_contract_test.dart' show MemorySessionStore, code;
import 'client_portal_access_test.dart' show readyPortalResponse;
import 'session_lifecycle_test.dart' show owner, saved, profile, jsonResponse;
import 'team_lead_test.dart' show pod;
import 'workstation_hub_test.dart' show hubOwner;

void main() {
  testWidgets(
    'unconnected account actions cannot claim server changes or enable 2FA',
    (tester) async {
      var requests = 0;
      final session = await hubOwner((_) async {
        requests++;
        return jsonResponse({});
      }, role: 'client');
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountSettingsScreen(
              session: session,
              onToggleTheme: () {},
              onSignOut: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save Profile Changes'));
      await tester.tap(find.text('Save Profile Changes'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Your changes have not been saved.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.ensureVisible(find.text('Security'));
      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();
      final twoFactor = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(twoFactor.onChanged, isNull);
      expect(twoFactor.value, isFalse);
      await tester.ensureVisible(find.text('Revoke others'));
      await tester.tap(find.text('Revoke others'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No other sessions were revoked.'),
        findsOneWidget,
      );
      expect(requests, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  const destinations = {
    'admin': AdminShellScreen,
    'super_admin': AdminShellScreen,
    'bde': BdeShellScreen,
    'sales': BdeShellScreen,
    'bde_head': BdeShellScreen,
    'client': ClientPortalScreen,
    'client_owner': ClientPortalScreen,
    'editor': MemberWorkspaceShell,
    'designer': MemberWorkspaceShell,
    'freelancer': FreelancerWorkspacePage,
    'team_lead': TeamLeadPage,
  };

  for (final entry in destinations.entries) {
    for (final light in [false, true]) {
      testWidgets('${entry.key}: main app tabs and logout, light=$light', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = MemorySessionStore()..value = saved();
        final paths = <String>[];
        final session = owner(store, (request) async {
          paths.add(request.url.path);
          final access = readyPortalResponse(request);
          if (access != null) return access;
          if (request.url.path.endsWith('/auth/me') ||
              request.url.path.endsWith('/users/me')) {
            return jsonResponse({
              ...profile(),
              'role': entry.key,
              'onboarding_stage': 8,
            });
          }
          if (request.url.path.endsWith('/pod-dashboard'))
            return jsonResponse(pod());
          return jsonResponse({'items': []});
        });
        final appearance = CreoAppearance(
          read: () async => light ? 'light' : 'dark',
          write: (_) async {},
        );
        await appearance.restore();
        await session.restore();
        await tester.pumpWidget(
          CreoApp(
            session: session,
            appearance: appearance,
            initialRoute: '/login',
          ),
        );
        Future<void> advance() async {
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 300));
          }
        }

        await advance();
        expect(find.byType(entry.value), findsOneWidget);
        expect(
          Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
          light ? Brightness.light : Brightness.dark,
        );
        expect(find.byKey(const Key('login-email')), findsNothing);
        expect(tester.takeException(), isNull);
        final navigation = find.byType(NavigationBar);
        if (navigation.evaluate().isNotEmpty) {
          final labels = tester
              .widget<NavigationBar>(navigation)
              .destinations
              .whereType<NavigationDestination>()
              .map((d) => d.label)
              .toList();
          for (final label in labels) {
            await tester.tap(
              find.descendant(of: navigation, matching: find.text(label)).last,
            );
            await advance();
            expect(
              tester.takeException(),
              isNull,
              reason: '${entry.key}/$label',
            );
          }
        }
        expect(paths, contains('/api/v1/auth/me'));
        if (['bde', 'sales', 'bde_head'].contains(entry.key)) {
          bde.leads.add(
            bde.Lead(
              name: 'Private previous-account lead',
              company: 'Test brand',
            ),
          );
          bde.channels.first.messages.add(
            bde.Msg('Test account', 'Private draft'),
          );
        }
        await session.logout(notifyServer: false);
        await advance();
        expect(find.byType(entry.value), findsNothing);
        expect(find.byKey(const Key('login-email')), findsOneWidget);
        expect(store.value, isNull);
        if (['bde', 'sales', 'bde_head'].contains(entry.key)) {
          expect(bde.leads, isEmpty);
          expect(
            bde.channels.every((channel) => channel.messages.isEmpty),
            isTrue,
          );
          expect(currentBdeApi, isNull);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        session.dispose();
        appearance.dispose();
      });
    }
  }

  test(
    'client owner uses the same portal boundary; staff cannot read it',
    () async {
      final client = await hubOwner(
        (_) async => jsonResponse({'full_name': 'Client'}),
        role: 'client_owner',
      );
      addTearDown(client.dispose);
      expect((await PortalRepository(client).profile())['full_name'], 'Client');
      var requests = 0;
      final staff = await hubOwner((_) async {
        requests++;
        return jsonResponse({});
      });
      addTearDown(staff.dispose);
      await expectLater(
        ClientApiService(staff).fetchDashboard(),
        throwsA(code('PORTAL_FORBIDDEN')),
      );
      expect(requests, 0);
    },
  );

  test(
    'client review rejects duplicate and unconfirmed approval responses',
    () async {
      final pending = Completer<http.Response>();
      var requests = 0;
      final session = await hubOwner((request) {
        requests++;
        expect(request.headers['idempotency-key'], isNotEmpty);
        return pending.future;
      }, role: 'client');
      addTearDown(session.dispose);
      final api = ClientApiService(session);
      final first = api.approveDeliverable('asset-a');
      final assertion = expectLater(first, throwsA(code('WRITE_UNCONFIRMED')));
      await expectLater(
        api.approveDeliverable('asset-a'),
        throwsA(code('WRITE_UNCONFIRMED')),
      );
      pending.complete(
        jsonResponse({
          'status': 'approved',
          'deliverable_id': 'different-asset',
        }),
      );
      await assertion;
      expect(requests, 1);
    },
  );

  test(
    'client review rejects HTTP-200 application errors and keeps exact contract',
    () async {
      final session = await hubOwner((request) async {
        expect(
          request.url.path,
          '/api/v1/deliverables/asset-a/request-changes',
        );
        expect(jsonDecode(request.body), {'rejection_comment': 'Adjust title'});
        return jsonResponse({
          'status': 'error',
          'message': 'Revision rejected',
        });
      }, role: 'client');
      addTearDown(session.dispose);
      await expectLater(
        ClientApiService(session).requestChanges('asset-a', ' Adjust title '),
        throwsA(code('VALIDATION_FAILED')),
      );
    },
  );
}
