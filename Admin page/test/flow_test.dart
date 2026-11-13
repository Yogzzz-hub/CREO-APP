// Taps through the main admin flows the way a person would.
import 'package:creo_admin/data.dart';
import 'package:creo_admin/main.dart';
import 'package:creo_admin/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> tapText(WidgetTester t, String text) async {
  final f = find.text(text).last;
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> openTab(WidgetTester t, String bottom, [String? sub]) async {
  await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(bottom)));
  await t.pumpAndSettle();
  if (sub != null) {
    final tab = find.widgetWithText(Tab, sub);
    await t.ensureVisible(tab);
    await t.pumpAndSettle();
    await t.tap(tab);
    await t.pumpAndSettle();
  }
}

Future<void> fill(WidgetTester t, String label, String value) async {
  final f = find.widgetWithText(TextFormField, label);
  await t.ensureVisible(f);
  await t.enterText(f, value);
}

Future<void> pick(WidgetTester t, String label, String option) async {
  final f = find.widgetWithText(DropdownButtonFormField<String>, label);
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
  await t.tap(find.text(option).last);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('client, draft, task and leave flows', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(const CreoAdmin());
    await t.pumpAndSettle();
    expect(find.text('Needs your decision'), findsNothing);

    // Onboard a client on the Scale plan, then mark them as paid.
    await openTab(t, 'Team', 'Clients');
    await tapText(t, 'Onboard a client');
    await fill(t, 'Brand name *', 'Zest Foods');
    await fill(t, 'Login email *', 'owner@zest.in');
    await pick(t, 'Plan', 'Scale');
    await tapText(t, 'Send invite');
    expect(clients.single.name, 'Zest Foods');
    await tapText(t, 'Not paid 1');
    await tapText(t, 'Zest Foods');
    await tapText(t, 'Mark as paid');
    expect(clients.single.paid, isTrue);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    await openTab(t, 'Money', 'Revenue');
    expect(find.text('₹1,00,000'), findsWidgets);

    // A new draft shows up on Home, then gets approved from Review.
    await openTab(t, 'Content', 'Review');
    await tapText(t, 'New draft');
    await fill(t, 'Title *', 'Launch reel');
    await pick(t, 'Client *', 'Zest Foods');
    await pick(t, 'Format *', 'Reel');
    await tapText(t, 'Pick a date');
    await tapText(t, 'OK');
    await tapText(t, 'Add draft');
    expect(drafts(Draft.review).length, 1);
    await openTab(t, 'Home');
    expect(find.text('Review 1 drafts'), findsOneWidget);
    await openTab(t, 'Content', 'Review');
    await tapText(t, 'Approve');
    expect(drafts(Draft.approved).length, 1);

    // Add a team member, give them a task, and move it along.
    await openTab(t, 'Team', 'Pods');
    await tapText(t, 'Add member');
    await fill(t, 'Full name *', 'Arjun Nair');
    await fill(t, 'Email for the invite *', 'arjun@creo.in');
    await tapText(t, 'Send invite');
    expect(people.single.name, 'Arjun Nair');
    await openTab(t, 'Content', 'Tasks');
    await tapText(t, 'Create task');
    await fill(t, 'Task title *', 'Story set');
    await pick(t, 'Client *', 'Zest Foods');
    await pick(t, 'Assign to *', 'Arjun Nair');
    await tapText(t, 'Pick a date');
    await tapText(t, 'OK');
    await tapText(t, 'Create task');
    expect(tasks.single.stage, Stage.todo);
    await tapText(t, 'Story set');
    await tapText(t, 'Making');
    expect(tasks.single.stage, Stage.making);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();

    // Apply for leave: it appears as a decision on Home and can be approved.
    await openTab(t, 'Team', 'Leave');
    await tapText(t, 'Apply for time off');
    await tapText(t, 'Pick a date');
    await tapText(t, 'OK');
    await tapText(t, 'Pick a date');
    await tapText(t, 'OK');
    await tapText(t, 'Apply');
    expect(pendingLeaves.length, 1);
    await openTab(t, 'Home');
    expect(find.text('Admin asked for leave'), findsOneWidget);
    await openTab(t, 'Team', 'Leave');
    await tapText(t, 'Approve');
    expect(pendingLeaves, isEmpty);
  });

  testWidgets('chat message and support ticket', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(const CreoAdmin());
    await t.pumpAndSettle();

    await openTab(t, 'Inbox', 'Chat');
    await tapText(t, 'New group');
    await fill(t, 'Group name *', 'pod alpha');
    await tapText(t, 'Create group');
    await t.enterText(find.byType(TextField).last, 'Standup at 4');
    await t.tap(find.byTooltip('Send'));
    await t.pumpAndSettle();
    expect(channels.single.name, 'pod-alpha');
    expect(channels.single.messages.single.text, 'Standup at 4');
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();

    await t.tap(find.widgetWithText(Tab, 'Support 0'));
    await t.pumpAndSettle();
    await tapText(t, 'New ticket');
    await pick(t, 'Client *', 'Zest Foods');
    await fill(t, 'Subject *', 'Wrong logo');
    await tapText(t, 'Open ticket');
    expect(openTickets.length, 1);
    await tapText(t, 'Wrong logo');
    await tapText(t, 'Close ticket');
    expect(openTickets, isEmpty);
  });

  testWidgets('theme switch goes light and back to dark, and is saved', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(const CreoAdmin());
    await t.pumpAndSettle();
    Color ground() => t.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor ?? Theme.of(t.element(find.byType(Scaffold).first)).scaffoldBackgroundColor;
    expect(ground(), const Color(0xFF0A0908));
    Finder wave() => find.descendant(of: find.byType(ClipPath), matching: find.byType(RawImage));
    await t.tap(find.byTooltip('Light mode'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await t.pump(const Duration(milliseconds: 400));
    expect(wave(), findsOneWidget);
    await t.pumpAndSettle();
    expect(wave(), findsNothing);
    expect(lightMode.value, isTrue);
    expect(ground(), const Color(0xFFE9DFCF));
    expect((await SharedPreferences.getInstance()).getBool('light'), isTrue);
    lightMode.value = false;
    await loadTheme();
    expect(lightMode.value, isTrue);
    await t.tap(find.byTooltip('Dark mode'));
    await t.pumpAndSettle();
    expect(lightMode.value, isFalse);
    expect(ground(), const Color(0xFF0A0908));
  });

  testWidgets('a long form still checks fields scrolled out of view', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    Map<String, String>? result;
    await t.pumpWidget(MaterialApp(
        home: Builder(
            builder: (c) => TextButton(
                onPressed: () async => result = await formSheet(c, 'Long', [for (var i = 0; i < 20; i++) F('Field $i', required: true)], 'Done'),
                child: const Text('Open')))));
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Done'));
    await t.pumpAndSettle();
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('Field 0 is needed', skipOffstage: false), findsOneWidget);
  });
}
