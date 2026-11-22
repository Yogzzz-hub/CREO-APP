import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:app_flutter/src/features/team_lead/team_lead_repository.dart';
import 'package:app_flutter/src/features/team_lead/team_lead_people_page.dart';
import 'team_lead_test.dart' show signedIn, pod;
import 'auth_contract_test.dart' show code;

Map<String, dynamic> leave({
  String id = 'leave-a',
  bool self = false,
  bool allowed = true,
}) => {
  'id': id,
  'user_id': self ? 'account-a' : 'member-a',
  'is_self': self,
  'status': 'pending',
  'can_approve': allowed,
  'can_reject': allowed,
  'user_name': 'Editor',
  'start_date': '2030-01-02',
  'end_date': '2030-01-03',
  'reason': 'Planned break',
};
void main() {
  test(
    'leave flags, identity and own-account boundaries are checked before transport',
    () async {
      var writes = 0;
      final session = await signedIn((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode([
              leave(),
              leave(id: 'own', self: true),
              leave(id: 'denied', allowed: false),
            ]),
            200,
          );
        }
        writes++;
        expect(request.url.path, '/api/v1/admin/leave/leave-a/reject');
        expect(jsonDecode(request.body), {});
        return http.Response('{"status":"rejected","id":"leave-a"}', 200);
      });
      final repo = TeamLeadRepository(session);
      final rows = await repo.leaves();
      await expectLater(
        repo.decideLeave(leave(), approve: true),
        throwsA(code('LEAVE_FORBIDDEN')),
      );
      await expectLater(
        repo.decideLeave(rows[1], approve: true),
        throwsA(code('LEAVE_FORBIDDEN')),
      );
      await expectLater(
        repo.decideLeave(rows[2], approve: false),
        throwsA(code('LEAVE_FORBIDDEN')),
      );
      await repo.decideLeave(rows[0], approve: false);
      expect(writes, 1);
      await expectLater(
        repo.decideLeave(rows[0], approve: true),
        throwsA(code('LEAVE_FORBIDDEN')),
      );
      session.dispose();
    },
  );
  test(
    'ambiguous review remains blocked across reload and page reopening',
    () async {
      var writes = 0;
      final session = await signedIn((request) async {
        if (request.method == 'GET') {
          return http.Response(jsonEncode([leave()]), 200);
        }
        writes++;
        return http.Response('{}', 200);
      });
      final first = TeamLeadRepository(session);
      await expectLater(
        first.decideLeave((await first.leaves()).single, approve: true),
        throwsA(code('WRITE_UNCONFIRMED')),
      );
      final next = TeamLeadRepository(session);
      await expectLater(
        next.decideLeave((await next.leaves()).single, approve: false),
        throwsA(code('WRITE_UNCONFIRMED')),
      );
      expect(writes, 1);
      session.dispose();
    },
  );
  test(
    'member settings use current roster, exact patch fields and generation',
    () async {
      var writes = 0;
      final session = await signedIn((request) async {
        if (request.method == 'GET') {
          return http.Response(jsonEncode(pod()), 200);
        }
        writes++;
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/v1/admin/teams/member-a');
        expect(jsonDecode(request.body), {
          'daily_capacity': 5,
          'skills': ['editing'],
          'is_accepting_work': false,
        });
        return http.Response(
          '{"status":"updated","user_id":"member-a","daily_capacity":5,"skills":["editing"],"is_accepting_work":false}',
          200,
        );
      });
      final repo = TeamLeadRepository(session);
      await repo.load();
      final member = repo.members.single;
      await expectLater(
        repo.updateMember(
          {'id': 'other'},
          capacity: 5,
          skills: [],
          accepting: false,
        ),
        throwsA(code('OUTSIDE_POD')),
      );
      await expectLater(
        repo.updateMember(member, capacity: 0, skills: [], accepting: false),
        throwsArgumentError,
      );
      await repo.updateMember(
        member,
        capacity: 5,
        skills: ['editing'],
        accepting: false,
      );
      expect(writes, 1);
      await session.logout(notifyServer: false);
      await expectLater(
        repo.updateMember(member, capacity: 5, skills: [], accepting: true),
        throwsA(code('FORBIDDEN')),
      );
      session.dispose();
    },
  );
  testWidgets(
    'narrow leave page hides own actions and confirms permitted approval',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var writes = 0;
      final session = await signedIn((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode([leave(), leave(id: 'own', self: true)]),
            200,
          );
        }
        writes++;
        return http.Response('{"status":"approved","id":"leave-a"}', 200);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: TeamLeadPeoplePage(repository: TeamLeadRepository(session)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Approve'), findsOneWidget);
      expect(
        find.text('Your request is reviewed by another approver.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      await tester.tap(find.widgetWithText(FilledButton, 'Approve').last);
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
