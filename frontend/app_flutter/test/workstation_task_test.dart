import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:app_flutter/src/core/app_theme.dart';
import 'package:app_flutter/src/core/auth_repository.dart';
import 'package:app_flutter/src/core/auth_session.dart';
import 'package:app_flutter/src/features/workstation/workstation_data.dart';
import 'package:app_flutter/src/features/workstation/workstation_files.dart';
import 'package:app_flutter/src/features/workstation/workstation_task_page.dart';
import 'package:app_flutter/src/features/workstation/workstation_task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'auth_contract_test.dart' show MemorySessionStore, code;
import 'session_lifecycle_test.dart'
    show owner, saved, profile, jsonResponse, clock;
import 'workstation_test.dart' show taskJson, dashboardJson;

Map<String, dynamic> board() => {
  ...dashboardJson(),
  'clients': [
    {'id': 'client-a', 'name': 'Sample brand'},
  ],
  'tasks': {
    'backlog': [
      {...taskJson('queued', assigned: 'account-a'), 'status': 'backlog'},
    ],
    'in_production': [
      {...taskJson('production', assigned: 'account-a'), 'is_revision': true},
    ],
    'internal_qa': [
      {...taskJson('qa', assigned: 'account-a'), 'status': 'internal_qa'},
    ],
    'client_review': [
      {...taskJson('review', assigned: 'account-a'), 'status': 'client_review'},
    ],
    'ready_to_publish': [
      {
        ...taskJson('ready', assigned: 'account-a'),
        'status': 'ready_to_publish',
      },
    ],
    'completed': [
      {...taskJson('done', assigned: 'account-a'), 'status': 'completed'},
    ],
  },
};
Future<AuthSession> staff(
  Future<http.Response> Function(http.Request) send,
) async {
  final session = owner(MemorySessionStore()..value = saved(), (request) async {
    if (request.url.path == '/api/v1/auth/me') {
      return jsonResponse({...profile(), 'role': 'editor'});
    }
    return send(request);
  });
  await session.restore();
  return session;
}

class MultipartClient extends http.BaseClient {
  http.BaseRequest? captured;
  String? sent;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path == '/api/v1/auth/me') {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({...profile(), 'role': 'editor'}))),
        200,
      );
    }
    captured = request;
    sent = utf8.decode(await request.finalize().toBytes());
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"id":"delivery-a","version":2}')),
      200,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('All six backend buckets map to four source task stages', () async {
    final session = await staff((r) async => jsonResponse(board()));
    final repo = StaffTaskRepository(session);
    final data = await repo.load();
    final entries = staffBoardEntries(data, repo.user);
    expect(entries.length, 6);
    expect(entries.where((r) => r.column == 'Review').length, 3);
    expect(
      entries.singleWhere((r) => r.task.id == 'production').highPriority,
      true,
    );
    session.dispose();
  });
  test('Source five optional self checks preserve notes and open keys', () {
    expect(
      staffSubmissionNotes('  Delivery notes  ', {'brand'}),
      'Delivery notes\nSelf-check 1/5 (open: spec, audio, copy, guardrails)',
    );
    expect(
      staffSubmissionNotes('', staffSelfChecks.keys.toSet()),
      'Self-check 5/5',
    );
  });
  test(
    'Task title uses source blueprint title when concept name is absent',
    () {
      expect(
        WorkstationTask.fromJson({
          ...taskJson('created'),
          'blueprint': {'title': 'Actual task title'},
        }).title,
        'Actual task title',
      );
    },
  );
  test('Start exact contract and create preserves all form fields', () async {
    final writes = <http.Request>[];
    final session = await staff((r) async {
      if (r.method == 'GET') return jsonResponse(board());
      writes.add(r);
      return jsonResponse({'id': 'new-task', 'status': 'backlog'});
    });
    final repo = StaffTaskRepository(session);
    final data = await repo.load();
    await repo.start(data.backlog.single);
    expect(writes.single.method, 'POST');
    expect(writes.single.url.path, '/api/v1/deliverables/tasks/queued/start');
    const fields = {
      'client_id': 'client-a',
      'deliverable_type': 'reel',
      'title': 'Story',
      'brief': 'Instructions',
      'due_date': null,
      'raw_footage_url': 'https://media.example.test/raw',
      'target_duration': '30-60s',
      'audio_notes': 'Clean',
      'hook': 'First frame',
      'reference_url': 'https://media.example.test/ref',
    };
    await repo.create(fields);
    expect(writes.last.url.path, '/api/v1/tasks');
    expect(jsonDecode(writes.last.body), fields);
    await expectLater(
      repo.create({...fields, 'deliverable_type': 'static_post'}),
      throwsA(code('FORMAT_NOT_ALLOWED')),
    );
    await expectLater(
      repo.create({...fields, 'client_id': 'another-client'}),
      throwsA(code('CLIENT_NOT_AVAILABLE')),
    );
    session.dispose();
  });
  test(
    'Pending/uncertain writes blocked until successful server reconciliation',
    () async {
      final pending = Completer<http.Response>();
      pending.future.ignore();
      var writes = 0;
      final session = await staff((r) async {
        if (r.method == 'GET') return jsonResponse(board());
        writes++;
        return pending.future;
      });
      final repo = StaffTaskRepository(session);
      final data = await repo.load();
      final first = repo.start(data.backlog.single);
      await expectLater(
        repo.start(data.backlog.single),
        throwsA(code('RECONCILE_REQUIRED')),
      );
      final firstFailure = expectLater(first, throwsA(code('TIMEOUT')));
      pending.completeError(
        const HttpError(status: 0, code: 'TIMEOUT', message: 'Timed out'),
      );
      await firstFailure;
      await expectLater(
        repo.start(data.backlog.single),
        throwsA(code('RECONCILE_REQUIRED')),
      );
      expect(writes, 1);
      await repo.load();
      session.dispose();
    },
  );
  test(
    'Read candidates cannot cross logout or same-account session generation',
    () async {
      final session = await staff((r) async => jsonResponse(board()));
      final repo = StaffTaskRepository(session);
      final data = await repo.load();
      session.beginAttempt();
      await expectLater(
        repo.start(data.backlog.single),
        throwsA(code('FORBIDDEN')),
      );
      session.dispose();
    },
  );
  test('Media file validation matches React limits and minimum video size', () {
    WorkstationFile file(String mime, int size) => WorkstationFile(
      path: 'private',
      name: 'file',
      size: size,
      mimeType: mime,
    );
    expect(
      WorkstationFileTransfer.validate(file('video/mp4', 1023)),
      isNotNull,
    );
    expect(
      WorkstationFileTransfer.validate(file('video/mp4', 500 * 1024 * 1024)),
      isNull,
    );
    expect(
      WorkstationFileTransfer.validate(file('image/png', 10 * 1024 * 1024 + 1)),
      isNotNull,
    );
    expect(
      WorkstationFileTransfer.validate(file('application/pdf', 1024)),
      isNotNull,
    );
  });
  test(
    'Multipart delivery uses shared bearer client without JSON content type',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'creo-workstation-contract-',
      );
      final file = File('${temp.path}/fixture.png');
      await file.writeAsString('fixture-bytes');
      try {
        final client = MultipartClient();
        final store = MemorySessionStore()..value = saved();
        final session = AuthSession(
          store: store,
          now: () => clock,
          repository: AuthRepository(
            client: client,
            store: store,
            origin: Uri.parse('https://api.example.test'),
          ),
        );
        await session.restore();
        var progress = 0.0;
        final response = await WorkstationFileTransfer(session).upload(
          '/api/v1/deliverables/tasks/queued/upload',
          WorkstationFile(
            path: file.path,
            name: 'fixture.png',
            size: 13,
            mimeType: 'image/png',
          ),
          notes: 'Self-check 5/5',
          onProgress: (value) => progress = value,
        );
        expect(response['version'], 2);
        expect(
          client.captured!.headers['Authorization'],
          startsWith('Bearer '),
        );
        expect(
          client.captured!.headers['content-type'],
          contains('multipart/form-data'),
        );
        expect(client.sent, contains('name="file"'));
        expect(client.sent, contains('fixture-bytes'));
        expect(client.sent, contains('Self-check 5/5'));
        expect(progress, 1);
        session.dispose();
      } finally {
        await temp.delete(recursive: true);
      }
    },
  );
  test(
    'Native picker cancellation and media-only flag retain explicit contract',
    () async {
      MethodCall? call;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(WorkstationFileTransfer.channel, (
            value,
          ) async {
            call = value;
            return null;
          });
      expect(await WorkstationFileTransfer.pick(mediaOnly: false), isNull);
      expect(call!.arguments, {'mediaOnly': false});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(WorkstationFileTransfer.channel, null);
    },
  );
  test(
    'Authenticated request factory cannot redirect bearer to another origin',
    () async {
      final session = await staff((r) async => jsonResponse({}));
      await expectLater(
        session.request(
          'POST',
          '/api/v1/tasks',
          buildRequest: (_) async => http.Request(
            'POST',
            Uri.parse('https://another.example.test/api/v1/tasks'),
          ),
        ),
        throwsArgumentError,
      );
      session.dispose();
    },
  );
  testWidgets('Board stage, search and client filters work without writes', (
    tester,
  ) async {
    var writes = 0;
    final session = await staff((r) async {
      if (r.method != 'GET') writes++;
      return jsonResponse(board());
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCreoTheme(),
        home: WorkstationTaskPage(session: session),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Task queued'), findsOneWidget);
    await tester.tap(find.text('Review (3)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Task review');
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'Task review',
      ),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'no matches');
    await tester.pumpAndSettle();
    expect(find.textContaining('No tasks match'), findsOneWidget);
    expect(writes, 0);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
  testWidgets('Staff board reflows at 280px, 200% text and reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = await staff((r) async => jsonResponse(board()));
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
          home: WorkstationTaskPage(session: session),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
