import 'dart:async';
import 'package:app_flutter/src/core/app_theme.dart';
import 'package:app_flutter/src/core/auth_session.dart';
import 'package:app_flutter/src/features/workstation/workstation_notifications_page.dart';
import 'package:app_flutter/src/features/workstation/workstation_notifications_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'auth_contract_test.dart' show MemorySessionStore, code;
import 'session_lifecycle_test.dart' show owner, saved, profile, jsonResponse;

Map<String, dynamic> notice(
  String id, {
  bool read = false,
  String? link = '/workstation/tasks?taskId=task-one',
}) => {
  'id': id,
  'title': 'Task update $id',
  'message': 'A returned notification for your account.',
  'is_read': read,
  'created_at': '2030-01-01T10:30:00Z',
  'link': link,
};
Map<String, dynamic> notices(
  List<Map<String, dynamic>> rows, {
  int? unread,
}) => {
  'unread_count': unread ?? rows.where((row) => row['is_read'] == false).length,
  'items': rows,
};
Future<AuthSession> notificationOwner(
  Future<http.Response> Function(http.Request) send, {
  String role = 'editor',
  bool restricted = false,
}) async {
  final session = owner(MemorySessionStore()..value = saved(), (request) async {
    if (request.url.path.endsWith('/auth/me')) {
      return jsonResponse({...profile(restricted: restricted), 'role': role});
    }
    return send(request);
  });
  await session.restore();
  return session;
}

void main() {
  test(
    'notification payload preserves account unread count and rejects malformed rows',
    () {
      final data = WorkstationNotifications.fromJson(
        notices([notice('n1')], unread: 37),
      );
      expect(data.unreadCount, 37);
      expect(data.items.single.createdAt, DateTime.utc(2030, 1, 1, 10, 30));
      expect(
        () => WorkstationNotifications.fromJson({'items': []}),
        throwsFormatException,
      );
      expect(
        () => WorkstationNotifications.fromJson(
          notices([notice('n1'), notice('n1')]),
        ),
        throwsFormatException,
      );
      expect(
        () => WorkstationNotifications.fromJson(
          notices([
            {...notice('n1'), 'is_read': 'false'},
          ]),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'navigation intents are role bounded and preserve only safe source parameters',
    () {
      expect(
        notificationWorkspacePath('/admin/leaves', 'freelancer'),
        '/freelancer/leave',
      );
      expect(
        notificationWorkspacePath('/admin/leave', 'designer'),
        '/workstation/schedule',
      );
      expect(
        notificationWorkspacePath(
          '/member/tasks?selected=task-one&redirect=https://evil.test',
          'editor',
        ),
        '/workstation/tasks?taskId=task-one',
      );
      expect(
        notificationWorkspacePath('/slack?dm=admin-one', 'freelancer'),
        '/slack?dm=admin-one',
      );
      expect(
        notificationWorkspacePath(
          '/workstation/chat?channel=pod-alpha-team',
          'editor',
        ),
        '/workstation/slack?channel=pod-alpha-team',
      );
      for (final link in [
        'https://example.test/workstation',
        '//example.test/workstation',
        '/platform/security',
        '/admin/clients',
        '/workstation/../admin',
        '/workstation\\tasks',
      ]) {
        expect(notificationWorkspacePath(link, 'editor'), isNull);
      }
      expect(
        notificationWorkspacePath('/workstation/tasks', 'freelancer'),
        isNull,
      );
      expect(notificationWorkspacePath('/freelancer/tasks', 'client'), isNull);
    },
  );

  test(
    'all mutation methods use verified contracts and refetch actual rows',
    () async {
      final requests = <http.Request>[];
      var rows = [notice('n1'), notice('n2')];
      final session = await notificationOwner((request) async {
        requests.add(request);
        if (request.method == 'GET') return jsonResponse(notices(rows));
        final path = request.url.path;
        if (path.endsWith('/mark-all-read')) {
          rows = rows.map((row) => {...row, 'is_read': true}).toList();
          return jsonResponse({'status': 'all_read', 'updated': rows.length});
        }
        if (request.method == 'PATCH') {
          rows = rows
              .map((row) => row['id'] == 'n1' ? {...row, 'is_read': true} : row)
              .toList();
          return jsonResponse({'status': 'read', 'id': 'n1'});
        }
        if (path.endsWith('/n2')) {
          rows = rows.where((row) => row['id'] != 'n2').toList();
          return jsonResponse({'status': 'deleted', 'id': 'n2'});
        }
        final count = rows.length;
        rows = [];
        return jsonResponse({'status': 'all_deleted', 'deleted': count});
      });
      addTearDown(session.dispose);
      final repository = WorkstationNotificationsRepository(session);
      await repository.load();
      expect((await repository.markRead('n1')).items.first.isRead, isTrue);
      expect((await repository.markAllRead()).unreadCount, 0);
      expect((await repository.delete('n2')).items.single.id, 'n1');
      expect((await repository.clearAll()).items, isEmpty);
      expect(
        requests
            .where((request) => request.method != 'GET')
            .map((request) => '${request.method} ${request.url.path}'),
        [
          'PATCH /api/v1/notifications/n1/read',
          'POST /api/v1/notifications/mark-all-read',
          'DELETE /api/v1/notifications/n2',
          'DELETE /api/v1/notifications',
        ],
      );
      expect(
        requests.every(
          (request) => request.headers.values.any(
            (value) => value.startsWith('Bearer '),
          ),
        ),
        isTrue,
      );
    },
  );

  test(
    'unknown IDs, forbidden roles and mandatory reset never write',
    () async {
      var requests = 0;
      final session = await notificationOwner((request) async {
        requests++;
        return jsonResponse(notices([]));
      });
      addTearDown(session.dispose);
      final repository = WorkstationNotificationsRepository(session);
      await repository.load();
      await expectLater(
        repository.delete('another-account'),
        throwsA(code('NOTIFICATION_UNAVAILABLE')),
      );
      expect(requests, 1);
      for (final role in ['client', 'team_member']) {
        final denied = await notificationOwner((request) async {
          requests++;
          return jsonResponse(notices([]));
        }, role: role);
        addTearDown(denied.dispose);
        await expectLater(
          WorkstationNotificationsRepository(denied).load(),
          throwsA(code('NOTIFICATIONS_FORBIDDEN')),
        );
      }
      final restricted = await notificationOwner((request) async {
        requests++;
        return jsonResponse(notices([]));
      }, restricted: true);
      addTearDown(restricted.dispose);
      await expectLater(
        WorkstationNotificationsRepository(restricted).load(),
        throwsA(code('NOTIFICATIONS_FORBIDDEN')),
      );
      expect(requests, 1);
    },
  );

  test(
    'ambiguous action blocks reopening and reconciles only observed server state',
    () async {
      var writes = 0;
      var read = false;
      final session = await notificationOwner((request) async {
        if (request.method == 'GET') {
          return jsonResponse(notices([notice('n1', read: read)]));
        }
        writes++;
        return jsonResponse({'detail': 'Unavailable'}, 503);
      });
      addTearDown(session.dispose);
      final first = WorkstationNotificationsRepository(session);
      await first.load();
      await expectLater(
        first.markRead('n1'),
        throwsA(code('NOTIFICATION_WRITE_UNCONFIRMED')),
      );
      final reopened = WorkstationNotificationsRepository(session);
      await reopened.load();
      await expectLater(
        reopened.markAllRead(),
        throwsA(code('NOTIFICATION_WRITE_UNCONFIRMED')),
      );
      expect(writes, 1);
      read = true;
      expect((await reopened.load()).items.single.isRead, isTrue);
      expect(reopened.mutationBlocked, isFalse);
    },
  );

  test(
    'malformed mutation response stays unconfirmed and never optimistically deletes',
    () async {
      var writes = 0;
      final session = await notificationOwner((request) async {
        if (request.method == 'GET') {
          return jsonResponse(notices([notice('n1')]));
        }
        writes++;
        return jsonResponse({});
      });
      addTearDown(session.dispose);
      final repository = WorkstationNotificationsRepository(session);
      await repository.load();
      await expectLater(
        repository.delete('n1'),
        throwsA(code('NOTIFICATION_WRITE_UNCONFIRMED')),
      );
      expect((await repository.load()).items.single.id, 'n1');
      await expectLater(
        repository.clearAll(),
        throwsA(code('NOTIFICATION_WRITE_UNCONFIRMED')),
      );
      expect(writes, 1);
    },
  );

  testWidgets(
    'failed writes retain visible rows and related navigation remains safe',
    (tester) async {
      final paths = <String>[];
      var writes = 0;
      final session = await notificationOwner((request) async {
        if (request.method == 'GET') {
          return jsonResponse(notices([notice('n1')]));
        }
        writes++;
        return jsonResponse({'detail': 'Permission denied'}, 403);
      });
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCreoTheme(),
          home: WorkstationNotificationsPage(
            session: session,
            onNavigate: paths.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark read'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Unread ·'), findsOneWidget);
      expect(find.text('Task update n1'), findsOneWidget);
      await tester.ensureVisible(find.text('Open related page'));
      await tester.tap(find.text('Open related page'));
      await tester.pumpAndSettle();
      expect(paths, ['/workstation/tasks?taskId=task-one']);
      expect(writes, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'duplicate taps issue one mutation and logout rejects late notification results',
    (tester) async {
      final pending = Completer<http.Response>();
      var writes = 0;
      final session = await notificationOwner((request) async {
        if (request.method == 'GET') {
          return jsonResponse(notices([notice('n1')]));
        }
        writes++;
        return pending.future;
      });
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCreoTheme(),
          home: WorkstationNotificationsPage(session: session),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark read'));
      await tester.pump();
      await tester.tap(find.text('Mark read'));
      await tester.pump();
      expect(writes, 1);
      await session.logout(notifyServer: false);
      await tester.pump();
      expect(find.text('Task update n1'), findsNothing);
      pending.complete(jsonResponse({'status': 'read', 'id': 'n1'}));
      await tester.pumpAndSettle();
      expect(find.text('Task update n1'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('notifications support narrow large text and reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = await notificationOwner(
      (request) async => jsonResponse(notices([notice('n1')], unread: 37)),
      role: 'freelancer',
    );
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCreoTheme(),
        builder: (_, child) => MediaQuery(
          data: const MediaQueryData(
            size: Size(280, 520),
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: WorkstationNotificationsPage(session: session),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('37 unread'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Task update n1'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
