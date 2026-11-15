import 'dart:async';
import 'dart:convert';

import 'package:app_flutter/src/core/app_theme.dart';
import 'package:app_flutter/src/core/auth_repository.dart';
import 'package:app_flutter/src/core/auth_session.dart';
import 'package:app_flutter/src/features/workstation/workstation_account_pages.dart';
import 'package:app_flutter/src/features/workstation/workstation_account_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'auth_contract_test.dart' show MemorySessionStore, code, sessionJson;
import 'session_lifecycle_test.dart' show owner, saved, profile, jsonResponse;
import 'workstation_test.dart' show dashboardJson;

Map<String, dynamic> leaveJson({
  String id = 'request-a',
  bool self = true,
  bool cancel = true,
  String status = 'pending',
}) => {
  'id': id,
  'start_date': '2030-01-02',
  'end_date': '2030-01-03',
  'reason': 'Family commitment',
  'status': status,
  'is_self': self,
  'can_cancel': cancel,
  'team_lead_name': 'Lead',
};

Future<AuthSession> account(
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

Widget app(Widget page, {double scale = 1, bool light = false}) => MaterialApp(
  theme: buildCreoTheme(brightness: light ? Brightness.light : Brightness.dark),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
    child: child!,
  ),
  home: page,
);

void main() {
  testWidgets(
    'Freelancer recovery verifies OTP and adopts only same-account session',
    (tester) async {
      var sends = 0, verifies = 0, resets = 0;
      const password = ' password123 ';
      final session = await account((request) async {
        final body = jsonDecode(request.body);
        if (request.url.path.endsWith('/forgot-password')) {
          sends++;
          expect(body, {'email': 'user@example.test'});
          return jsonResponse({'status': 'sent'});
        }
        if (request.url.path.endsWith('/verify-reset-otp')) {
          verifies++;
          expect(body, {'email': 'user@example.test', 'code': '123456'});
          return jsonResponse({
            'reset_token': 'one-time-test-token',
            'sign_in_methods': ['password'],
          });
        }
        if (request.url.path.endsWith('/reset-password')) {
          resets++;
          expect(body, {
            'reset_token': 'one-time-test-token',
            'new_password': password,
          });
          return jsonResponse(sessionJson(role: 'freelancer'));
        }
        throw StateError('Unexpected request');
      });
      await tester.pumpWidget(
        app(
          WorkstationPasswordPage(session: session, email: 'user@example.test'),
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Send code'));
      await tester.pumpAndSettle();
      expect(sends, 1);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Resend code in 60s'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), '123456');
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Verify code'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Verify code'));
      await tester.pumpAndSettle();
      expect(verifies, 1);
      await tester.enterText(find.byType(TextField).first, password);
      await tester.enterText(find.byType(TextField).last, password);
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Save password'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save password'));
      await tester.pumpAndSettle();
      expect(resets, 1);
      expect(find.text('Password saved'), findsOneWidget);
      expect(session.current!.user.id, 'account-a');
      expect(session.phase, SessionPhase.authenticated);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  test('Leave dates validate UTC calendar, range and nonempty reason', () {
    final now = DateTime.utc(2030, 1, 2, 23);
    expect(
      WorkstationAccountRepository.validateLeave('', '', 'x', now),
      isNotNull,
    );
    expect(
      WorkstationAccountRepository.validateLeave(
        '2030-01-01',
        '2030-01-03',
        'x',
        now,
      ),
      contains('past'),
    );
    expect(
      WorkstationAccountRepository.validateLeave(
        '2030-01-03',
        '2030-01-02',
        'x',
        now,
      ),
      contains('End date'),
    );
    expect(
      WorkstationAccountRepository.validateLeave(
        '2030-01-02',
        '2030-01-02',
        '  ',
        now,
      ),
      contains('reason'),
    );
    expect(
      WorkstationAccountRepository.validateLeave(
        '2030-01-02',
        '2030-01-02',
        'x',
        now,
      ),
      isNull,
    );
  });

  test(
    'Leave list honors server self/cancellation flags and direct array contract',
    () async {
      final session = await account((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/leave');
        expect(request.headers['authorization'], startsWith('Bearer '));
        return jsonResponse([leaveJson(), leaveJson(id: 'other', self: false)]);
      });
      final rows = await WorkstationAccountRepository(
        session,
        freelancer: true,
      ).leaves();
      expect(rows.single.id, 'request-a');
      expect(rows.single.days, 2);
      expect(rows.single.canCancel, true);
      expect(
        WorkspaceLeave.fromJson(
          {...leaveJson()}..remove('can_cancel'),
        ).canCancel,
        false,
      );
      session.dispose();
    },
  );

  test(
    'Staff leave payload trims reason; freelancer preserves blackout prefix',
    () async {
      for (final freelancer in [false, true]) {
        var writes = 0;
        final session = await account((request) async {
          writes++;
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/admin/leave');
          expect(jsonDecode(request.body), {
            'start_date': '2030-01-02',
            'end_date': '2030-01-03',
            'reason': freelancer
                ? '[Freelancer Blackout: Medical / Rest] Notes'
                : 'Notes',
          });
          return jsonResponse({'status': 'pending'});
        }, role: freelancer ? 'freelancer' : 'editor');
        await WorkstationAccountRepository(
          session,
          freelancer: freelancer,
        ).requestLeave(
          '2030-01-02',
          '2030-01-03',
          '  Notes  ',
          category: 'Medical / Rest',
          now: DateTime.utc(2030),
        );
        expect(writes, 1);
        session.dispose();
      }
    },
  );

  test(
    'Cancellation denies other users/noncancellable and encodes IDs',
    () async {
      var calls = 0;
      final session = await account((request) async {
        calls++;
        expect(request.method, 'DELETE');
        expect(request.url.pathSegments.last, 'request-a');
        return jsonResponse({'status': 'cancelled'});
      });
      final repo = WorkstationAccountRepository(session, freelancer: true);
      await expectLater(
        repo.cancelLeave(WorkspaceLeave.fromJson(leaveJson(self: false))),
        throwsA(code('FORBIDDEN')),
      );
      await expectLater(
        repo.cancelLeave(WorkspaceLeave.fromJson(leaveJson(cancel: false))),
        throwsA(code('FORBIDDEN')),
      );
      expect(calls, 0);
      await repo.cancelLeave(WorkspaceLeave.fromJson(leaveJson()));
      expect(calls, 1);
      session.dispose();
    },
  );

  test(
    'Profile GET/PATCH contract preserves owner and updates shared name',
    () async {
      final session = await account((request) async {
        expect(request.url.path, '/api/v1/users/me');
        if (request.method == 'PATCH') {
          expect(jsonDecode(request.body), {
            'full_name': 'Updated Name',
            'phone': '+91 123',
          });
          return jsonResponse({
            ...profile(),
            'role': 'freelancer',
            'full_name': 'Updated Name',
            'phone': '+91 123',
          });
        }
        return jsonResponse({...profile(), 'role': 'freelancer', 'phone': ''});
      });
      final repo = WorkstationAccountRepository(session, freelancer: true);
      expect((await repo.profile()).id, 'account-a');
      final result = await repo.saveProfile('  Updated Name  ', ' +91 123 ');
      expect(result.name, 'Updated Name');
      expect(result.phone, '+91 123');
      expect(session.current!.user.fullName, 'Updated Name');
      session.dispose();
    },
  );

  test('Cross-role account repository denied before transport', () async {
    var calls = 0;
    final session = await account((_) async {
      calls++;
      return jsonResponse({});
    }, role: 'client');
    for (final freelancer in [false, true]) {
      await expectLater(
        WorkstationAccountRepository(session, freelancer: freelancer).profile(),
        throwsA(code('FORBIDDEN')),
      );
    }
    expect(calls, 0);
    session.dispose();
  });

  test(
    'Late profile after logout rejected; malformed list is not empty success',
    () async {
      final pending = Completer<http.Response>();
      final session = await account((_) => pending.future);
      final result = WorkstationAccountRepository(
        session,
        freelancer: true,
      ).profile();
      await Future<void>.delayed(Duration.zero);
      await session.logout(notifyServer: false);
      pending.complete(jsonResponse({...profile(), 'role': 'freelancer'}));
      await expectLater(result, throwsA(isA<HttpError>()));
      session.dispose();
      final other = await account((_) async => jsonResponse({'wrong': []}));
      await expectLater(
        WorkstationAccountRepository(other, freelancer: true).leaves(),
        throwsFormatException,
      );
      other.dispose();
    },
  );

  testWidgets(
    'Leave errors retain form, retry loads, server cancellation works',
    (tester) async {
      var reads = 0, cancels = 0;
      final session = await account((request) async {
        if (request.method == 'DELETE') {
          cancels++;
          return jsonResponse({'status': 'cancelled'});
        }
        reads++;
        return reads == 1
            ? jsonResponse({'detail': 'Offline'}, 503)
            : jsonResponse([leaveJson()]);
      });
      await tester.pumpWidget(
        app(WorkstationSchedulePage(session: session, freelancer: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cancel request'));
      await tester.tap(find.text('Cancel request'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel request'));
      await tester.pumpAndSettle();
      expect(cancels, 1);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'Profile save blocks duplicate taps and retains values on server error',
    (tester) async {
      final pending = Completer<http.Response>();
      var writes = 0;
      final session = await account((request) async {
        if (request.method == 'PATCH') {
          writes++;
          return pending.future;
        }
        return jsonResponse({...profile(), 'role': 'freelancer', 'phone': ''});
      });
      await tester.pumpWidget(
        app(WorkstationSettingsPage(session: session, freelancer: true)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'My updated name',
      );
      final button = find.widgetWithText(FilledButton, 'Save changes');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Saving changes…'),
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Saving changes…'),
            )
            .onPressed,
        isNull,
      );
      await tester.tapAt(
        tester.getCenter(find.widgetWithText(FilledButton, 'Saving changes…')),
      );
      await tester.pump();
      expect(writes, 1);
      pending.complete(jsonResponse({'detail': 'Unable to save'}, 500));
      await tester.pumpAndSettle();
      expect(find.text('My updated name'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'Account pages fit narrow 200% text and landscape in both themes',
    (tester) async {
      for (final freelancer in [false, true]) {
        final session = await account((request) async {
          if (request.url.path.endsWith('pod-dashboard')) {
            return jsonResponse(dashboardJson());
          }
          if (request.url.path.endsWith('/leave')) {
            return jsonResponse([leaveJson()]);
          }
          return jsonResponse({
            ...profile(),
            'role': freelancer ? 'freelancer' : 'editor',
            'phone': '',
          });
        }, role: freelancer ? 'freelancer' : 'editor');
        for (final size in [const Size(280, 520), const Size(852, 393)]) {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          for (final light in [false, true]) {
            for (final page in [
              WorkstationSchedulePage(session: session, freelancer: freelancer),
              WorkstationSettingsPage(session: session, freelancer: freelancer),
            ]) {
              await tester.pumpWidget(app(page, scale: 2, light: light));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox());
            }
          }
        }
        session.dispose();
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  test(
    'Profile sparse PATCH preserves auth metadata omitted by backend',
    () async {
      final store = MemorySessionStore()..value = saved();
      final session = owner(store, (request) async {
        if (request.method == 'PATCH') {
          return jsonResponse({
            'id': 'account-a',
            'email': 'user@example.test',
            'full_name': 'Updated',
            'phone': '123',
            'role': 'freelancer',
            'account_status': 'active',
            'onboarding_stage': 5,
          });
        }
        return jsonResponse({
          ...profile(),
          'role': 'freelancer',
          'company_name': 'Company',
          'terms_accepted': true,
          'onboarding_status': 'complete',
          'sign_in_methods': ['password', 'google'],
          'must_reset_password': false,
        });
      });
      await session.restore();
      final updated = await session.updateProfile(
        fullName: 'Updated',
        phone: '123',
      );
      expect(updated.companyName, 'Company');
      expect(updated.termsAccepted, true);
      expect(updated.onboardingStatus, 'complete');
      expect(updated.signInMethods, ['password', 'google']);
      expect(updated.mustResetPassword, false);
      session.dispose();
    },
  );

  test(
    'Profile PATCH rejects a different account without committing credentials',
    () async {
      final session = await account(
        (_) async => jsonResponse({
          ...profile(id: 'another-account'),
          'role': 'freelancer',
          'full_name': 'Other',
        }),
      );
      await expectLater(
        session.updateProfile(fullName: 'Other', phone: ''),
        throwsA(code('ACCOUNT_MISMATCH')),
      );
      expect(session.current!.user.id, 'account-a');
      session.dispose();
    },
  );

  test(
    'Logout during queued profile storage write prevents reauthentication',
    () async {
      final store = MemorySessionStore()..value = saved();
      final session = owner(
        store,
        (request) async => jsonResponse({
          ...profile(),
          'role': 'freelancer',
          'full_name': request.method == 'PATCH' ? 'Updated' : 'Before',
        }),
      );
      await session.restore();
      final pause = Completer<void>();
      store.pause = pause;
      final pending = session.updateProfile(fullName: 'Updated', phone: '');
      final assertion = expectLater(
        pending,
        throwsA(code('SESSION_CANCELLED')),
      );
      await Future<void>.delayed(Duration.zero);
      final logout = session.logout(notifyServer: false);
      pause.complete();
      await assertion;
      await logout;
      expect(session.phase, SessionPhase.signedOut);
      expect(session.current, isNull);
      expect(store.value, isNull);
      session.dispose();
    },
  );

  test(
    'Profile storage failure is explicit and recoverable without dropping credentials',
    () async {
      final store = MemorySessionStore()..value = saved();
      final session = owner(
        store,
        (request) async => jsonResponse({
          ...profile(),
          'role': 'freelancer',
          'full_name': request.method == 'PATCH' ? 'Updated' : 'Before',
        }),
      );
      await session.restore();
      final previous = store.value;
      store.failNext = true;
      await expectLater(
        session.updateProfile(fullName: 'Updated', phone: ''),
        throwsA(isA<HttpError>()),
      );
      expect(store.value?.userId, previous?.userId);
      expect(store.value?.refreshToken, previous?.refreshToken);
      await session.restore();
      expect(
        (await session.updateProfile(fullName: 'Updated', phone: '')).fullName,
        'Updated',
      );
      session.dispose();
    },
  );
}
