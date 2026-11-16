import 'dart:async';
import 'dart:convert';
import 'package:app_flutter/src/core/app_theme.dart';
import 'package:app_flutter/src/core/auth_session.dart';
import 'package:app_flutter/src/features/workstation/workstation_hub_repository.dart';
import 'package:app_flutter/src/features/workstation/workstation_hub_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'auth_contract_test.dart' show MemorySessionStore, code;
import 'session_lifecycle_test.dart' show owner, saved, profile, jsonResponse;

Future<AuthSession> hubOwner(
  Future<http.Response> Function(http.Request) send, {
  String role = 'editor',
}) async {
  final session = owner(MemorySessionStore()..value = saved(), (request) async {
    if (request.url.path.endsWith('/auth/me')) {
      return jsonResponse({...profile(), 'role': role});
    }
    return send(request);
  });
  await session.restore();
  return session;
}

void main() {
  for (final role in ['admin', 'super_admin']) {
    for (final failedSection in ['contacts', 'channels']) {
      testWidgets(
        '$role Hub keeps the working section when $failedSection fails and recovers on Retry',
        (tester) async {
          var fail = true;
          final session = await hubOwner((request) async {
            if (fail && request.url.path.endsWith('/$failedSection')) {
              return jsonResponse({
                'detail': 'An unexpected server error occurred.',
              }, 500);
            }
            if (request.url.path.endsWith('/channels')) {
              return jsonResponse([
                {'id': 'general', 'label': 'General channel'},
              ]);
            }
            if (request.url.path.endsWith('/contacts')) {
              return jsonResponse([
                {'id': 'staff', 'name': 'Staff contact'},
              ]);
            }
            return jsonResponse([]);
          }, role: role);
          addTearDown(session.dispose);
          await tester.pumpWidget(
            MaterialApp(
              theme: buildCreoTheme(),
              home: WorkstationHubPage(session: session),
            ),
          );
          await tester.pumpAndSettle();
          final workingTitle = failedSection == 'contacts'
              ? 'General channel'
              : 'Staff contact';
          final failedTitle = failedSection == 'contacts'
              ? 'Staff contact'
              : 'General channel';
          expect(find.text(workingTitle), findsOneWidget);
          expect(find.text(failedTitle), findsNothing);
          expect(
            find.textContaining(
              '${failedSection == 'contacts' ? 'Direct conversations' : 'Channels'} could not be loaded.',
            ),
            findsOneWidget,
          );
          await tester.ensureVisible(find.text(workingTitle));
          await tester.tap(find.text(workingTitle));
          await tester.pumpAndSettle();
          expect(find.text('Send'), findsOneWidget);
          await tester.pageBack();
          await tester.pumpAndSettle();
          fail = false;
          await tester.tap(find.text('Retry'));
          await tester.pumpAndSettle();
          expect(find.text('General channel'), findsOneWidget);
          expect(find.text('Staff contact'), findsOneWidget);
          expect(find.textContaining('could not be loaded.'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  test('chat only reads and sends server-returned conversations', () async {
    final requests = <http.Request>[];
    final session = await hubOwner((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/channels')) {
        return jsonResponse([
          {'id': 'pod/one & two', 'label': 'My pod'},
        ]);
      }
      if (request.url.path.endsWith('/contacts')) {
        return jsonResponse([
          {'id': 'administrator', 'name': 'Admin'},
        ]);
      }
      return jsonResponse(
        request.method == 'GET' ? <Object>[] : {'id': 'message'},
      );
    });
    addTearDown(session.dispose);
    final repository = WorkstationHubRepository(session);
    await repository.channels();
    await repository.contacts();
    await repository.messages('pod/one & two', direct: false);
    expect(requests.last.url.queryParameters['channel'], 'pod/one & two');
    await repository.send('administrator', '  Hello  ', direct: true);
    expect(jsonDecode(requests.last.body), {
      'recipient_id': 'administrator',
      'thread_type': 'direct',
      'message': 'Hello',
    });
    final before = requests.length;
    await expectLater(
      repository.send('unknown', 'hello', direct: false),
      throwsA(code('THREAD_FORBIDDEN')),
    );
    expect(requests.length, before);
  });

  test('freelancer has no channel requests or publishing access', () async {
    var calls = 0;
    final session = await hubOwner((request) async {
      calls++;
      return jsonResponse([]);
    }, role: 'freelancer');
    addTearDown(session.dispose);
    final repository = WorkstationHubRepository(session);
    expect(await repository.channels(), isEmpty);
    await expectLater(repository.jobs(), throwsA(code('WORKSPACE_FORBIDDEN')));
    expect(calls, 0);
  });

  test('publishing role and actual server capability gate mutations', () async {
    var writes = 0;
    final session = await hubOwner((request) async {
      if (request.method == 'POST') writes++;
      return jsonResponse({'can_manage': false});
    });
    addTearDown(session.dispose);
    final repository = WorkstationHubRepository(session);
    await expectLater(
      repository.publishingAction('deliverable', 'cancel'),
      throwsA(code('ACTION_FORBIDDEN')),
    );
    await expectLater(
      repository.publishingAction('deliverable', 'publish_now'),
      throwsA(code('ACTION_FORBIDDEN')),
    );
    await expectLater(
      repository.publishingAction('deliverable', 'retry'),
      throwsA(code('ACTION_FORBIDDEN')),
    );
    await expectLater(
      repository.planCalendar(),
      throwsA(code('ACTION_FORBIDDEN')),
    );
    expect(writes, 0);
  });

  test(
    'publishing list paging and schedule preserve exact backend payloads',
    () async {
      final requests = <http.Request>[];
      final session = await hubOwner((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/jobs')) return jsonResponse([]);
        if (request.method == 'POST') {
          return jsonResponse({'id': 'job', 'status': 'pending_approval'});
        }
        return jsonResponse({'can_manage': true});
      });
      addTearDown(session.dispose);
      final repository = WorkstationHubRepository(session);
      await repository.jobs(
        offset: 100,
        clientId: 'brand & one',
        status: 'scheduled',
      );
      expect(requests.last.url.queryParameters, {
        'offset': '100',
        'client_id': 'brand & one',
        'status': 'scheduled',
      });
      await repository.schedule(
        'deliverable',
        localTime: '2030-11-09T14:30',
        timezone: 'Asia/Kolkata',
        caption: 'Caption',
        mediaType: 'REELS',
        fold: 1,
      );
      expect(jsonDecode(requests.last.body), {
        'local_time': '2030-11-09T14:30',
        'timezone': 'Asia/Kolkata',
        'fold': 1,
        'caption': 'Caption',
        'media_type': 'REELS',
      });
      await repository.schedule(
        'deliverable',
        caption: 'discard for story',
        mediaType: 'STORIES',
      );
      expect(jsonDecode(requests.last.body), {
        'timezone': 'Asia/Kolkata',
        'fold': null,
        'caption': '',
        'media_type': 'STORIES',
      });
    },
  );

  test('malformed lists and empty messages fail without a write', () async {
    expect(
      () => workspaceRows({
        'items': [42],
      }),
      throwsFormatException,
    );
    final session = await hubOwner(
      (request) async => jsonResponse([
        {'id': 'admin'},
      ]),
    );
    addTearDown(session.dispose);
    final repository = WorkstationHubRepository(session);
    await repository.contacts();
    await expectLater(
      repository.send('admin', '  ', direct: true),
      throwsFormatException,
    );
  });

  testWidgets(
    'hub navigation, draft retention after error and duplicate-send protection',
    (tester) async {
      final pending = Completer<http.Response>();
      var sends = 0;
      final session = await hubOwner((request) async {
        if (request.url.path.endsWith('/channels')) return jsonResponse([]);
        if (request.url.path.endsWith('/contacts')) {
          return jsonResponse([
            {'id': 'admin', 'name': 'Workspace admin', 'role': 'Administrator'},
          ]);
        }
        if (request.method == 'POST') {
          sends++;
          return pending.future;
        }
        return jsonResponse([]);
      });
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCreoTheme(),
          home: WorkstationHubPage(session: session),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Workspace admin'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Keep my draft');
      await tester.tap(find.text('Send'));
      await tester.pump();
      await tester.tap(find.text('Sending…'));
      await tester.pump();
      expect(sends, 1);
      pending.complete(jsonResponse({'detail': 'Network failed'}, 503));
      await tester.pumpAndSettle();
      expect(find.text('Keep my draft'), findsOneWidget);
      expect(find.text('Send'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('hub narrow large-text and background resume stay bounded', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    final session = await hubOwner((request) async {
      calls++;
      return jsonResponse([]);
    });
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCreoTheme(),
        builder: (_, child) => MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: WorkstationHubPage(session: session),
      ),
    );
    await tester.pumpAndSettle();
    final initial = calls;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 15));
    expect(calls, initial);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(calls, initial + 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('publishing respects server permission and page navigation', (
    tester,
  ) async {
    final session = await hubOwner((request) async {
      if (request.url.path.endsWith('/jobs')) {
        return jsonResponse([
          {
            'id': 'job',
            'title': 'Brand launch',
            'deliverable_id': 'deliverable',
            'status': 'scheduled',
          },
        ]);
      }
      if (request.url.path.endsWith('/clients')) {
        return jsonResponse([
          {'client_id': 'brand', 'company_name': 'Brand'},
        ]);
      }
      return jsonResponse({
        'can_manage': false,
        'connection_status': 'connected',
        'publishing_enabled': true,
        'job': {
          'status': 'scheduled',
          'caption': 'Approved caption',
          'version': 2,
          'approved': true,
        },
      });
    });
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCreoTheme(),
        home: WorkstationPublishingPage(session: session),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Client'), findsOneWidget);
    expect(find.text('Plan posts from calendars'), findsNothing);
    await tester.tap(find.text('Brand launch'));
    await tester.pumpAndSettle();
    expect(find.text('Approved caption'), findsOneWidget);
    expect(find.text('Custom time & caption'), findsNothing);
    expect(find.text('Post now'), findsNothing);
    expect(find.text('Cancel auto-post'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Brand launch'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'message history disappears on logout and late results stay rejected',
    (tester) async {
      final pending = Completer<http.Response>();
      var messageReads = 0;
      final session = await hubOwner((request) async {
        if (request.url.path.endsWith('/channels')) return jsonResponse([]);
        if (request.url.path.endsWith('/contacts')) {
          return jsonResponse([
            {'id': 'admin', 'name': 'Workspace admin'},
          ]);
        }
        messageReads++;
        if (messageReads == 1) {
          return jsonResponse([
            {'id': 'm1', 'message': 'Private message', 'sender_name': 'Admin'},
          ]);
        }
        return pending.future;
      });
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCreoTheme(),
          home: WorkstationHubPage(session: session),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Workspace admin'));
      await tester.pumpAndSettle();
      expect(find.text('Private message'), findsOneWidget);
      await tester.tap(find.byTooltip('Refresh').last);
      await tester.pump();
      await session.logout(notifyServer: false);
      await tester.pump();
      expect(find.text('Private message'), findsNothing);
      pending.complete(
        jsonResponse([
          {'id': 'm2', 'message': 'Late private result'},
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Late private result'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'ambiguous chat write is shared across reopened conversations and reconciles only new own history',
    () async {
      var writes = 0;
      List<Object> history = [];
      final session = await hubOwner((request) async {
        if (request.url.path.endsWith('/contacts')) {
          return jsonResponse([
            {'id': 'admin'},
          ]);
        }
        if (request.method == 'GET') return jsonResponse(history);
        writes++;
        return writes == 1
            ? jsonResponse({'detail': 'Unavailable'}, 503)
            : jsonResponse({'id': 'sent'});
      });
      addTearDown(session.dispose);
      final first = WorkstationHubRepository(session);
      await first.contacts();
      await first.messages('admin', direct: true);
      await expectLater(
        first.send('admin', 'Check the cut', direct: true),
        throwsA(code('WRITE_UNCONFIRMED')),
      );
      final reopened = WorkstationHubRepository(session);
      await reopened.contacts();
      await expectLater(
        reopened.send('admin', 'Check the cut', direct: true),
        throwsA(code('WRITE_UNCONFIRMED')),
      );
      expect(writes, 1);
      history = [
        {
          'id': 'new',
          'sender_id': 'another-person',
          'message': 'Check the cut',
        },
      ];
      await reopened.messages('admin', direct: true);
      await expectLater(
        reopened.send('admin', 'Check the cut', direct: true),
        throwsA(code('WRITE_UNCONFIRMED')),
      );
      history = [
        {'id': 'new-own', 'sender_id': 'account-a', 'message': 'Check the cut'},
      ];
      await reopened.messages('admin', direct: true);
      expect(
        reopened.takeConfirmedMessage('admin', direct: true)?['id'],
        'new-own',
      );
      await reopened.send('admin', 'A different message', direct: true);
      expect(writes, 2);
    },
  );

  test(
    'ambiguous publishing schedule stays blocked after reopening and malformed success is unconfirmed',
    () async {
      var writes = 0;
      final session = await hubOwner((request) async {
        if (request.method == 'GET') return jsonResponse({'can_manage': true});
        writes++;
        return jsonResponse({});
      });
      addTearDown(session.dispose);
      final first = WorkstationHubRepository(session);
      await expectLater(
        first.schedule(
          'deliverable',
          caption: 'Caption',
          mediaType: 'IMAGE',
          localTime: '2030-11-09T14:30',
        ),
        throwsA(code('WRITE_UNCONFIRMED')),
      );
      final reopened = WorkstationHubRepository(session);
      await expectLater(
        reopened.schedule(
          'deliverable',
          caption: 'Caption',
          mediaType: 'IMAGE',
          localTime: '2030-11-09T14:30',
        ),
        throwsA(code('WRITE_UNCONFIRMED')),
      );
      expect(writes, 1);
    },
  );

  testWidgets('conversation composer fits narrow keyboard and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = await hubOwner((request) async {
      if (request.url.path.endsWith('/contacts')) {
        return jsonResponse([
          {'id': 'admin', 'name': 'Admin'},
        ]);
      }
      return jsonResponse([]);
    });
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCreoTheme(),
        builder: (_, child) => MediaQuery(
          data: const MediaQueryData(
            size: Size(280, 520),
            textScaler: TextScaler.linear(2),
            viewInsets: EdgeInsets.only(bottom: 220),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: WorkstationHubPage(session: session),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Admin'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Admin')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();
    expect(find.text('Send'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
