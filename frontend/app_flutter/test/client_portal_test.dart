import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:app_flutter/src/features/portal/client_portal_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/src/features/portal/client_api_service.dart';
import 'package:app_flutter/src/features/portal/models/dashboard_model.dart';
import 'package:app_flutter/src/features/portal/models/deliverable_model.dart';
import 'package:app_flutter/src/features/portal/screens/review/deliverables_review_screen.dart' show reviewDateLabel;
import 'auth_contract_test.dart' show MemorySessionStore;
import 'client_portal_access_test.dart' show readyPortalResponse;
import 'session_lifecycle_test.dart' show owner, saved, profile, jsonResponse;

void main() {
  test('review cards show a readable date, not the raw timestamp', () {
    final when = DateTime.parse('2030-01-02T10:05:00Z').toLocal();
    final hh = when.hour.toString().padLeft(2, '0');
    final mm = when.minute.toString().padLeft(2, '0');
    expect(reviewDateLabel('2030-01-02T10:05:00Z'), '${when.day} Jan, $hh:$mm');
    expect(reviewDateLabel(null), 'Not scheduled');
    expect(reviewDateLabel(''), 'Not scheduled');
    expect(reviewDateLabel('next week'), 'next week');
  });

  test(
    'deliverables follow server cursor without losing earlier pages',
    () async {
      final store = MemorySessionStore()..value = saved();
      final session = owner(store, (request) async {
        if (request.url.path.endsWith('/auth/me')) {
          return jsonResponse(profile());
        }
        if (request.url.queryParameters['cursor_id'] == 'asset-a') {
          return jsonResponse({
            'items': [
              {'id': 'asset-b'},
            ],
            'has_more': false,
          });
        }
        return jsonResponse({
          'items': [
            {'id': 'asset-a'},
          ],
          'has_more': true,
        });
      });
      await session.restore();
      expect(
        (await ClientApiService(
          session,
        ).fetchDeliverables()).map((item) => item.id),
        ['asset-a', 'asset-b'],
      );
      session.dispose();
    },
  );
  testWidgets('client shell renders empty server data on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemorySessionStore()..value = saved();
    final session = owner(store, (request) async {
      if (request.url.path.endsWith('/auth/me')) {
        return jsonResponse({...profile(), 'role': 'client'});
      }
      final access = readyPortalResponse(request);
      if (access != null) return access;
      return jsonResponse(
        request.url.path.endsWith('/deliverables') ? {'items': []} : {},
      );
    });
    await session.restore();
    await tester.pumpWidget(
      MaterialApp(home: ClientPortalScreen(session: session)),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ClientPortalScreen), findsOneWidget);
    expect(find.text('Good morning'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });

  test(
    'all standalone screens and shared widgets have migrated counterparts',
    () {
      for (final folder in ['screens', 'widgets', 'models']) {
        final source = Directory('../../client portal/lib/$folder');
        expect(source.existsSync(), isTrue);
        for (final file in source.listSync(recursive: true).whereType<File>()) {
          if (!file.path.endsWith('.dart')) continue;
          final suffix = file.path.substring(source.path.length);
          expect(
            File('lib/src/features/portal/$folder$suffix').existsSync(),
            isTrue,
            reason: file.path,
          );
        }
      }
    },
  );

  test(
    'dashboard reads actual backend fields without sample quota defaults',
    () {
      final data = DashboardData.fromJson({
        'pending_deliverable_count': 7,
        'open_ticket_count': 2,
        'ai_summary_line': 'Server summary',
        'active_plan': {'name': 'Server plan', 'tier': 'custom'},
        'quotas': {
          'reel': {'quota': 12, 'used': 3, 'remaining': 9},
        },
      });
      expect(data.pendingDeliverableCount, 7);
      expect(data.brandSummary, 'Server summary');
      expect(data.planName, 'Server plan');
      expect(data.reelsQuota.remaining, 9);
      expect(data.postersQuota.quota, 0);
      expect(DashboardData.fromJson({}).planName, isNull);
    },
  );

  test('deliverable preserves media, revision allowance and server date', () {
    final item = DeliverableItem.fromJson({
      'id': 'asset-a',
      'type_label': 'Carousel',
      'revisions_allowed': 5,
      'file_url': 'https://media.example.test/asset',
      'scheduled_at': '2030-01-02T10:00:00Z',
    });
    expect(item.formatLabel, 'Carousel');
    expect(item.maxRevisions, 5);
    expect(item.fileUrl, 'https://media.example.test/asset');
    expect(item.scheduledDate, '2030-01-02T10:00:00Z');
  });

  test(
    'review submits server rejection_comment and empty refresh clears items',
    () async {
      final store = MemorySessionStore()..value = saved();
      var empty = false;
      final session = owner(store, (request) async {
        if (request.url.path.endsWith('/auth/me')) {
          return jsonResponse(profile());
        }
        if (request.method == 'POST') {
          expect(
            request.url.path,
            '/api/v1/deliverables/asset-a/request-changes',
          );
          expect(jsonDecode(request.body), {'rejection_comment': 'Fix title'});
          return jsonResponse({
            'status': 'revision_requested',
            'deliverable_id': 'asset-a',
          });
        }
        return jsonResponse({
          'items': empty
              ? []
              : [
                  {'id': 'asset-a'},
                ],
        });
      });
      await session.restore();
      final api = ClientApiService(session);
      expect(await api.fetchDeliverables(), hasLength(1));
      await api.requestChanges('asset-a', ' Fix title ');
      empty = true;
      expect(await api.fetchDeliverables(), isEmpty);
      session.dispose();
    },
  );

  test('failed load is exposed and retains server data', () async {
    final store = MemorySessionStore()..value = saved();
    final session = owner(
      store,
      (request) async => request.url.path.endsWith('/auth/me')
          ? jsonResponse(profile())
          : jsonResponse({'detail': 'Unavailable'}, 503),
    );
    await session.restore();
    final api = ClientApiService(session);
    await api.refreshAll();
    expect(api.error, isNotNull);
    expect(api.isLoading, isFalse);
    expect(api.liveDashboard, isNull);
    session.dispose();
  });
}
