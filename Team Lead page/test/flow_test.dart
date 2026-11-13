// Taps through the main team lead flows the way a person would.
import 'package:creo_teamlead/data.dart';
import 'package:creo_teamlead/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data_test.dart' show reset;

/// Scrolls the innermost vertical list until [f] is built, since lists build lazily.
Future<void> reveal(WidgetTester t, Finder f) async {
  final list = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last;
  if (f.evaluate().isEmpty) {
    // Look below first, then above: the list may already be scrolled past it.
    try {
      await t.scrollUntilVisible(f, 300, scrollable: list, maxScrolls: 20);
    } on StateError {
      await t.scrollUntilVisible(f, -300, scrollable: list, maxScrolls: 20);
    }
  }
  await t.ensureVisible(f.last);
}

Future<void> tapText(WidgetTester t, String text) async {
  final f = find.text(text).last;
  await reveal(t, find.text(text));
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
  await reveal(t, f);
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

/// Opens a date field and accepts the date the picker offers (today).
Future<void> pickToday(WidgetTester t, String label) async {
  // Tap the field, not its floating label: the label sits half outside the field and warns on tap.
  final f = find.widgetWithText(InkWell, label);
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
  await tapText(t, 'OK');
}

Future<void> phone(WidgetTester t) async {
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    reset();
    me.name = 'Team Lead';
    pod.name = 'Pod';
  });

  Future<void> start(WidgetTester t) async {
    await phone(t);
    await t.pumpWidget(const CreoTeamLead());
    await t.pumpAndSettle();
  }

  Future<void> addClientAndMember(WidgetTester t) async {
    await openTab(t, 'Clients');
    await tapText(t, 'Add client');
    await fill(t, 'Brand name *', 'Nexis Tech');
    await tapText(t, 'Add client');
    await t.pump(const Duration(seconds: 5));
    await openTab(t, 'Home');
    await tapText(t, 'Add member');
    await fill(t, 'Name *', 'Rajini');
    await fill(t, 'Role *', 'Senior Video Editor');
    await tapText(t, 'Add to pod');
    await t.pump(const Duration(seconds: 5));
  }

  testWidgets('empty dashboard shows the lead alone and nothing to review', (t) async {
    await start(t);
    expect(find.text('Team lead'), findsOneWidget);
    expect(find.text('Team Lead (you)'), findsOneWidget);
    expect(find.text('Nothing to review. Work sent for QA shows here.'), findsOneWidget);
    await tapText(t, 'Assign task');
    expect(find.text('Add a client first, on the Clients tab'), findsOneWidget);
  });

  testWidgets('add client and member, assign a task, it lands in the backlog', (t) async {
    await start(t);
    await addClientAndMember(t);
    expect(find.text('Rajini'), findsOneWidget);
    await tapText(t, 'Assign task');
    await fill(t, 'Task title *', 'Launch reel');
    await tapText(t, 'Assign');
    await t.pump(const Duration(seconds: 5));
    expect(tasks.single.who.name, 'Rajini');
    expect(tasks.single.client.name, 'Nexis Tech');
    await openTab(t, 'Tasks');
    expect(find.text('Launch reel'), findsOneWidget);
    expect(find.text('Backlog 1'), findsOneWidget);
  });

  testWidgets('a task goes through QA: start, send, checklist, approve', (t) async {
    final c = Client('Nexis', 'Growth');
    clients.add(c);
    assign(title: 'Launch reel', client: c, format: Format.reel, who: me);
    await start(t);
    await openTab(t, 'Tasks');
    await tapText(t, 'Start');
    await tapText(t, 'In progress 1');
    await tapText(t, 'Send to QA');
    await t.pump(const Duration(seconds: 5));
    await openTab(t, 'Review');
    await tapText(t, 'Launch reel');
    await tapText(t, 'Approve & send');
    expect(find.text('Tick every checklist item first'), findsOneWidget);
    for (final item in checklist) {
      await tapText(t, item);
    }
    await tapText(t, 'Approve & send');
    expect(tasks.single.stage, Stage.dispatched);
  });

  testWidgets('a revision needs notes for the creative', (t) async {
    final c = Client('Nexis', 'Growth');
    clients.add(c);
    sendToQa(assign(title: 'Launch reel', client: c, format: Format.reel, who: me));
    await start(t);
    await tapText(t, 'Request revision');
    await tapText(t, 'Send back');
    expect(find.text('Notes for the creative is needed'), findsOneWidget);
    await fill(t, 'Notes for the creative *', 'Tighten the hook');
    await tapText(t, 'Send back');
    expect(tasks.single.stage, Stage.progress);
  });

  testWidgets('leave logged for a member is approved from the dashboard', (t) async {
    await start(t);
    await addClientAndMember(t);
    await openTab(t, 'More');
    await tapText(t, 'Leave & schedule');
    await tapText(t, 'Log leave');
    await pick(t, 'Who *', 'Rajini');
    await pickToday(t, 'Start date *');
    await pickToday(t, 'End date *');
    await tapText(t, 'Send request');
    await t.pump(const Duration(seconds: 5));
    expect(leaves.single.who.name, 'Rajini');
    expect(find.text('Rajini'), findsWidgets);
    await tapText(t, 'Approve leave');
    expect(leaves.single.status, 'Approved');
    expect(onLeave(leaves.single.who, today), isTrue);
  });

  testWidgets('every More page opens', (t) async {
    await start(t);
    for (final (item, text) in [
      ('Leave & schedule', 'No requests from the pod'),
      ('Calendar', 'Nothing due this day'),
      ('Instagram queue', 'Nothing in the queue'),
      ('Workspace hub', '# all-pod-leads'),
      ('Support desk', 'No tickets match these filters'),
      ('Settings', 'Personal details'),
    ]) {
      await openTab(t, 'More');
      await tapText(t, item);
      expect(find.text(text), findsOneWidget, reason: item);
      await t.pageBack();
      await t.pumpAndSettle();
    }
  });

  testWidgets('publishing refuses work that is not approved', (t) async {
    await start(t);
    await openTab(t, 'More');
    await tapText(t, 'Instagram queue');
    await tapText(t, 'Schedule a post');
    expect(find.text('Approve work on Review first. Only approved work can publish.'), findsOneWidget);
  });

  testWidgets('theme switch goes light and back to dark', (t) async {
    await start(t);
    await t.tap(find.byTooltip('Light mode'));
    await t.pumpAndSettle();
    expect(find.byTooltip('Dark mode'), findsOneWidget);
    await t.tap(find.byTooltip('Dark mode'));
    await t.pumpAndSettle();
    expect(find.byTooltip('Light mode'), findsOneWidget);
  });
}
