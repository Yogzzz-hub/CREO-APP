import 'package:app_flutter/main.dart';
import 'package:app_flutter/src/core/app_appearance.dart';
import 'package:app_flutter/src/features/portal/client_portal_screen.dart';
import 'package:app_flutter/src/features/portal/screens/review/deliverables_review_screen.dart';
import 'package:app_flutter/src/features/portal/screens/calendar/content_calendar_screen.dart';
import 'package:app_flutter/src/features/portal/screens/inbox/inbox_shell_screen.dart';
import 'package:app_flutter/src/features/portal/screens/settings/account_settings_screen.dart';
import 'package:app_flutter/src/features/portal/screens/library/asset_library_screen.dart';
import 'package:app_flutter/src/features/portal/screens/brand/brand_dna_screen.dart';
import 'package:app_flutter/src/features/portal/screens/billing/plan_and_billing_screen.dart';
import 'package:app_flutter/src/features/portal/screens/home/creative_pod_detail_screen.dart';
import 'package:app_flutter/src/features/portal/screens/support/help_support_screen.dart';
import 'package:app_flutter/src/features/portal/widgets/creo_bottom_nav.dart';
import 'package:app_flutter/src/features/portal/widgets/creo_portal_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'auth_contract_test.dart' show MemorySessionStore, sessionJson;
import 'session_lifecycle_test.dart'
    show owner, saved, profile, jsonResponse, jwt;

void main() {
  for (final role in ['client', 'client_owner']) {
    testWidgets('normal app password login opens $role portal', (tester) async {
      final paths = <String>[];
      final session = owner(MemorySessionStore(), (request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('/auth/login')) {
          return jsonResponse({
            ...sessionJson(role: role),
            'access_token': jwt(),
          });
        }
        return jsonResponse({'items': []});
      });
      await session.restore();
      await tester.pumpWidget(
        CreoApp(
          session: session,
          // Own instance: the shared one leaks theme between test cases.
          appearance: CreoAppearance(
            read: () async => null,
            write: (_) async {},
          ),
          initialRoute: '/portal',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ClientPortalScreen), findsNothing);
      await tester.enterText(
        find.byKey(const Key('login-email')),
        'user@example.test',
      );
      await tester.enterText(
        find.byKey(const Key('login-password')),
        'FixturePassword123!',
      );
      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byType(ClientPortalScreen),
        findsOneWidget,
        reason:
            'phase=${session.phase}, issue=${session.issue?.code}, paths=$paths, texts=${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).join(" | ")}',
      );
      final appearance = CreoAppearanceScope.maybeOf(
        tester.element(find.byType(ClientPortalScreen)),
      )!;
      expect(appearance.mode, ThemeMode.dark);
      expect(
        Theme.of(
          tester.element(find.byType(ClientPortalScreen)),
        ).scaffoldBackgroundColor,
        const Color(0xFF0F0E0C),
      );
      final nav = find.byType(CreoBottomNavBar);
      Future<void> tab(String label) async {
        await tester.tap(find.descendant(of: nav, matching: find.text(label)));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      }

      await tab('Review');
      expect(find.byType(DeliverablesReviewScreen), findsOneWidget);
      await tab('Calendar');
      expect(find.byType(ContentCalendarScreen), findsOneWidget);
      await tab('Inbox');
      expect(find.byType(InboxShellScreen), findsOneWidget);
      await tab('Account');
      expect(find.byType(AccountSettingsScreen), findsOneWidget);
      await tab('Home');
      await tab('Review');
      expect(find.byType(DeliverablesReviewScreen), findsOneWidget);
      final context = tester.element(find.byType(DeliverablesReviewScreen));
      final shell = Scaffold.of(context);
      for (final entry in {
        'library': AssetLibraryScreen,
        'brand': BrandDnaScreen,
        'billing': PlanAndBillingScreen,
        'pod': CreativePodDetailScreen,
        'help': HelpSupportScreen,
      }.entries) {
        shell.openDrawer();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        tester
            .widget<CreoPortalDrawer>(find.byType(CreoPortalDrawer))
            .onSelect(entry.key);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(entry.value), findsOneWidget);
        tester.state<NavigatorState>(find.byType(Navigator).last).pop();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(DeliverablesReviewScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(
        paths,
        containsAll([
          '/api/v1/portal/dashboard',
          '/api/v1/portal/deliverables',
        ]),
      );
      await appearance.toggle();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        Theme.of(
          tester.element(find.byType(DeliverablesReviewScreen)),
        ).brightness,
        Brightness.light,
      );
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      appearance.dispose();
    });
  }
}
