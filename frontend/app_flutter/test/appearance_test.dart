import 'dart:async';

import 'package:app_flutter/main.dart';
import 'package:app_flutter/src/core/app_appearance.dart';
import 'package:app_flutter/src/core/app_theme.dart';
import 'package:app_flutter/src/core/auth_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_contract_test.dart' show MemorySessionStore;

void main() {
  test(
    'restores light preference; read failures retain React dark default',
    () async {
      final light = CreoAppearance(
        read: () async => 'light',
        write: (_) async {},
      );
      await light.restore();
      expect(light.mode, ThemeMode.light);
      final failed = CreoAppearance(
        read: () async => throw StateError('unavailable'),
        write: (_) async {},
      );
      await failed.restore();
      expect(failed.mode, ThemeMode.dark);
      light.dispose();
      failed.dispose();
    },
  );

  test(
    'rapid choices persist in order and late restore cannot replace choice',
    () async {
      final read = Completer<String?>();
      final firstWrite = Completer<void>();
      final writes = <String>[];
      final appearance = CreoAppearance(
        read: () => read.future,
        write: (value) async {
          writes.add(value);
          if (writes.length == 1) await firstWrite.future;
        },
      );
      final restore = appearance.restore();
      final first = appearance.toggle();
      final second = appearance.toggle();
      read.complete('light');
      await restore;
      expect(appearance.mode, ThemeMode.dark);
      firstWrite.complete();
      await Future.wait([first, second]);
      expect(writes, ['light', 'dark']);
      appearance.dispose();
    },
  );

  test('save failure leaves immediately selected appearance usable', () async {
    final appearance = CreoAppearance(
      write: (_) async => throw StateError('full'),
    );
    expect(await appearance.toggle(), false);
    expect(appearance.mode, ThemeMode.light);
    appearance.dispose();
  });

  test('both palettes retain readable text, accent and input borders', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return ((x > y ? x : y) + .05) / ((x < y ? x : y) + .05);
    }

    for (final brightness in Brightness.values) {
      final theme = buildCreoTheme(brightness: brightness);
      final palette = theme.extension<CreoPalette>()!;
      for (final text in [palette.appInk, palette.appMist, palette.accent]) {
        expect(contrast(text, palette.appBase), greaterThanOrEqualTo(4.5));
      }
      expect(
        contrast(palette.accent, palette.onAccent),
        greaterThanOrEqualTo(4.5),
      );
      final border =
          (theme.inputDecorationTheme.enabledBorder! as UnderlineInputBorder)
              .borderSide
              .color;
      expect(contrast(border, palette.appBase), greaterThanOrEqualTo(3));
    }
  });

  testWidgets(
    'theme toggle preserves typed credentials, route and session owner',
    (tester) async {
      final appearance = CreoAppearance(
        read: () async => null,
        write: (_) async {},
      );
      final owner = AuthSession(store: MemorySessionStore());
      await owner.restore();
      await tester.pumpWidget(
        CreoApp(session: owner, appearance: appearance, initialRoute: '/login'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('login-email')),
        'reader@example.test',
      );
      await tester.enterText(
        find.byKey(const Key('login-password')),
        'unsent fixture',
      );
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      await tester.ensureVisible(find.byType(CreoThemeToggle));
      await tester.tap(find.byType(CreoThemeToggle));
      await tester.pumpAndSettle();
      expect(appearance.mode, ThemeMode.light);
      expect(
        tester.state<NavigatorState>(find.byType(Navigator).first),
        same(navigator),
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('login-email')))
            .controller!
            .text,
        'reader@example.test',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('login-password')))
            .controller!
            .text,
        'unsent fixture',
      );
      expect(owner.phase, SessionPhase.signedOut);
      final context = tester.element(find.byKey(const Key('login-email')));
      expect(Theme.of(context).brightness, Brightness.light);
      expect(context.creo.appBase, const Color(0xFFF5EEE3));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      appearance.dispose();
      owner.dispose();
      owner.repository.close();
    },
  );

  for (final light in [false, true]) {
    for (final size in [const Size(320, 740), const Size(852, 393)]) {
      testWidgets(
        'appearance toggle and navigation fit $size at 200%, light=$light',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final appearance = CreoAppearance(
            read: () async => light ? 'light' : 'dark',
            write: (_) async {},
          );
          await appearance.restore();
          final owner = AuthSession(store: MemorySessionStore());
          await owner.restore();
          await tester.pumpWidget(
            CreoApp(session: owner, appearance: appearance),
          );
          await tester.pumpAndSettle();
          expect(find.byType(CreoThemeToggle), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Sign in'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byType(CreoThemeToggle));
          await tester.tap(find.byType(CreoThemeToggle));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          appearance.dispose();
          owner.dispose();
          owner.repository.close();
        },
      );
    }
  }
}
