import 'dart:async';
import 'dart:convert';

import 'package:app_flutter/src/core/app_theme.dart';
import 'package:app_flutter/src/core/auth_repository.dart';
import 'package:app_flutter/src/core/auth_session.dart';
import 'package:app_flutter/src/features/workstation/freelancer_page.dart';
import 'package:app_flutter/src/features/workstation/freelancer_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'auth_contract_test.dart' show MemorySessionStore, code;
import 'session_lifecycle_test.dart' show owner, saved, profile, jsonResponse;

Map<String, dynamic> assignment(
  String id, {
  String status = 'assigned',
  num? fee,
}) => {
  'id': id,
  'status': status,
  'client_name': 'Sample brand',
  'deliverable_type': 'reel',
  'milestone_fee': fee,
  'blueprint': {
    'title': 'Assignment $id',
    'instructions': 'Use the approved brief.',
    'raw_footage_url': 'https://assets.example.test/source',
    'audio_notes': 'Clear dialogue',
  },
  'deliverables': <Object>[],
};

Future<AuthSession> freelancerSession(
  Future<http.Response> Function(http.Request) send, {
  String role = 'freelancer',
}) async {
  final session = owner(MemorySessionStore()..value = saved(), (request) async {
    if (request.url.path == '/api/v1/auth/me') {
      return jsonResponse({...profile(), 'role': role});
    }
    return send(request);
  });
  await session.restore();
  return session;
}

void main() {
  test(
    'status grouping preserves React aliases without treating approval as payment',
    () {
      expect(
        freelancerTaskGroup('READY-TO-PUBLISH'),
        FreelancerTaskGroup.completed,
      );
      expect(freelancerTaskGroup('qa rejected'), FreelancerTaskGroup.revision);
      expect(freelancerTaskGroup('pending_qa'), FreelancerTaskGroup.review);
      expect(freelancerTaskGroup('backlog'), FreelancerTaskGroup.pending);
    },
  );

  test('assignment reads actual blueprint fields and never invents a fee', () {
    final task = FreelancerTask.fromJson(assignment('a'));
    expect(task.title, 'Assignment a');
    expect(task.description, 'Use the approved brief.');
    expect(task.footage, 'https://assets.example.test/source');
    expect(task.audio, 'Clear dialogue');
    expect(task.fee, isNull);
    expect(task.canStart, isTrue);
    expect(FreelancerTask.fromJson(assignment('b', fee: 0)).fee, 0);
    expect(() => FreelancerTask.fromJson({'id': ''}), throwsFormatException);
  });

  test(
    'real root-array task contract and bearer session are preserved',
    () async {
      final session = await freelancerSession((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/freelancer/my-tasks');
        expect(request.headers['authorization'], startsWith('Bearer '));
        return jsonResponse([assignment('a')]);
      });
      final tasks = await FreelancerRepository(session).load();
      expect(tasks.single.id, 'a');
      session.dispose();
    },
  );

  test('wrong role cannot read freelancer assignments', () async {
    var calls = 0;
    final session = await freelancerSession((_) async {
      calls++;
      return jsonResponse([]);
    }, role: 'editor');
    await expectLater(
      FreelancerRepository(session).load(),
      throwsA(code('FORBIDDEN')),
    );
    expect(calls, 0);
    session.dispose();
  });

  test(
    'writes require a loaded own assignment and send exact start/link contracts',
    () async {
      final calls = <http.Request>[];
      final session = await freelancerSession((request) async {
        calls.add(request);
        return request.method == 'GET'
            ? jsonResponse([assignment('a')])
            : jsonResponse({'status': 'success'});
      });
      final repository = FreelancerRepository(session);
      await expectLater(
        repository.start(FreelancerTask.fromJson(assignment('not-mine'))),
        throwsA(code('TASK_FORBIDDEN')),
      );
      expect(calls, isEmpty);
      final task = (await repository.load()).single;
      await repository.start(task);
      expect(calls.last.method, 'PATCH');
      expect(
        calls.last.url.path,
        '/api/v1/admin/freelancer/tasks/a/start-work',
      );
      await repository.submitLink(
        task,
        ' https://assets.example.test/final.mp4 ',
        '  Final mix  ',
      );
      expect(jsonDecode(calls.last.body), {
        'task_id': 'a',
        'asset_url': 'https://assets.example.test/final.mp4',
        'submission_notes': 'Final mix',
      });
      await expectLater(
        Future.sync(
          () => repository.submitLink(task, 'file:///private.mp4', ''),
        ),
        throwsA(code('INVALID_ASSET_URL')),
      );
      session.dispose();
    },
  );

  test(
    'duplicate task action blocked and server error is not replayed',
    () async {
      final pending = Completer<http.Response>();
      var writes = 0;
      final session = await freelancerSession((request) {
        if (request.method == 'GET') {
          return Future.value(jsonResponse([assignment('a')]));
        }
        writes++;
        return pending.future;
      });
      final repository = FreelancerRepository(session);
      final task = (await repository.load()).single;
      final first = repository.start(task);
      await expectLater(
        repository.start(task),
        throwsA(code('ACTION_PENDING')),
      );
      pending.complete(
        jsonResponse({
          'error': {'code': 'UNAVAILABLE', 'message': 'Try later'},
        }, 503),
      );
      await expectLater(first, throwsA(isA<HttpError>()));
      expect(writes, 1);
      session.dispose();
    },
  );

  test(
    'history uses confirmed deliverable id, empty assignment never invents one',
    () async {
      final paths = <String>[];
      final data = assignment('a')
        ..['deliverables'] = [
          {'id': 'delivery-a', 'version': 1},
        ];
      final session = await freelancerSession((request) async {
        paths.add(request.url.path);
        return jsonResponse(
          request.url.path.endsWith('my-tasks')
              ? [data, assignment('empty')]
              : [
                  {'action': 'submitted', 'version': 1},
                ],
        );
      });
      final repository = FreelancerRepository(session);
      final tasks = await repository.load();
      expect(await repository.history(tasks.last), isEmpty);
      expect(paths.length, 1);
      expect(
        (await repository.history(tasks.first)).single['action'],
        'submitted',
      );
      expect(paths.last, '/api/v1/deliverables/delivery-a/history');
      session.dispose();
    },
  );

  test('logout invalidates an in-flight assignment read', () async {
    final pending = Completer<http.Response>();
    final session = await freelancerSession((request) => pending.future);
    final future = FreelancerRepository(session).load();
    await session.logout(notifyServer: false);
    pending.complete(jsonResponse([assignment('private')]));
    await expectLater(future, throwsA(code('SESSION_CANCELLED')));
    session.dispose();
  });

  test(
    'uncertain write requires successful assigned-work refresh before retry',
    () async {
      var writes = 0;
      final session = await freelancerSession((request) async {
        if (request.method == 'GET') return jsonResponse([assignment('a')]);
        writes++;
        throw TimeoutException('Ambiguous response');
      });
      final repository = FreelancerRepository(session);
      final task = (await repository.load()).single;
      await expectLater(repository.start(task), throwsA(code('TIMEOUT')));
      await expectLater(
        repository.start(task),
        throwsA(code('RECONCILE_REQUIRED')),
      );
      expect(writes, 1);
      await repository.load();
      await expectLater(repository.start(task), throwsA(code('TIMEOUT')));
      expect(writes, 2);
      session.dispose();
    },
  );

  testWidgets(
    'assigned work search/stage filters and start feedback use live repository',
    (tester) async {
      final session = await freelancerSession(
        (request) async => jsonResponse(
          request.method == 'GET'
              ? [assignment('a'), assignment('b', status: 'pending_qa')]
              : {'status': 'success'},
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCreoTheme(),
          home: FreelancerPage(session: session),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Assignment a'), findsOneWidget);
      expect(find.text('Milestone fee not provided'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'no match');
      await tester.pump();
      expect(find.text('No matching assignments'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      await tester.tap(find.text('QA review (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Assignment b'), findsOneWidget);
      expect(find.text('Assignment a'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'submission preserves input after server rejection and blocks duplicate taps',
    (tester) async {
      final pending = Completer<http.Response>();
      var writes = 0;
      final session = await freelancerSession((request) {
        if (request.method == 'GET') {
          return Future.value(jsonResponse([assignment('a')]));
        }
        writes++;
        return pending.future;
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCreoTheme(),
          home: FreelancerPage(session: session),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit content'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit content'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cloud link'));
      await tester.pumpAndSettle();
      final link = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Asset / cloud storage URL',
      );
      await tester.enterText(link, 'https://assets.example.test/final.mp4');
      await tester.ensureVisible(find.text('Submit for review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit for review'));
      await tester.pump();
      await tester.tap(find.text('Submitting…'));
      await tester.pump();
      expect(writes, 1);
      pending.complete(
        jsonResponse({
          'error': {
            'code': 'QA_UNAVAILABLE',
            'message': 'Review service unavailable',
          },
        }, 503),
      );
      await tester.pumpAndSettle();
      expect(find.text('Review service unavailable'), findsOneWidget);
      expect(
        (tester.widget<TextField>(link)).controller!.text,
        'https://assets.example.test/final.mp4',
      );
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'narrow large-text landscape and themes retain actions without overflow',
    (tester) async {
      final session = await freelancerSession(
        (request) async => jsonResponse([assignment('a')]),
      );
      for (final size in [const Size(280, 520), const Size(852, 393)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        for (final brightness in Brightness.values) {
          await tester.pumpWidget(
            MaterialApp(
              theme: buildCreoTheme(brightness: brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: FreelancerPage(session: session),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      session.dispose();
    },
  );
}
