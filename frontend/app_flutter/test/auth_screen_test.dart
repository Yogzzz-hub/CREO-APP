import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:app_flutter/src/core/app_theme.dart';
import 'package:app_flutter/src/core/auth_repository.dart';
import 'package:app_flutter/src/core/auth_session.dart';
import 'package:app_flutter/src/features/auth/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'auth_contract_test.dart' show MemorySessionStore, sessionJson;

void main() {
  final email = find.byKey(const Key('login-email'));
  final password = find.byKey(const Key('login-password'));
  final submit = find.byType(ElevatedButton);
  final captureKey = GlobalKey();
  Future<MemorySessionStore> mount(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) handler, {
    ValueChanged<DestinationIntent>? onDestination,
    double width = 390,
    double scale = 1,
    bool reduceMotion = false,
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = Size(width, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemorySessionStore();
    final repo = AuthRepository(
      origin: Uri.parse('https://api.example.test'),
      store: store,
      client: MockClient(handler),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          theme: buildCreoTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 740),
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduceMotion,
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: AuthScreen(
              repository: repo,
              session: AuthSession(store: store),
              onDestination: onDestination,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(email, ' user@example.test ');
    await tester.enterText(password, ' original password ');
  }

  Future<void> press(WidgetTester tester) async {
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
  }

  testWidgets('T01-T04 validation focuses invalid field', (tester) async {
    var calls = 0;
    await mount(tester, (_) async {
      calls++;
      return http.Response('{}', 500);
    });
    await press(tester);
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: email, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus,
      true,
    );
    await tester.enterText(email, 'invalid');
    await press(tester);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    await tester.enterText(email, 'user@example.test');
    await press(tester);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: password, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus,
      true,
    );
    expect(calls, 0);
    expect(validateLoginPassword('x'), null);
    expect(validateLoginPassword('x' * 129), isNotNull);
  });
  testWidgets(
    'original payload, duplicate taps, slow hint and destination intent',
    (tester) async {
      final response = Completer<http.Response>();
      var calls = 0;
      DestinationIntent? intent;
      final store = await mount(tester, (r) {
        calls++;
        expect(jsonDecode(r.body)['password'], ' original password ');
        return response.future;
      }, onDestination: (v) => intent = v);
      await fill(tester);
      await press(tester);
      await press(tester);
      expect(calls, 1);
      expect(tester.widget<ElevatedButton>(submit).onPressed, null);
      await tester.pump(const Duration(milliseconds: 3501));
      expect(find.text('Waking up the server...'), findsOneWidget);
      response.complete(http.Response(jsonEncode(sessionJson()), 200));
      await tester.pumpAndSettle();
      expect(intent?.path, '/portal');
      expect(intent?.blocker, isNotNull);
      expect(store.value?.userId, 'account-a');
      expect(find.byKey(const Key('destination-status')), findsOneWidget);
      expect(tester.widget<TextFormField>(password).controller!.text, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    },
  );
  testWidgets('cancel then retry ignores late first response', (tester) async {
    final first = Completer<http.Response>();
    final second = Completer<http.Response>();
    var calls = 0;
    final store = await mount(
      tester,
      (_) => ++calls == 1 ? first.future : second.future,
    );
    await fill(tester);
    await press(tester);
    final cancel = find.text('Cancel sign-in');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pump();
    await press(tester);
    first.complete(http.Response(jsonEncode(sessionJson()), 200));
    await tester.pump();
    expect(store.value, null);
    second.complete(
      http.Response(jsonEncode(sessionJson(id: 'account-b')), 200),
    );
    await tester.pumpAndSettle();
    expect(store.value?.userId, 'account-b');
  });
  testWidgets('dispose during login cannot write a late session', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final store = await mount(tester, (_) => response.future);
    await fill(tester);
    await press(tester);
    await tester.pumpWidget(const SizedBox());
    response.complete(http.Response(jsonEncode(sessionJson()), 200));
    await tester.pump();
    expect(store.writes, 0);
    expect(tester.takeException(), null);
  });
  testWidgets('method notice preserves recovery, Google, and input', (
    tester,
  ) async {
    await mount(
      tester,
      (_) async => http.Response(
        jsonEncode({
          'error': {
            'code': 'PASSWORD_NOT_SET',
            'message': 'No password',
            'details': {
              'sign_in_methods': ['google'],
            },
          },
        }),
        401,
      ),
    );
    await fill(tester);
    await press(tester);
    await tester.pumpAndSettle();
    expect(find.text('This account uses Google sign-in'), findsOneWidget);
    expect(find.text('Set a password'), findsOneWidget);
    expect(find.text('Continue with Google'), findsWidgets);
    expect(
      tester.widget<TextFormField>(password).controller!.text,
      ' original password ',
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.liveRegion == true,
      ),
      findsWidgets,
    );
  });
  testWidgets('T22-T26 focus traversal, visibility, autofill and IME submit', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    var calls = 0;
    await mount(tester, (_) {
      calls++;
      return pending.future;
    });
    await tester.enterText(email, 'user@example.test');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: password, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus,
      true,
    );
    await tester.enterText(password, 'untouched');
    final toggle = find.byTooltip('Show password');
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: password, matching: find.byType(EditableText)),
          )
          .obscureText,
      false,
    );
    expect(
      tester.widget<TextFormField>(password).controller!.text,
      'untouched',
    );
    final editable = tester.widget<EditableText>(
      find.descendant(of: password, matching: find.byType(EditableText)),
    );
    expect(editable.controller.text, 'untouched');
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: password, matching: find.byType(TextField)),
          )
          .autofillHints,
      contains(AutofillHints.password),
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(calls, 1);
    pending.complete(http.Response('error', 503));
    await tester.pumpAndSettle();
  });
  for (final width in [320.0, 430.0, 900.0]) {
    testWidgets('T22-T26 width $width with large text and keyboard', (
      tester,
    ) async {
      await mount(
        tester,
        (_) async => http.Response('{}', 503),
        width: width,
        scale: 2,
        keyboard: 300,
        reduceMotion: true,
      );
      await fill(tester);
      await press(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      expect(
        find.text('The server could not complete sign-in. Please try again.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Continue with Google'));
      expect(tester.takeException(), null);
    });
  }
  testWidgets('reduced motion keeps feedback static; signup still reachable', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    await mount(tester, (_) => pending.future, reduceMotion: true);
    await fill(tester);
    await press(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.hourglass_top), findsOneWidget);
    final cancel = find.text('Cancel sign-in');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pump();
    final signup = find.text('Create account').first;
    await tester.ensureVisible(signup);
    await tester.tap(signup);
    await tester.pumpAndSettle();
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    pending.complete(http.Response(jsonEncode(sessionJson()), 200));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('destination-status')), findsNothing);
  });
  testWidgets('render sign-in preview with pending controls', (tester) async {
    final pending = Completer<http.Response>();
    await mount(tester, (_) => pending.future, reduceMotion: true);
    await fill(tester);
    await press(tester);
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build').create(recursive: true);
      await File(
        'build/as01-signin.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    pending.complete(http.Response('unavailable', 503));
    await tester.pumpAndSettle();
  });
}
