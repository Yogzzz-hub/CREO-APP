import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:app_flutter/src/features/onboarding/onboarding_repository.dart';
import 'package:app_flutter/src/features/onboarding/client_onboarding_page.dart';
import 'team_lead_test.dart' show signedIn;
import 'auth_contract_test.dart' show code;

void main() {
  testWidgets(
    'optional brand failure does not hide resumed questionnaire at narrow width',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = await signedIn((request) async {
        if (request.url.path.endsWith('/status') &&
            !request.url.path.endsWith('brand-dna/status'))
          return http.Response(
            '{"stage":3,"stage_name":"Questionnaire","next_required_stage":"questionnaire","resume_section":"b"}',
            200,
          );
        if (request.url.path.endsWith('/questionnaire'))
          return http.Response(
            '{"section_b":{"ideal_customer":"Existing audience"},"core_completed":false}',
            200,
          );
        return http.Response(
          '{"code":"NOT_FOUND","message":"Not available"}',
          404,
        );
      }, role: 'client');
      await tester.pumpWidget(
        MaterialApp(home: ClientOnboardingPage(session: session)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Existing audience'), findsOneWidget);
      expect(find.text('Questionnaire'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  test(
    'unverified section response blocks duplicate save across reopened page repositories',
    () async {
      var writes = 0;
      final session = await signedIn((request) async {
        writes++;
        return http.Response('{}', 200);
      }, role: 'client');
      await expectLater(
        ClientOnboardingRepository(
          session,
        ).save('g', {}, {'vision': 'A vision'}),
        throwsA(code('WRITE_UNCONFIRMED')),
      );
      await expectLater(
        ClientOnboardingRepository(
          session,
        ).save('g', {}, {'vision': 'A vision'}),
        throwsA(code('WRITE_UNCONFIRMED')),
      );
      expect(writes, 1);
      session.dispose();
    },
  );
  test(
    'section save preserves unknown fields and excludes untouched defaults',
    () async {
      final session = await signedIn((request) async {
        expect(request.url.path, '/api/v1/onboarding/questionnaire/sections');
        expect(jsonDecode(request.body), {
          'sections': {
            'a': {
              'future_field': {'preserved': true},
              'brand_name': 'Updated',
            },
          },
          'active_section': 'a',
        });
        return http.Response('{"version":2,"core_completed":false}', 200);
      }, role: 'client');
      final repo = ClientOnboardingRepository(session);
      await repo.save(
        'a',
        {
          'future_field': {'preserved': true},
          'brand_name': 'Original',
        },
        {'brand_name': 'Updated'},
      );
      await session.logout(notifyServer: false);
      await expectLater(repo.read('status'), throwsA(code('FORBIDDEN')));
      session.dispose();
    },
  );
  testWidgets(
    'terms never accepted automatically; explicit checkbox and click required',
    (tester) async {
      var writes = 0;
      final session = await signedIn((request) async {
        if (request.method == 'POST') {
          writes++;
          expect(jsonDecode(request.body), {'terms_version': 'v1.0'});
          return http.Response('{"status":"ok"}', 200);
        }
        return http.Response(
          '{"stage":1,"stage_name":"Terms","next_required_stage":"terms","is_complete":false}',
          200,
        );
      }, role: 'client');
      await tester.pumpWidget(
        MaterialApp(home: ClientOnboardingPage(session: session)),
      );
      await tester.pumpAndSettle();
      expect(writes, 0);
      await tester.scrollUntilVisible(
        find.text('Accept agreement'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Accept agreement'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('Accept agreement'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets(
    'payment blocker stays truthful with no payment or completion mutation',
    (tester) async {
      final session = await signedIn((request) async {
        expect(request.method, 'GET');
        return http.Response(
          '{"stage":2,"stage_name":"Payment","next_required_stage":"payment","is_complete":false}',
          200,
        );
      }, role: 'client');
      await tester.pumpWidget(
        MaterialApp(home: ClientOnboardingPage(session: session)),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Mobile Razorpay checkout is not available'),
        findsOneWidget,
      );
      expect(find.text('Complete setup and allocate team'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
