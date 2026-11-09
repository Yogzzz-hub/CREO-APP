import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:app_flutter/main.dart';
import 'package:app_flutter/src/core/auth_session.dart';
import 'package:app_flutter/src/core/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'auth_contract_test.dart' show MemorySessionStore;
import 'session_lifecycle_test.dart'
    show saved, owner, profile, jsonResponse, FaultyStore;

class DelayedReadStore extends MemorySessionStore {
  final readResult = Completer<StoredSession?>();
  @override
  Future<StoredSession?> read() => readResult.future;
}

void main() {
  final previewKey = GlobalKey();
  Future<void> mount(
    WidgetTester tester,
    AuthSession session, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 640),
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: CreoApp(session: session, initialRoute: '/login'),
        ),
      ),
    );
  }

  testWidgets(
    'T09 cold startup never exposes auth/app content before credentials are read',
    (tester) async {
      final store = DelayedReadStore();
      var requests = 0;
      final session = owner(store, (_) async {
        requests++;
        return jsonResponse({});
      });
      await mount(tester, session);
      expect(find.text('Checking your session'), findsOneWidget);
      expect(find.byKey(const Key('login-email')), findsNothing);
      store.readResult.complete(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      expect(requests, 0);
    },
  );
  testWidgets(
    'validated session shows only existing navigation boundary; logout resets navigation',
    (tester) async {
      final store = MemorySessionStore()..value = saved();
      final me = Completer<http.Response>();
      final session = owner(
        store,
        (r) async => r.url.path.endsWith('/me')
            ? me.future
            : jsonResponse({'status': 'logged_out'}),
      );
      await mount(tester, session);
      await tester.pump();
      expect(find.text('Checking your session'), findsOneWidget);
      me.complete(jsonResponse(profile()));
      await tester.pumpAndSettle();
      expect(find.text('You’re signed in'), findsOneWidget);
      expect(
        find.text('The mobile workspace is not implemented yet.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('login-email')), findsNothing);
      await tester.tap(find.text('Sign out on this device'));
      await tester.pumpAndSettle();
      expect(store.value, null);
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      expect(find.text('Signed out on this device.'), findsOneWidget);
      expect(session.navigationEpoch, 1);
      final context = tester.element(find.byKey(const Key('login-email')));
      expect(Navigator.of(context).canPop(), false);
    },
  );
  testWidgets(
    'offline restore offers Retry and deliberate sign-in after local clear',
    (tester) async {
      final store = MemorySessionStore()..value = saved();
      var offline = true;
      final session = owner(store, (_) async {
        if (offline) throw http.ClientException('offline');
        return jsonResponse(profile());
      });
      await mount(tester, session);
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      expect(store.value, isNotNull);
      expect(find.byKey(const Key('login-email')), findsNothing);
      offline = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('You’re signed in'), findsOneWidget);
      await session.logout(notifyServer: false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login-email')), findsOneWidget);
    },
  );
  testWidgets(
    'mandatory reset null token remains restricted, without inventing reset screens',
    (tester) async {
      final store = MemorySessionStore()..value = saved();
      final session = owner(
        store,
        (_) async => jsonResponse(profile(restricted: true)),
      );
      await mount(tester, session);
      await tester.pumpAndSettle();
      expect(find.text('Password update required'), findsOneWidget);
      expect(session.current?.accessToken, store.value?.accessToken);
      expect(find.byKey(const Key('login-email')), findsNothing);
    },
  );
  testWidgets(
    'repeated resume events share one validation and hide unvalidated content',
    (tester) async {
      final store = MemorySessionStore()..value = saved();
      var requests = 0;
      final next = Completer<http.Response>();
      final session = owner(
        store,
        (_) async => ++requests == 1 ? jsonResponse(profile()) : next.future,
      );
      await mount(tester, session);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(requests, 2);
      expect(find.text('Checking your session'), findsOneWidget);
      next.complete(jsonResponse(profile()));
      await tester.pumpAndSettle();
      expect(find.text('You’re signed in'), findsOneWidget);
    },
  );
  testWidgets('partial clear failure blocks login and exposes retry sign-out', (
    tester,
  ) async {
    final store = FaultyStore()..value = saved();
    store.failClear = true;
    final session = owner(store, (_) async => jsonResponse(profile()));
    await mount(tester, session);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out on this device'));
    await tester.pumpAndSettle();
    expect(find.text('Retry sign-out'), findsOneWidget);
    expect(find.byKey(const Key('login-email')), findsNothing);
    store.failClear = false;
    await tester.tap(find.text('Retry sign-out'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-email')), findsOneWidget);
  });
  testWidgets(
    'branded unavailable state remains accessible on narrow large-text screens',
    (tester) async {
      final store = MemorySessionStore()..value = saved();
      final session = owner(
        store,
        (_) async => throw TimeoutException('timeout'),
      );
      await mount(tester, session, scale: 2);
      await tester.pumpAndSettle();
      expect(find.text('creo.'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
        findsWidgets,
      );
      await tester.ensureVisible(find.text('Clear saved session and sign in'));
      expect(tester.takeException(), null);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
  testWidgets(
    'render branded restoring-session preview without protected content',
    (tester) async {
      final store = MemorySessionStore()..value = saved();
      final response = Completer<http.Response>();
      final session = owner(store, (_) => response.future);
      await mount(tester, session);
      await tester.pump();
      expect(find.text('Checking your session'), findsOneWidget);
      expect(find.byKey(const Key('login-email')), findsNothing);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(previewKey),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build').create(recursive: true);
        await File(
          'build/as02-restoring.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      response.complete(jsonResponse(profile()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
    },
  );
}
