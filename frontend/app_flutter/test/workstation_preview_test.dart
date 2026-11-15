import 'package:app_flutter/workstation_journey_preview.dart';
import 'package:app_flutter/src/features/workstation/workstation_preview_fixtures.dart';
import 'package:app_flutter/src/features/workstation/workstation_notifications_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test(
    'Isolated notification fixtures satisfy the real repository mutation statuses',
    () async {
      final transport = WorkstationPreviewFixtures();
      final session = transport.createSession();
      await session.restore();
      final repository = WorkstationNotificationsRepository(session);
      final initial = await repository.load();
      expect(initial.unreadCount, 1);
      final id = initial.items.single.id;
      expect((await repository.markRead(id)).items.single.isRead, true);
      expect((await repository.markAllRead()).unreadCount, 0);
      expect((await repository.delete(id)).items, isEmpty);
      expect((await repository.clearAll()).items, isEmpty);
      session.dispose();
      transport.close();
    },
  );
  test('preview transport refuses live hosts and unknown actions', () async {
    final transport = WorkstationPreviewFixtures();
    await expectLater(
      transport.send(
        http.Request(
          'GET',
          Uri.parse('https://api.example.test/api/v1/auth/me'),
        ),
      ),
      throwsA(isA<http.ClientException>()),
    );
    final response = await transport.send(
      http.Request(
        'POST',
        Uri.parse(
          'https://preview.example.invalid/api/v1/not-a-preview-endpoint',
        ),
      ),
    );
    expect(response.statusCode, 404);
    transport.close();
  });

  testWidgets(
    'editor journey uses real session gate and task navigation with persistent fixture banner',
    (tester) async {
      await tester.pumpWidget(const WorkstationJourneyPreview());
      await tester.pumpAndSettle();
      expect(
        find.text('DEVELOPMENT PREVIEW · Sample data · No live account'),
        findsOneWidget,
      );
      expect(find.text('Sample Creative Pod'), findsWidgets);
      await tester.tap(find.text('Tasks').last);
      await tester.pumpAndSettle();
      expect(find.text('My tasks'), findsOneWidget);
      expect(find.text('Autumn launch · First cut'), findsWidgets);
      expect(
        find.text('DEVELOPMENT PREVIEW · Sample data · No live account'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('freelancer preview opens isolated freelancer workspace', (
    tester,
  ) async {
    await tester.pumpWidget(
      const WorkstationJourneyPreview(role: 'freelancer'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Freelancer workspace'), findsOneWidget);
    expect(find.text('Assigned workload'), findsOneWidget);
    expect(
      find.text('DEVELOPMENT PREVIEW · Sample data · No live account'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
