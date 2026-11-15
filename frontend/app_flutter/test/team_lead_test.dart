import 'dart:convert';
import 'package:app_flutter/src/core/auth_repository.dart';
import 'package:app_flutter/src/core/auth_session.dart';
import 'package:app_flutter/src/features/team_lead/team_lead_repository.dart';
import 'package:app_flutter/src/features/team_lead/team_lead_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'auth_contract_test.dart' show MemorySessionStore, sessionJson, code;

Map<String, dynamic> pod() => {
  'pod': {'name': 'Scoped pod'},
  'members': [
    {'id': 'member-a', 'full_name': 'Editor', 'role': 'editor'},
  ],
  'clients': [],
  'notifications': [],
  'tasks': {
    'backlog': [],
    'in_production': [],
    'completed': [],
    'internal_qa': [
      {
        'id': 'task-a',
        'status': 'internal_qa',
        'client_name': 'Scoped client',
        'deliverable_type': 'reel',
      },
    ],
  },
};
Future<AuthSession> signedIn(
  Future<http.Response> Function(http.Request) handler, {
  String role = 'team_lead',
}) async {
  final store = MemorySessionStore();
  final session = AuthSession(
    store: store,
    repository: AuthRepository(
      store: store,
      origin: Uri.parse('https://example.test'),
      client: MockClient(handler),
    ),
  );
  await session.adopt(
    SessionResponse.fromJson({
      ...sessionJson(role: role),
      'access_token':
          '${base64Url.encode(utf8.encode(jsonEncode({'typ': 'JWT'})))}.${base64Url.encode(utf8.encode(jsonEncode({'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000})))}.signature',
    }),
    session.beginAttempt(),
  );
  return session;
}

void main() {
  testWidgets('profile update does not erase the current pod screen', (
    tester,
  ) async {
    final session = await signedIn(
      (request) async => http.Response(
        jsonEncode(
          request.url.path.endsWith('/users/me') ||
                  request.url.path.endsWith('/auth/me')
              ? sessionJson(role: 'team_lead')['user']
              : pod(),
        ),
        200,
      ),
    );
    await tester.pumpWidget(MaterialApp(home: TeamLeadPage(session: session)));
    await tester.pumpAndSettle();
    expect(find.text('Scoped pod'), findsOneWidget);
    await session.updateProfile(fullName: 'Updated lead', phone: '');
    await tester.pumpAndSettle();
    expect(find.text('Scoped pod'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
  test(
    'support exposes only current pod client tickets and scoped thread IDs',
    () async {
      var replies = 0;
      final session = await signedIn((request) async {
        if (request.url.path.endsWith('pod-dashboard'))
          return http.Response(
            jsonEncode({
              ...pod(),
              'clients': [
                {'id': 'client-a', 'name': 'Client A'},
              ],
            }),
            200,
          );
        if (request.url.path.endsWith('/support/tickets'))
          return http.Response(
            jsonEncode([
              {
                'id': 'ticket-a',
                'client_id': 'client-a',
                'subject': 'Pod issue',
              },
              {'id': 'outside', 'client_id': 'other-client'},
            ]),
            200,
          );
        replies++;
        expect(
          request.url.path,
          '/api/v1/admin/support/tickets/ticket-a/messages',
        );
        expect(jsonDecode(request.body), {
          'message_text': 'Checking this',
          'status': 'open',
        });
        return http.Response('{"id":"message-a","ticket_id":"ticket-a"}', 200);
      });
      final repo = TeamLeadRepository(session);
      final tickets = await repo.tickets();
      expect(tickets.map((row) => row['id']), ['ticket-a']);
      await expectLater(
        repo.reply({'id': 'outside'}, 'Unauthorized', 'open'),
        throwsA(code('OUTSIDE_POD')),
      );
      await repo.reply(tickets.single, 'Checking this', 'open');
      expect(replies, 1);
      session.dispose();
    },
  );
  testWidgets(
    'narrow team lead navigation reaches real task form, clients and operations',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = await signedIn(
        (request) async => http.Response(jsonEncode(pod()), 200),
      );
      await tester.pumpWidget(
        MaterialApp(home: TeamLeadPage(session: session)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Scoped pod'), findsOneWidget);
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(find.text('1 tasks'), findsOneWidget);
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();
      expect(find.text('New pod task'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clients'));
      await tester.pumpAndSettle();
      expect(find.text('No clients are assigned to this pod.'), findsOneWidget);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Pod support'), findsOneWidget);
      expect(find.text('My time off'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  test(
    'task creation rejects out of pod clients and posts real scoped fields',
    () async {
      var writes = 0;
      final session = await signedIn((request) async {
        if (request.method == 'GET')
          return http.Response(
            jsonEncode({
              ...pod(),
              'clients': [
                {'id': 'client-a', 'name': 'Client A'},
              ],
            }),
            200,
          );
        writes++;
        expect(request.url.path, '/api/v1/tasks');
        expect(jsonDecode(request.body), {
          'client_id': 'client-a',
          'deliverable_type': 'reel',
          'title': 'Brief',
          'auto_dispatch': false,
        });
        return http.Response('{"id":"created-task"}', 201);
      });
      final repo = TeamLeadRepository(session);
      await repo.load();
      await expectLater(
        repo.createTask({
          'client_id': 'outside',
          'deliverable_type': 'reel',
          'title': 'Brief',
        }),
        throwsA(code('OUTSIDE_POD')),
      );
      await repo.createTask({
        'client_id': 'client-a',
        'deliverable_type': 'reel',
        'title': 'Brief',
      });
      expect(writes, 1);
      session.dispose();
    },
  );
  test('team lead rejects other roles without sending transport', () async {
    final session = await signedIn(
      (_) async => throw StateError('Unexpected request'),
      role: 'freelancer',
    );
    await expectLater(
      TeamLeadRepository(session).load(),
      throwsA(code('FORBIDDEN')),
    );
    session.dispose();
  });
  test(
    'QA uses scoped task and exact decision contract; stale objects denied',
    () async {
      var writes = 0;
      final session = await signedIn((request) async {
        if (request.method == 'GET')
          return http.Response(jsonEncode(pod()), 200);
        writes++;
        expect(request.url.path, '/api/v1/admin/pod-tasks/task-a/qa-review');
        expect(jsonDecode(request.body), {
          'decision': 'reject',
          'comment': 'Fix caption',
        });
        return http.Response(
          jsonEncode({
            'status': 'success',
            'task_id': 'task-a',
            'new_task_status': 'in_production',
          }),
          200,
        );
      });
      final repo = TeamLeadRepository(session);
      final data = await repo.load();
      await expectLater(
        repo.review(data.inQa.single, approve: false),
        throwsA(code('NOTES_REQUIRED')),
      );
      await repo.review(
        data.inQa.single,
        approve: false,
        comment: 'Fix caption',
      );
      await expectLater(
        repo.review(data.inQa.single, approve: true),
        throwsA(code('STALE_TASK')),
      );
      expect(writes, 1);
      session.dispose();
    },
  );
  test('uncertain QA stays blocked across reopened repositories', () async {
    var writes = 0;
    final session = await signedIn((request) async {
      if (request.method == 'GET') return http.Response(jsonEncode(pod()), 200);
      writes++;
      return http.Response('{}', 503);
    });
    final first = TeamLeadRepository(session);
    await expectLater(
      first.review((await first.load()).inQa.single, approve: true),
      throwsA(code('WRITE_UNCONFIRMED')),
    );
    final reopened = TeamLeadRepository(session);
    await expectLater(
      reopened.review((await reopened.load()).inQa.single, approve: true),
      throwsA(code('WRITE_UNCONFIRMED')),
    );
    expect(writes, 1);
    session.dispose();
  });
  test(
    'assignment accepts only current scoped roster objects and expires on logout',
    () async {
      var writes = 0;
      final session = await signedIn((request) async {
        if (request.method == 'GET')
          return http.Response(jsonEncode(pod()), 200);
        writes++;
        expect(jsonDecode(request.body), {'assignee_id': 'member-a'});
        return http.Response(
          jsonEncode({
            'status': 'success',
            'task_id': 'task-a',
            'assigned_to': 'member-a',
          }),
          200,
        );
      });
      final repo = TeamLeadRepository(session);
      final data = await repo.load();
      await expectLater(
        repo.reassign(data.inQa.single, {'id': 'outside', 'role': 'editor'}),
        throwsA(code('OUTSIDE_POD')),
      );
      await repo.reassign(data.inQa.single, repo.members.single);
      expect(writes, 1);
      await session.logout(notifyServer: false);
      await expectLater(repo.load(), throwsA(code('FORBIDDEN')));
      session.dispose();
    },
  );
}
