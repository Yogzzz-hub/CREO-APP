import 'package:creo_freelancer/data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    tasks.clear();
    blackouts.clear();
  });

  test('rupees use Indian grouping', () {
    expect(inr(0), '₹0');
    expect(inr(4500), '₹4,500');
    expect(inr(235000), '₹2,35,000');
  });

  test('not started tasks count as in progress, like the site', () {
    tasks.addAll([Task(client: 'A', title: 'a'), Task(client: 'B', title: 'b', status: Status.working)]);
    expect(countIn(Status.working), 2);
    expect(countIn(Status.review), 0);
  });

  test('earned counts approved tasks only, expected counts all', () {
    tasks.addAll([
      Task(client: 'A', title: 'a', fee: 6000, status: Status.done),
      Task(client: 'B', title: 'b', status: Status.review),
      Task(client: 'C', title: 'c', fee: 2000, status: Status.revision),
    ]);
    expect(earned, 6000);
    expect(expected, 6000 + defaultFee + 2000);
  });

  test('each submission is a new version and goes to QA', () {
    final t = Task(client: 'A', title: 'Reel', status: Status.working);
    tasks.add(t);
    submit(t, name: 'cut.mp4', bytes: 1536000);
    expect(t.status, Status.review);
    expect(t.history.single.label, 'Submitted for QA');
    t.status = Status.revision;
    submit(t, name: 'drive.google.com', url: 'https://drive.google.com/x', notes: 'Shorter intro');
    expect(t.submissions.map((s) => s.version), [1, 2]);
    expect(t.history.last.label, 'New version resubmitted');
    expect(t.history.last.note, 'Shorter intro');
  });

  test('a task is late only while it waits on the freelancer', () {
    final past = today.subtract(const Duration(days: 1));
    expect(Task(client: 'A', title: 'a', due: past).late, isTrue);
    expect(Task(client: 'A', title: 'a', due: past, status: Status.review).late, isFalse);
    expect(Task(client: 'A', title: 'a', due: today).late, isFalse);
  });

  test('time off counts both end days and splits upcoming from pending', () {
    final a = Blackout('Holiday / Vacation', today, today.add(const Duration(days: 2)), '');
    final b = Blackout('Medical / Rest', today, today, '')..status = 'Approved';
    final old = Blackout('Medical / Rest', DateTime(2024, 1, 1), DateTime(2024, 1, 3), '')..status = 'Approved';
    blackouts.addAll([a, b, old]);
    expect(a.days, 3);
    expect(daysOf(pendingBlackouts), 3);
    expect(upcomingBlackouts, [b]);
  });

  test('links, phones and file sizes', () {
    expect(validUrl('https://drive.google.com/file/d/1'), isTrue);
    expect(validUrl('drive.google.com/file'), isFalse);
    expect(validUrl('ftp://x.com'), isFalse);
    for (final bad in ['javascript:alert(1)', 'tel:+911234567890', 'intent://x#Intent;end', 'file:///etc/passwd', 'http://[bad']) {
      expect(validUrl(bad), isFalse, reason: bad);
    }
    expect(normalPhone('98765 43210'), '+919876543210');
    expect(normalPhone(''), '');
    expect(mb(1536000), '1.46 MB');
  });
}
