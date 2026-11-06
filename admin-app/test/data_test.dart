import 'package:creo_admin/data.dart';
import 'package:creo_admin/ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    clients.clear();
    invoices.clear();
    tasks.clear();
    deliverables.clear();
    people.clear();
    leaves.clear();
  });

  test('rupee grouping', () {
    expect(inr(0), '₹0');
    expect(inr(25000), '₹25,000');
    expect(inr(100000), '₹1,00,000');
    expect(inr(235000), '₹2,35,000');
    expect(inr(12345678), '₹1,23,45,678');
  });

  test('revenue comes from paid clients and their plan or deal', () {
    clients.addAll([
      Client(name: 'A', plan: 'Scale')..paid = true,
      Client(name: 'B', plan: 'Starter Growth')
        ..paid = true
        ..upi = true,
      Client(name: 'C', plan: 'Scale'), // not paid
      Client(name: 'D', plan: 'Brand Accelerator')
        ..paid = true
        ..customFee = 40000,
    ]);
    expect(mrr, 100000 + 25000 + 40000);
    expect(upiTotal, 25000);
    expect(cardTotal + upiTotal, mrr);
    expect(clientsOn('Scale'), 1);
  });

  test('invoices are summed per month, last 6 months', () {
    final now = DateTime(2026, 11, 5);
    invoices.addAll([
      Invoice('A', 'x', 1000, payMethods.first, DateTime(2026, 11, 1)),
      Invoice('A', 'x', 500, payMethods.first, DateTime(2026, 11, 20)),
      Invoice('A', 'x', 700, payMethods.first, DateTime(2026, 6, 2)),
      Invoice('A', 'x', 900, payMethods.first, DateTime(2026, 5, 2)), // older than 6 months: left out
    ]);
    final m = invoicedByMonth(now);
    expect(m.length, 6);
    expect(m.first, ('Jun', 700));
    expect(m.last, ('Nov', 1500));
  });

  test('workload, overload and on-time rate come from tasks', () {
    people.add(Person('Arjun', 'a@x.in', Kind.staff));
    for (var i = 0; i < overloadAt; i++) {
      tasks.add(Task('t$i', 'A', 'Arjun', '', 'Medium', DateTime(2026, 11, 10)));
    }
    expect(openTasks('Arjun'), overloadAt);
    expect(overloaded.single.$1, 'Arjun');
    expect(onTimeRate, '—');
    tasks[0]
      ..stage = Stage.done
      ..doneAt = DateTime(2026, 11, 9);
    tasks[1]
      ..stage = Stage.done
      ..doneAt = DateTime(2026, 11, 15);
    expect(onTimeRate, '50%');
    expect(overloaded, isEmpty);
  });

  test('leave length and who is away today', () {
    final l = Leave('Sarah', today, today.add(const Duration(days: 2)), '');
    leaves.add(l);
    expect(l.days, 3);
    expect(onLeaveToday, isEmpty);
    l.status = 'Approved';
    expect(onLeaveToday.single.who, 'Sarah');
  });

  test('draft summary', () {
    deliverables.addAll([
      Deliverable('a', 'x', 'Reel', '', today),
      Deliverable('b', 'x', 'Reel', '', today),
      Deliverable('c', 'x', 'Story', '', today),
    ]);
    expect(formatCounts(deliverables), '2 reels, 1 story');
    expect(formatCounts(const []), '');
  });

  test('dates and initials', () {
    expect(shortDate(DateTime(2026, 11, 5)), 'Thu 5 Nov');
    expect(longDate(DateTime(2026, 11, 5)), 'Thursday 5 Nov');
    expect(initials('Sarah Connor'), 'SC');
    expect(initials('Admin'), 'AD');
    expect(initials(''), '?');
  });

  test('CSV cells are quoted, escaped and cannot start a formula', () {
    expect(csvRow(['Card, Razorpay', 'Dummy "Brand", Ltd', 25000]), '"Card, Razorpay","Dummy ""Brand"", Ltd","25000"');
    expect(csvCell('=HYPERLINK("http://x","y")'), '"\'=HYPERLINK(""http://x"",""y"")"');
    for (final lead in ['+1', '-1', '@a', '\tx', '\rx']) {
      expect(csvCell(lead).startsWith('"\''), isTrue, reason: lead);
    }
  });

  test('names are unique regardless of case and spaces', () {
    expect(nameTaken(['Zest Foods'], ' zest foods '), isTrue);
    expect(nameTaken(['Zest Foods'], 'Zest'), isFalse);
  });

  test('invite emails need a name, one @ and a domain with a dot', () {
    for (final ok in ['ana@creo.in', ' ana.k+1@mail.co.uk ']) {
      expect(validEmail(ok), isTrue, reason: ok);
    }
    for (final bad in ['@', 'ana@', '@creo.in', 'ana@creo', 'a b@creo.in', 'ana@@creo.in', '']) {
      expect(validEmail(bad), isFalse, reason: bad);
    }
  });
}
