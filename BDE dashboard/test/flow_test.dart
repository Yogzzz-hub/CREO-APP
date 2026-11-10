// Taps through the main BDE flows the way a person would.
import 'package:creo_bde/data.dart';
import 'package:creo_bde/main.dart';
import 'package:creo_bde/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scrolls the innermost vertical list until [f] is built, since lists build lazily.
Future<void> reveal(WidgetTester t, Finder f) async {
  if (f.evaluate().isEmpty) {
    await t.scrollUntilVisible(f, 300, scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last);
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
  await tapText(t, label);
  await tapText(t, 'OK');
}

Future<void> phone(WidgetTester t) async {
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

void main() {
  setUp(() {
    leads.clear();
    followUps.clear();
    leaves.clear();
    negotiations.clear();
  });

  testWidgets('add a lead, log a call, win it', (t) async {
    await phone(t);
    await t.pumpWidget(const CreoBde());
    await t.pumpAndSettle();
    expect(find.text('No clients in Contacted. Tap Add to create a lead.'), findsOneWidget);

    await tapText(t, 'Add');
    await fill(t, 'Contact name *', 'Rahul Sharma');
    await fill(t, 'Company / brand *', 'Acme Retail');
    await fill(t, 'Phone / WhatsApp', '123');
    await fill(t, 'Estimated value (₹)', '50000');
    await tapText(t, 'Create lead');
    expect(find.text('Enter 10 digits, or + and the country code'), findsOneWidget);
    await fill(t, 'Phone / WhatsApp', '98765 43210');
    await tapText(t, 'Create lead');
    expect(leads.single.phone, '+919876543210');
    expect(find.text('Acme Retail'), findsOneWidget);
    expect(find.text('₹50,000'), findsWidgets);

    // +3 days sets a follow-up; the bell has nothing due yet.
    await tapText(t, '+3 days');
    expect(leads.single.next!.due, plus3());
    await t.pump(const Duration(seconds: 5)); // let the toast go so it does not cover the card
    await t.pumpAndSettle();

    await tapText(t, 'Log');
    await fill(t, 'What was discussed *', 'Wants 15 reels a month');
    await tapText(t, 'Save');
    expect(leads.single.activities.last.summary, 'Wants 15 reels a month');

    await tapText(t, 'Move');
    await pick(t, 'Stage *', 'Won');
    await tapText(t, 'Move');
    expect(leads.single.stage, Stage.won);
    expect(find.text('No clients in Contacted. Tap Add to create a lead.'), findsOneWidget);
    await tapText(t, 'Won 1');
    expect(find.text('Acme Retail'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    // The CRM sees the same lead and its booked value.
    await openTab(t, 'CRM');
    expect(find.text('₹50,000'), findsWidgets);
  });

  testWidgets('leave request and withdraw', (t) async {
    await phone(t);
    await t.pumpWidget(const CreoBde());
    await t.pumpAndSettle();
    await openTab(t, 'Leave');
    await tapText(t, 'Request leave');
    await pickToday(t, 'Start date *');
    await pickToday(t, 'End date *');
    await fill(t, 'Handover notes and pipeline cover *', 'Priya covers Acme');
    await tapText(t, 'Send request');
    expect(leaves.single.days, 1);
    expect(find.text('Pending'), findsOneWidget);
    expect(daysLeft, allowance - 1);
    await tapText(t, 'Withdraw');
    await tapText(t, 'Withdraw');
    expect(leaves, isEmpty);
  });

  testWidgets('plan proposal goes to the admin', (t) async {
    await phone(t);
    await t.pumpWidget(const CreoBde());
    await t.pumpAndSettle();
    await openTab(t, 'Plans');
    expect(find.text('Brand Accelerator'), findsOneWidget);
    await tapText(t, 'Initiate custom proposal');
    await fill(t, 'Client brand name *', 'Apex Media');
    await fill(t, 'Recipient email *', 'founder@apex.in');
    await fill(t, 'Target plan and custom scope *', 'Scale with 2 pods');
    await fill(t, 'Proposed rate (₹ a month) *', '85000');
    await tapText(t, 'Send to admin');
    expect(negotiations.single.proposed, 85000);
    expect(find.text('Waiting'), findsOneWidget);
  });

  testWidgets('theme switch goes light and back to dark', (t) async {
    SharedPreferences.setMockInitialValues({});
    await phone(t);
    await t.pumpWidget(const CreoBde());
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Light mode'));
    await t.pumpAndSettle();
    expect(lightMode.value, isTrue);
    await t.tap(find.byTooltip('Dark mode'));
    await t.pumpAndSettle();
    expect(lightMode.value, isFalse);
  });
}
