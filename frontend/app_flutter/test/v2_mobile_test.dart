import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/main.dart';
import 'package:app_flutter/src/core/app_theme.dart';
import 'package:app_flutter/src/features/admin/creo_admin/ui.dart' as admin;
import 'package:app_flutter/src/features/splash/splash_screen.dart';
import 'package:app_flutter/src/features/workstation/member_workspace_shell.dart';
import 'package:app_flutter/src/features/workstation/workstation_page.dart';
import 'package:app_flutter/src/features/workstation/workstation_task_page.dart';
import 'package:app_flutter/src/features/workstation/workstation_hub_pages.dart';
import 'auth_contract_test.dart' show MemorySessionStore;
import 'session_lifecycle_test.dart' show owner, saved, profile, jsonResponse;
import 'team_lead_test.dart' show pod;

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets('v2 cold signed-out app opens login without the landing page', (
    tester,
  ) async {
    final session = owner(MemorySessionStore(), (_) async => jsonResponse({}));
    await session.restore();
    await tester.pumpWidget(CreoApp(session: session));
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(find.text('Delivered every week'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
  testWidgets('reduced motion skips startup movement and navigates once', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const SplashScreen(),
        routes: {
          '/login': (_) => const Scaffold(body: Text('Sign in destination')),
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final dark in [false, true]) {
    testWidgets(
      'readable selected controls in ${dark ? 'dark' : 'light'} admin theme',
      (tester) async {
        final previous = admin.lightMode.value;
        admin.lightMode.value = !dark;
        addTearDown(() => admin.lightMode.value = previous);
        tester.view.physicalSize = const Size(360, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        final theme = admin.creoTheme();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: RepaintBoundary(
              key: key,
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Workspace Hub'),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected: true,
                            onSelected: (_) {},
                          ),
                          ChoiceChip(
                            label: const Text('Channels'),
                            selected: false,
                            onSelected: (_) {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () {},
                        child: const Text('Continue'),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Create group'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final chipText = DefaultTextStyle.of(
          tester.element(find.text('All')),
        ).style.color!;
        expect(
          contrast(chipText, theme.chipTheme.selectedColor!),
          greaterThanOrEqualTo(4.5),
        );
        final buttonText = DefaultTextStyle.of(
          tester.element(find.text('Continue')),
        ).style.color!;
        expect(
          contrast(
            buttonText,
            theme.filledButtonTheme.style!.backgroundColor!.resolve({})!,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final picture =
              await (tester.renderObject(find.byKey(key))
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await picture.toByteData(
            format: ui.ImageByteFormat.png,
          );
          await Directory('build/v2-qa').create(recursive: true);
          await File(
            'build/v2-qa/controls-${dark ? 'dark' : 'light'}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          picture.dispose();
        });
      },
    );
  }
  testWidgets(
    'member bottom tabs retain state and stay visible on detail routes',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = owner(MemorySessionStore()..value = saved(), (
        request,
      ) async {
        if (request.url.path.endsWith('/auth/me') ||
            request.url.path.endsWith('/users/me')) {
          return jsonResponse({...profile(), 'role': 'editor'});
        }
        if (request.url.path.endsWith('/pod-dashboard')) {
          return jsonResponse(pod());
        }
        return jsonResponse({'items': []});
      });
      await session.restore();
      final captureKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildCreoTheme(),
          home: RepaintBoundary(
            key: captureKey,
            child: MemberWorkspaceShell(session: session),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WorkstationPage), findsOneWidget);
      await tester.runAsync(() async {
        final image =
            await (tester.renderObject(find.byKey(captureKey))
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/v2-qa').create(recursive: true);
        await File(
          'build/v2-qa/member-bottom-tabs.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.tap(find.text('Tasks').last);
      await tester.pumpAndSettle();
      expect(find.byType(WorkstationTaskPage), findsOneWidget);
      await tester.tap(find.text('Chat').last);
      await tester.pumpAndSettle();
      expect(find.byType(WorkstationHubPage), findsOneWidget);
      final search = find.widgetWithText(TextField, 'Search conversations');
      await tester.enterText(search, 'retained draft');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chat').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(search).controller?.text ??
            tester
                .widget<EditableText>(
                  find.descendant(
                    of: search,
                    matching: find.byType(EditableText),
                  ),
                )
                .controller
                .text,
        'retained draft',
      );
      Navigator.of(tester.element(find.byType(WorkstationHubPage))).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Conversation details')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('member-bottom-navigation')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Conversation details'), findsNothing);
      expect(find.byType(WorkstationHubPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(WorkstationPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
