import 'dart:async';
import 'dart:convert';
import 'package:app_flutter/src/core/app_theme.dart';
import 'package:app_flutter/src/features/workstation/workstation_meetings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'workstation_account_test.dart' show account;

void main() {
  test(
    'Meeting defaults, code fallback and legacy placeholders match React',
    () {
      final defaults = WorkstationMeetingConfig.normalized('', '', '');
      expect(defaults.meetUrl, 'https://meet.google.com');
      expect(defaults.zoomUrl, 'https://zoom.us/join');
      final custom = WorkstationMeetingConfig.normalized(
        ' abc-defg-hij ',
        '',
        ' https://example.test/zoom ',
      );
      expect(custom.code, 'abc-defg-hij');
      expect(custom.meetUrl, 'https://meet.google.com/abc-defg-hij');
      expect(custom.zoomUrl, 'https://example.test/zoom');
      final legacy = WorkstationMeetingConfig.fromJson({
        'code': 'creo-standup-sync',
        'meet_url': 'https://meet.google.com/creo-standup-sync',
        'zoom_url': 'https://zoom.us/join',
      });
      expect(legacy.code, '');
      expect(legacy.meetUrl, defaults.meetUrl);
    },
  );

  test('Unsafe meeting schemes and URL credentials cannot launch', () {
    for (final url in [
      'javascript:alert(1)',
      'http://example.test',
      'file:///private',
      'https://user:password@example.test',
      'not a link',
    ]) {
      expect(WorkstationMeetingConfig.safeLink(url), isNull);
      expect(
        () => WorkstationMeetingConfig.normalized('', url, ''),
        throwsFormatException,
      );
    }
  });

  test(
    'Meeting preference record survives recreation and stays account-scoped',
    () async {
      final values = <String, String>{};
      WorkstationMeetingStore create() => WorkstationMeetingStore(
        read: (key) async => values[key],
        write: (key, value) async {
          if (value == null) {
            values.remove(key);
          } else {
            values[key] = value;
          }
        },
      );
      final first = create();
      await first.save(
        'account-a',
        WorkstationMeetingConfig.normalized('abc', '', ''),
      );
      expect((await create().load('account-a')).code, 'abc');
      expect((await create().load('account-b')).code, '');
      await create().clear('account-a');
      expect((await first.load('account-a')).code, '');
    },
  );

  test(
    'Pending meeting save cannot restore private preferences after logout cleanup',
    () async {
      final values = <String, String>{};
      final started = Completer<void>(), release = Completer<void>();
      var valid = true;
      final store = WorkstationMeetingStore(
        read: (key) async => values[key],
        write: (key, value) async {
          if (value != null) {
            started.complete();
            await release.future;
            values[key] = value;
          } else {
            values.remove(key);
          }
        },
      );
      final save = store.save(
        'account-a',
        const WorkstationMeetingConfig(code: 'abc'),
        isCurrent: () => valid,
      );
      final rejected = expectLater(save, throwsStateError);
      await started.future;
      valid = false;
      final clear = store.clear('account-a');
      release.complete();
      await rejected;
      await clear;
      expect(values, isEmpty);
    },
  );

  test(
    'Corrupt and failed preference storage are explicit, retry remains possible',
    () async {
      var failed = true;
      final store = WorkstationMeetingStore(
        read: (_) async => failed ? 'not-json' : null,
        write: (_, value) async {
          if (failed) throw StateError('Unavailable');
        },
      );
      await expectLater(store.load('a'), throwsFormatException);
      await expectLater(
        store.save('a', const WorkstationMeetingConfig()),
        throwsStateError,
      );
      failed = false;
      await store.save('a', const WorkstationMeetingConfig());
      expect((await store.load('a')).code, '');
    },
  );

  testWidgets(
    'Meeting settings save, copy feedback and provider navigation work',
    (tester) async {
      final values = <String, String>{};
      final launched = <Uri>[];
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'];
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final session = await account(
        (_) async => throw StateError('Meetings must not call APIs'),
        role: 'editor',
      );
      final store = WorkstationMeetingStore(
        read: (key) async => values[key],
        write: (key, value) async {
          if (value == null) {
            values.remove(key);
          } else {
            values[key] = value;
          }
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCreoTheme(),
          home: WorkstationMeetingsPage(
            session: session,
            store: store,
            openLink: (uri) async {
              launched.add(uri);
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Configure meeting link / code'));
      await tester.tap(find.text('Configure meeting link / code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'abc-defg-hij');
      expect(
        (tester.widget<TextField>(
          find.byType(TextField).at(1),
        )).controller!.text,
        'https://meet.google.com/abc-defg-hij',
      );
      await tester.ensureVisible(find.text('Save meeting settings'));
      await tester.tap(find.text('Save meeting settings'));
      await tester.pumpAndSettle();
      expect(jsonDecode(values.values.single)['code'], 'abc-defg-hij');
      await tester.ensureVisible(find.text('Copy meet code'));
      await tester.tap(find.text('Copy meet code'));
      await tester.pump();
      expect(clipboard, 'abc-defg-hij');
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Copy meet code'), findsOneWidget);
      await tester.ensureVisible(find.text('Redirect to Google Meet'));
      await tester.tap(find.text('Redirect to Google Meet'));
      await tester.pumpAndSettle();
      expect(
        launched.single.toString(),
        'https://meet.google.com/abc-defg-hij',
      );
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Zoom'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Zoom'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Redirect to Zoom'));
      await tester.tap(find.text('Redirect to Zoom'));
      await tester.pumpAndSettle();
      expect(launched.last.toString(), 'https://zoom.us/join');
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'Meeting settings respect denied roles and narrow large-text layouts',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(280, 520);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = WorkstationMeetingStore(
        read: (_) async => null,
        write: (_, value) async {},
      );
      for (final role in ['client', 'editor']) {
        final session = await account(
          (_) async => throw StateError('No API calls'),
          role: role,
        );
        for (final brightness in [Brightness.dark, Brightness.light]) {
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
              home: WorkstationMeetingsPage(session: session, store: store),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (role == 'editor') {
            await tester.ensureVisible(
              find.text('Configure meeting link / code'),
            );
            await tester.tap(find.text('Configure meeting link / code'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        }
        session.dispose();
      }
    },
  );
}
