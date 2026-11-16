import 'dart:io';
import 'dart:ui' as ui;
import 'package:app_flutter/src/core/app_theme.dart';
import 'package:app_flutter/src/features/portal/client_portal_screen.dart';
import 'package:app_flutter/src/features/workstation/workstation_hub_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'workstation_hub_test.dart' show hubOwner;
import 'client_portal_access_test.dart' show readyPortalResponse;
import 'session_lifecycle_test.dart' show jsonResponse;

// Isolated fixture rendering. These identities and responses are test-only.
void main() {
  setUpAll(() async {
    final text = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([text.load(), icons.load()]);
  });
  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image =
          await (tester.renderObject(find.byKey(key)) as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/portal-qa').create(recursive: true);
      await File(
        'build/portal-qa/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final dark in [true, false]) {
    testWidgets('capture client populated ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = await hubOwner(
        (request) async =>
            readyPortalResponse(request) ??
            jsonResponse(
              request.url.path.endsWith('/deliverables')
                  ? {'items': []}
                  : {
                      'pending_deliverable_count': 3,
                      'open_ticket_count': 1,
                      'ai_summary_line':
                          'Thoughtful creative for Harbour Studio.',
                      'active_plan': {
                        'name': 'Growth',
                        'current_period_end': '2030-06-01T00:00:00Z',
                      },
                      'quotas': {
                        'reel': {'quota': 8, 'used': 3},
                        'static_post': {'quota': 12, 'used': 5},
                        'story': {'quota': 10, 'used': 2},
                      },
                      'assigned_team': [
                        {
                          'id': 'team',
                          'name': 'Maya Chen',
                          'raw_role': 'team_lead',
                          'role': 'Creative lead',
                        },
                      ],
                      'recent_activity': [
                        {
                          'title': 'Summer launch film v2',
                          'status': 'pending_approval',
                        },
                      ],
                    },
            ),
        role: 'client',
      );
      addTearDown(session.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: ClientPortalScreen(session: session),
          ),
        ),
      );
      // CreoPulseDot loops forever, so pumpAndSettle never settles here.
      await tester.pump(const Duration(seconds: 1));
      if (!dark) {
        await tester.tap(find.byTooltip('Switch appearance'));
        await tester.pump(const Duration(seconds: 1));
      }
      await capture(tester, key, 'client-${dark ? 'dark' : 'light'}');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('capture populated chat ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = await hubOwner(
        (request) async => jsonResponse(
          request.url.path.endsWith('/channels')
              ? [
                  {
                    'id': 'creative',
                    'label': 'creative-room',
                    'desc': 'Ideas, feedback and work in progress',
                  },
                ]
              : request.url.path.endsWith('/contacts')
              ? []
              : [
                  {
                    'id': 'm1',
                    'sender_id': 'team',
                    'sender_name': 'Maya Chen',
                    'message': 'The new storyboard is ready for review.',
                    'created_at': '2030-05-18T09:30:00Z',
                  },
                  {
                    'id': 'm2',
                    'sender_id': 'team',
                    'sender_name': 'Maya Chen',
                    'message': 'I added the product close-ups we discussed.',
                    'created_at': '2030-05-18T09:31:00Z',
                  },
                  {
                    'id': 'm3',
                    'sender_id': 'account-a',
                    'sender_name': 'Alex Morgan',
                    'message': 'Looks good. I will review the pacing next.',
                    'created_at': '2030-05-18T09:35:00Z',
                  },
                ],
        ),
      );
      addTearDown(session.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: buildCreoTheme(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: WorkstationHubPage(session: session),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('creative-room'));
      await tester.pumpAndSettle();
      await capture(tester, key, 'chat-${dark ? 'dark' : 'light'}');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
