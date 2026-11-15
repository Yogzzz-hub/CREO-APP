import 'package:app_flutter/src/core/app_theme.dart';
import 'package:app_flutter/src/features/workstation/workstation_meetings_page.dart';
import 'package:app_flutter/src/features/workstation/workstation_page.dart';
import 'package:app_flutter/src/features/workstation/workstation_data.dart';
import 'package:app_flutter/src/features/workstation/workstation_preview_fixtures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Feedback preferences persist by account and clear alongside meeting settings',
    () async {
      final records = <String, String>{};
      final store = WorkstationMeetingStore(
        read: (key) async => records[key],
        write: (key, value) async {
          if (value == null) {
            records.remove(key);
          } else {
            records[key] = value;
          }
        },
      );
      await store.saveFeedback('account-a', {
        'task:1:first feedback',
      }, isCurrent: () => true);
      await store.saveFeedback('account-b', {
        'other:1:feedback',
      }, isCurrent: () => true);
      expect(await store.loadFeedback('account-a'), {'task:1:first feedback'});
      expect(await store.loadFeedback('account-b'), {'other:1:feedback'});
      await store.clear('account-a');
      expect(await store.loadFeedback('account-a'), isEmpty);
      expect(await store.loadFeedback('account-b'), {'other:1:feedback'});
    },
  );

  testWidgets(
    'Quick reply chooses a server channel, sends once and clears the confirmed draft',
    (tester) async {
      final fixtures = WorkstationPreviewFixtures();
      final session = fixtures.createSession();
      await session.restore();
      final preferences = WorkstationMeetingStore(
        read: (_) async => null,
        write: (_, _) async {},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCreoTheme(),
          home: WorkstationMeetingScope(
            store: preferences,
            child: WorkstationPage(
              user: session.current!.user,
              session: session,
              load: WorkstationRepository(session).load,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final send = find.text('Choose channel & send');
      await tester.scrollUntilVisible(
        send,
        450,
        scrollable: find.byType(Scrollable).first,
      );
      final input = find.widgetWithText(TextField, 'Reply to your pod');
      await tester.enterText(input, 'Sample reply from the dashboard');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.text('Send reply to…'), findsOneWidget);
      final conversation = find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(ListTile),
          )
          .first;
      await tester.tap(conversation);
      await tester.pumpAndSettle();
      expect(find.text('Reply sent.'), findsOneWidget);
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      fixtures.close();
    },
  );

  testWidgets(
    'Dismissed review notes persist across page disposal and can be restored',
    (tester) async {
      final fixtures = WorkstationPreviewFixtures();
      final session = fixtures.createSession();
      await session.restore();
      final records = <String, String>{};
      final store = WorkstationMeetingStore(
        read: (key) async => records[key],
        write: (key, value) async {
          if (value == null) {
            records.remove(key);
          } else {
            records[key] = value;
          }
        },
      );
      Widget app() => MaterialApp(
        key: UniqueKey(),
        theme: buildCreoTheme(),
        home: WorkstationMeetingScope(
          store: store,
          child: WorkstationPage(
            user: session.current!.user,
            session: session,
            load: WorkstationRepository(session).load,
          ),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final dismiss = find.text('Dismiss feedback').first;
      await tester.scrollUntilVisible(
        dismiss,
        450,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(dismiss);
      await tester.pumpAndSettle();
      expect(await store.loadFeedback(session.current!.user.id), hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final restore = find.text('Show dismissed feedback');
      await tester.scrollUntilVisible(
        restore,
        450,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(restore);
      await tester.pumpAndSettle();
      expect(await store.loadFeedback(session.current!.user.id), isEmpty);
      expect(find.text('Dismiss feedback'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      fixtures.close();
    },
  );
}
