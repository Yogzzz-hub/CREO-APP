import 'dart:io';

import 'package:creo_client_portal/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Real glyph widths, so layout checks match a phone. The default test font draws every glyph as a wide square.
Future<void> loadRealFont() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final file = File('$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
  if (!file.existsSync()) return;
  final bytes = file.readAsBytesSync();
  for (final family in ['Inter', 'Roboto']) {
    await (FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  }
}

void main() {
  setUpAll(() async {
    // Tests run offline: never download fonts.
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadRealFont();
  });

  emptyStateTests();

  for (final width in [360.0, 412.0]) {
    testWidgets('app opens on the portal shell without overflow at $width dp', (t) async {
      t.view.physicalSize = Size(width * 3, 800 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(const ProviderScope(child: CreoClientApp()));
      await t.pump(const Duration(seconds: 2));
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsWidgets);
    });
  }
}

void emptyStateTests() {
  testWidgets('starts with no sample data and every tab opens cleanly', (t) async {
    t.view.physicalSize = const Size(412 * 3, 900 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(const ProviderScope(child: CreoClientApp()));
    await t.pump(const Duration(seconds: 2));

    expect(find.text('No drafts to review'), findsOneWidget);
    expect(find.text('No active plan'), findsWidgets);
    for (final label in ['Review', 'Calendar', 'Inbox', 'Account', 'Home']) {
      await t.tap(find.text(label).last);
      await t.pump(const Duration(seconds: 2));
    }
    for (final page in ['Plan & billing', 'Brand DNA', 'Library', 'Help']) {
      await t.tap(find.byIcon(Icons.menu_rounded).first);
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text(page).last);
      await t.pump(const Duration(seconds: 2));
      expect(find.textContaining('Zest'), findsNothing, reason: page);
      final nav = Navigator.of(t.element(find.byType(Scaffold).last));
      if (nav.canPop()) {
        nav.pop();
        await t.pump(const Duration(seconds: 1));
      }
    }
    // None of the old sample names may appear anywhere.
    for (final mock in ['Zest Foods', 'Yogalakshmi Baskar', 'Arvind N', 'Monsoon menu teaser', 'Priya Nair']) {
      expect(find.textContaining(mock), findsNothing, reason: mock);
    }
    // Let entrance animations finish their timers before the test ends.
    await t.pump(const Duration(seconds: 5));
  });
}
