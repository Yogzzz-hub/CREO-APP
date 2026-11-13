// Taps through the main freelancer flows the way a person would.
import 'package:creo_freelancer/data.dart';
import 'package:creo_freelancer/main.dart';
import 'package:creo_freelancer/ui.dart';
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
    tasks.clear();
    blackouts.clear();
    me.name = 'Freelancer';
    me.phone = '';
  });

  Future<void> start(WidgetTester t) async {
    await phone(t);
    await t.pumpWidget(const CreoFreelancer());
    await t.pumpAndSettle();
  }

  testWidgets('empty workload says where tasks come from', (t) async {
    await start(t);
    expect(find.text('No tasks yet. Team leads send each task with a brief, a due date and its payout.'), findsOneWidget);
    expect(find.text('₹0'), findsOneWidget);
  });

  testWidgets('start a task, submit a cloud link, see it in QA review', (t) async {
    tasks.add(Task(client: 'Apex Media', title: 'Launch reel', fee: 6000, length: '45 s', sourceUrl: 'https://drive.google.com/d/1'));
    await start(t);
    expect(find.text('Not started'), findsOneWidget);
    await tapText(t, 'Start working');
    expect(tasks.single.status, Status.working);
    await t.pump(const Duration(seconds: 5)); // let the toast go so it does not cover the card
    await t.pumpAndSettle();

    await tapText(t, 'Upload and submit');
    await tapText(t, 'Submit for review');
    expect(find.text('Choose a file to upload'), findsOneWidget);
    await tapText(t, 'Cloud link');
    await t.enterText(find.widgetWithText(TextFormField, 'Cloud link *'), 'drive.google.com/x');
    await tapText(t, 'Submit for review');
    expect(find.text('Enter a full link starting with https://'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextFormField, 'Cloud link *'), 'https://drive.google.com/file/d/9');
    await t.enterText(find.widgetWithText(TextFormField, 'Notes for the reviewer'), 'Graded to the brief');
    await tapText(t, 'Submit for review');

    final task = tasks.single;
    expect(task.status, Status.review);
    expect(task.submissions.single.url, 'https://drive.google.com/file/d/9');
    expect(find.text('Launch reel'), findsNothing); // moved out of the In progress filter
    await tapText(t, 'In QA review 1');
    await tapText(t, 'Launch reel');
    expect(find.text('Submitted for QA'), findsOneWidget);
    expect(find.text('v1 · drive.google.com'), findsOneWidget);
  });

  testWidgets('bell opens tasks sent back for changes', (t) async {
    tasks.add(Task(client: 'Apex Media', title: 'Cut down', status: Status.revision));
    await start(t);
    expect(find.text('Cut down'), findsNothing);
    await t.tap(find.byTooltip('Revisions needed'));
    await t.pumpAndSettle();
    expect(find.text('Cut down'), findsOneWidget);
    expect(find.text('Submit revision'), findsOneWidget);
  });

  testWidgets('earned shows approved payouts only', (t) async {
    tasks.addAll([
      Task(client: 'A', title: 'a', fee: 6000, status: Status.done),
      Task(client: 'B', title: 'b', status: Status.review),
    ]);
    await start(t);
    expect(find.text('₹6,000'), findsOneWidget);
    expect(find.text('of ₹10,500 expected'), findsOneWidget);
  });

  testWidgets('block out dates and withdraw them', (t) async {
    await start(t);
    await openTab(t, 'Time off');
    expect(find.text('You are available for projects'), findsOneWidget);
    await tapText(t, 'Block out dates');
    await pickToday(t, 'Start date *');
    await pickToday(t, 'End date *');
    await fill(t, 'Notes for project leads', 'Drafts delivered first');
    await tapText(t, 'Send to team lead');
    expect(blackouts.single.days, 1);
    expect(find.text('1 day'), findsOneWidget); // In review count, singular
    expect(blackouts.single.reason, 'Holiday / Vacation');
    expect(find.text('Pending'), findsOneWidget);
    await tapText(t, 'Withdraw');
    await tapText(t, 'Withdraw');
    expect(blackouts, isEmpty);
  });

  testWidgets('edit profile and change password', (t) async {
    await start(t);
    await openTab(t, 'Profile');
    await tapText(t, 'Edit profile');
    await fill(t, 'Full name *', 'Asha Rao');
    await fill(t, 'Contact phone', '98765 43210');
    await tapText(t, 'Save');
    expect(me.name, 'Asha Rao');
    expect(me.phone, '+919876543210');

    await tapText(t, 'Change password');
    await fill(t, 'Code from the email *', '12345');
    await fill(t, 'New password *', 'short');
    await fill(t, 'Repeat new password *', 'short');
    await t.tap(find.widgetWithText(FilledButton, 'Change password'));
    await t.pumpAndSettle();
    expect(find.text('Enter the 6 digits'), findsOneWidget);
    expect(find.text('Use at least 8 characters'), findsOneWidget);
    await fill(t, 'Code from the email *', '123456');
    await fill(t, 'New password *', 'longer-pass');
    await fill(t, 'Repeat new password *', 'longer-pass');
    await t.tap(find.widgetWithText(FilledButton, 'Change password'));
    await t.pumpAndSettle();
    expect(find.text('Password changed'), findsOneWidget);
  });

  testWidgets('a task link that is not a web address is refused', (t) async {
    tasks.add(Task(client: 'Apex Media', title: 'Odd link', sourceUrl: 'tel:+911234567890'));
    await start(t);
    await tapText(t, 'Odd link');
    await tapText(t, 'Open source footage');
    expect(find.text('This link is not a web address'), findsOneWidget);
  });

  testWidgets('password fields hide text and keyboard suggestions', (t) async {
    await start(t);
    await openTab(t, 'Profile');
    await tapText(t, 'Change password');
    final field = t.widget<TextField>(find.descendant(of: find.widgetWithText(TextFormField, 'New password *'), matching: find.byType(TextField)));
    expect(field.obscureText, isTrue);
    expect(field.enableSuggestions, isFalse);
    expect(field.autocorrect, isFalse);
  });

  testWidgets('chat message shows in the thread', (t) async {
    await start(t);
    await openTab(t, 'Chat');
    await tapText(t, 'Creo Operations Admin');
    await t.enterText(find.byType(TextField), 'Brief received');
    await t.tap(find.byTooltip('Send'));
    await t.pumpAndSettle();
    expect(find.text('Brief received'), findsOneWidget);
  });

  testWidgets('theme switch goes light and back to dark', (t) async {
    SharedPreferences.setMockInitialValues({});
    await start(t);
    await t.tap(find.byTooltip('Light mode'));
    await t.pumpAndSettle();
    expect(lightMode.value, isTrue);
    await t.tap(find.byTooltip('Dark mode'));
    await t.pumpAndSettle();
    expect(lightMode.value, isFalse);
  });
}
