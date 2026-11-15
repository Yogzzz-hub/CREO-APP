import 'dart:async';

import 'package:app_flutter/main.dart';
import 'package:app_flutter/src/core/app_appearance.dart';
import 'package:app_flutter/src/core/app_theme.dart';
import 'package:app_flutter/src/core/auth_repository.dart';
import 'package:app_flutter/src/core/auth_session.dart';
import 'package:app_flutter/src/features/workstation/workstation_data.dart';
import 'package:app_flutter/src/features/workstation/workstation_page.dart';
import 'package:app_flutter/workstation_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'auth_contract_test.dart' show MemorySessionStore, code;
import 'session_lifecycle_test.dart' show owner, saved, profile, jsonResponse;

const user = workstationPreviewUser;
Map<String, dynamic> taskJson(
  String id, {
  String? assigned = 'preview-member',
  String format = 'reel',
  String? due,
}) => {
  'id': id,
  'client_name': 'Sample brand',
  'assigned_to': assigned,
  'assignee': null,
  'assignee_name': null,
  'deliverable_type': format,
  'status': 'in_production',
  'due_date': due,
  'sla_due_at': null,
  'blueprint': {'concept_name': 'Task $id'},
  'deliverable': null,
};
Map<String, dynamic> dashboardJson() => {
  'pod': {'id': 'test-pod', 'name': 'Sample Pod'},
  'members': <Object>[],
  'notifications': <Object>[],
  'tasks': {
    'backlog': [taskJson('unassigned', assigned: null)],
    'in_production': [
      taskJson('mine'),
      taskJson('other', assigned: 'other-account'),
    ],
    'internal_qa': <Object>[],
    'completed': [taskJson('done')],
  },
};

void main() {
  test('contract parses null media, preserves scopes and sorts due dates', () {
    final json = dashboardJson();
    (json['tasks'] as Map)['in_production'] = [
      taskJson('later', due: '2030-01-03'),
      taskJson('undated'),
      taskJson('other', assigned: 'another-account', due: '2030-01-01'),
      taskJson('early', due: '2030-01-01'),
    ];
    final data = WorkstationData.fromJson(json);
    expect(data.tasks(user).map((t) => t.id), ['early', 'later', 'undated']);
    expect(data.tasks(user, allPod: true).length, 4);
    expect(data.tasks(user, archived: true).single.id, 'done');
    expect(data.dueByToday(user, DateTime(2030, 1, 1)), 1);
    expect(data.tasks(user).first.fileUrl, isNull);
    expect(
      WorkstationTask.fromJson({
        ...taskJson('blank'),
        'blueprint': {'concept_name': ''},
      }).title,
      'reel',
    );
    expect(
      () => WorkstationData.fromJson({'pod': {}, 'tasks': []}),
      throwsFormatException,
    );
    final malformed = dashboardJson()..['members'] = 'invalid';
    expect(() => WorkstationData.fromJson(malformed), throwsFormatException);
  });

  test('React assignment fallbacks and role eligible backlog are retained', () {
    final emailAssigned = WorkstationTask.fromJson({
      ...taskJson('email', assigned: null),
      'assignee': {'email': user.email.toUpperCase()},
    });
    expect(emailAssigned.assignedToUser(user), true);
    final nameAssigned = WorkstationTask.fromJson({
      ...taskJson('name', assigned: null),
      'assignee_name': user.fullName.toUpperCase(),
    });
    expect(nameAssigned.assignedToUser(user), true);
    expect(
      WorkstationTask.fromJson(
        taskJson('reel', assigned: null),
      ).eligibleBacklog(user),
      true,
    );
    expect(
      WorkstationTask.fromJson(
        taskJson('graphic', assigned: null, format: 'carousel'),
      ).eligibleBacklog(user),
      false,
    );
    expect(
      WorkstationTask.fromJson(
        taskJson('other', assigned: 'other'),
      ).eligibleBacklog(user),
      false,
    );
  });

  test(
    'dashboard request uses session bearer and exact existing API contract',
    () async {
      final store = MemorySessionStore()..value = saved();
      var reads = 0;
      final session = owner(store, (request) async {
        if (request.url.path.endsWith('/me')) {
          return jsonResponse({...profile(), 'role': 'editor'});
        }
        reads++;
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/pod-dashboard');
        expect(request.url.hasQuery, false);
        expect(request.headers['authorization'], startsWith('Bearer '));
        expect(request.body, isEmpty);
        return jsonResponse(dashboardJson());
      });
      await session.restore();
      expect(
        (await WorkstationRepository(session).load()).podName,
        'Sample Pod',
      );
      expect(reads, 1);
      expect(DestinationIntent.forUser(session.current!.user).blocker, isNull);
      session.dispose();
    },
  );

  test(
    'repository denies client and mandatory reset before transport',
    () async {
      for (final restricted in [false, true]) {
        final store = MemorySessionStore()..value = saved();
        var calls = 0;
        final session = owner(store, (_) async {
          calls++;
          return jsonResponse({
            ...profile(restricted: restricted),
            'role': restricted ? 'editor' : 'client',
          });
        });
        await session.restore();
        await expectLater(
          WorkstationRepository(session).load(),
          throwsA(code('FORBIDDEN')),
        );
        expect(calls, 1);
        session.dispose();
      }
    },
  );

  test(
    'concurrent refresh is shared and delayed result cannot survive disposal',
    () async {
      final result = Completer<WorkstationData>();
      var calls = 0, changes = 0;
      final controller = WorkstationController(() {
        calls++;
        return result.future;
      });
      controller.addListener(() => changes++);
      final a = controller.refresh(), b = controller.refresh();
      expect(calls, 1);
      expect(identical(a, b), true);
      controller.dispose();
      result.complete(const WorkstationData(podName: 'Late result'));
      await a;
      expect(controller.data, isNull);
      expect(changes, 1);
      await controller.refresh();
      expect(calls, 1);
    },
  );

  test('refresh error retains last data and next retry recovers', () async {
    var attempt = 0;
    final controller = WorkstationController(() async {
      if (++attempt == 2) {
        throw const HttpError(status: 0, code: 'TIMEOUT', message: 'Timed out');
      }
      return const WorkstationData(podName: 'Loaded Pod');
    });
    await controller.refresh();
    await controller.refresh();
    expect(controller.data?.podName, 'Loaded Pod');
    expect(controller.error?.code, 'TIMEOUT');
    await controller.refresh();
    expect(controller.error, isNull);
    controller.dispose();
  });

  test('forbidden refresh clears previously loaded private data', () async {
    var fail = false;
    final controller = WorkstationController(() async {
      if (fail) {
        throw const HttpError(
          status: 403,
          code: 'FORBIDDEN',
          message: 'Access denied',
        );
      }
      return const WorkstationData(podName: 'Private Pod');
    });
    await controller.refresh();
    fail = true;
    await controller.refresh();
    expect(controller.data, isNull);
    expect(controller.error?.status, 403);
    controller.dispose();
  });

  test(
    'logout rejects a pending dashboard response without retaining its data',
    () async {
      final store = MemorySessionStore()..value = saved();
      final pending = Completer<http.Response>();
      final session = owner(store, (request) async {
        if (request.url.path.endsWith('/me')) {
          return jsonResponse({...profile(), 'role': 'editor'});
        }
        return pending.future;
      });
      await session.restore();
      final controller = WorkstationController(
        WorkstationRepository(session).load,
      );
      final loading = controller.refresh();
      await session.logout(notifyServer: false);
      pending.complete(jsonResponse(dashboardJson()));
      await loading;
      expect(session.current, isNull);
      expect(controller.data, isNull);
      expect(controller.error?.code, 'SESSION_CANCELLED');
      controller.dispose();
      session.dispose();
    },
  );

  Future<void> mount(
    WidgetTester tester, {
    LoadWorkstation? load,
    Size size = const Size(393, 852),
    double scale = 1,
    bool reduced = false,
    Brightness brightness = Brightness.dark,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final appearance = CreoAppearance(
      read: () async => null,
      write: (_) async {},
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      appearance.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCreoTheme(brightness: brightness),
        builder: (context, child) =>
            CreoAppearanceScope(appearance: appearance, child: child!),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduced,
          ),
          child: WorkstationPage(
            user: user,
            load: load ?? loadWorkstationPreview,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    for (final size in [
      const Size(280, 520),
      const Size(393, 852),
      const Size(852, 393),
      const Size(1280, 900),
    ]) {
      testWidgets(
        'dashboard fits $size with 200% text $brightness reduced motion',
        (tester) async {
          await mount(
            tester,
            size: size,
            scale: 2,
            brightness: brightness,
            reduced: true,
          );
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.byKey(const Key('panel-team')),
            300,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 35,
          );
          await Scrollable.ensureVisible(
            tester.element(find.byKey(const Key('panel-team'))),
            alignment: .5,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('panel-team')));
          await tester.pumpAndSettle();
          expect(find.text('Preview Lead'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'scope/archive filtering and detail sheet preserve the selected view',
    (tester) async {
      await mount(tester);
      await tester.ensureVisible(find.byKey(const Key('scope-pod')));
      await tester.tap(find.byKey(const Key('scope-pod')));
      await tester.pumpAndSettle();
      expect(find.text('Active (3)'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('tab-archived')));
      await tester.tap(find.byKey(const Key('tab-archived')));
      await tester.pumpAndSettle();
      final task = find.byKey(const Key('task-preview-5'));
      await tester.ensureVisible(task);
      await tester.tap(task);
      await tester.pumpAndSettle();
      expect(find.text('Deliverable details'), findsOneWidget);
      expect(find.text('Version 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('scope-pod'))).selected,
        true,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('tab-archived')))
            .selected,
        true,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loading failure retry and empty data are real states', (
    tester,
  ) async {
    final result = Completer<WorkstationData>();
    var calls = 0;
    Future<WorkstationData> load() => ++calls == 1
        ? result.future
        : Future.value(const WorkstationData(podName: 'Empty Pod'));
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCreoTheme(),
        home: WorkstationPage(user: user, load: load),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Loading your workspace…'), findsOneWidget);
    result.completeError(
      const HttpError(
        status: 0,
        code: 'TIMEOUT',
        message: 'Connection timed out.',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Connection timed out.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Empty Pod'), findsOneWidget);
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'validated editor opens real navigation boundary and logout clears history',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = MemorySessionStore()..value = saved();
      var dashboardCalls = 0;
      final session = owner(store, (request) async {
        if (request.url.path.endsWith('/me')) {
          return jsonResponse({...profile(), 'role': 'editor'});
        }
        if (request.url.path.endsWith('/logout')) {
          return jsonResponse({'status': 'logged_out'});
        }
        dashboardCalls++;
        return jsonResponse(dashboardJson());
      });
      final appearance = CreoAppearance(
        read: () async => null,
        write: (_) async {},
      );
      await session.restore();
      await tester.pumpWidget(
        CreoApp(
          session: session,
          appearance: appearance,
          initialRoute: '/login',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WorkstationPage), findsOneWidget);
      expect(find.byKey(const Key('login-email')), findsNothing);
      await tester.tap(find.text('Tasks').last);
      await tester.pumpAndSettle();
      expect(find.text('My tasks'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final callsBeforeAppearanceChange = dashboardCalls;
      await tester.tap(find.byKey(const Key('appearance-toggle')));
      await tester.pumpAndSettle();
      expect(
        dashboardCalls,
        callsBeforeAppearanceChange,
        reason: 'Appearance changes must not start a new dashboard request',
      );
      await tester.tap(find.byKey(const Key('workstation-menu')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sign out on this device'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out on this device'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkstationPage), findsNothing);
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      expect(store.value, isNull);
      expect(
        Navigator.of(
          tester.element(find.byKey(const Key('login-email'))),
        ).canPop(),
        false,
      );
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      appearance.dispose();
    },
  );
}
