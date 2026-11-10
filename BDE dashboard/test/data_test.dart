import 'package:creo_bde/data.dart';
import 'package:flutter_test/flutter_test.dart';

Lead lead(String company, {Stage stage = Stage.contacted, int value = 0, String email = '', String phone = ''}) {
  final l = Lead(name: 'Rahul', company: company, stage: stage, value: value, email: email, phone: phone);
  leads.add(l);
  return l;
}

void main() {
  setUp(() {
    leads.clear();
    followUps.clear();
    proposals.clear();
    referrals.clear();
    drafts.clear();
    leaves.clear();
  });

  test('rupees and phones', () {
    expect(inr(235000), '₹2,35,000');
    expect(inr(5000), '₹5,000');
    expect(normalPhone('98765 43210'), '+919876543210');
    expect(normalPhone('+44 20 7946 0000'), '+442079460000');
    expect(normalPhone(''), '');
  });

  test('lanes, pipeline value and conversion', () {
    expect(conversion, '—');
    lead('A', stage: Stage.qualified, value: 10000);
    lead('B', stage: Stage.proposal, value: 5000);
    lead('C', stage: Stage.won, value: 50000);
    lead('D', stage: Stage.lost, value: 9000);
    expect(inLane(Lane.contacted).single.company, 'A'); // qualified stays visible
    expect(inLane(Lane.negotiation).single.company, 'B');
    expect(pipelineValue, 15000);
    expect(conversion, '25%');
  });

  test('+3 days moves the next follow-up, or adds one', () {
    final l = lead('A');
    setFollowUp(l, plus3());
    expect(l.next!.due, today.add(const Duration(days: 3, hours: 11)));
    setFollowUp(l, today);
    expect(l.pending.length, 1);
  });

  test('the last follow-up of an open lead needs a next one', () {
    final l = lead('A');
    final f = FollowUp(l, 'Call', 'Call', DateTime.now());
    followUps.add(f);
    expect(resolve(f, complete: true, reason: ''), isNotNull);
    expect(resolve(f, complete: true, reason: 'Liked it'), contains('last action'));
    expect(resolve(f, complete: true, reason: 'Liked it', nextTitle: 'Send deck', due: today.add(const Duration(days: 1))), isNull);
    expect(f.done, isTrue);
    expect(l.next!.title, 'Send deck');
    expect(resolve(l.next!, complete: false, reason: 'Busy'), 'Pick a new due date');
  });

  test('qualification stays unknown until all five scores are in', () {
    final l = lead('A');
    qualify(l, [80, 90, null, null, null], null, 'call');
    expect(l.temp, Temp.unknown);
    expect(l.evidence, 40);
    qualify(l, [80, 90, 70, 60, 50], null, 'call');
    expect((l.score, l.temp), (70, Temp.hot));
    qualify(l, [10, 10, 10, 10, 10], Temp.warm, 'override');
    expect(l.temp, Temp.warm);
  });

  test('opting out suppresses drafts; deleting a lead leaves nothing behind', () {
    final l = lead('A');
    drafts.add(MessageDraft(l, 'Hi'));
    setConsent(l, 'Opted out', 'Offers', 'Said stop');
    expect(drafts.single.status, 'Suppressed');
    expect(MessageDraft(l, 'Again').status, 'Suppressed');
    followUps.add(FollowUp(l, 'Call', 'Call', today));
    referrals.add(Referral(l, 'Asha', 'Referral', ''));
    saveProposal(null, l, 'Reels', today, 0, [Line(title: 'Reel', price: 1000)]);
    deleteLead(l);
    expect([leads, followUps, drafts, referrals, proposals].every((x) => x.isEmpty), isTrue);
  });

  test('proposal totals per billing period and revisions', () {
    final l = lead('A');
    final lines = [
      Line(title: 'Shoot', qty: 2, price: 10000, discount: 10),
      Line(title: 'Reels', price: 25000, billing: Billing.monthly),
    ];
    final t = totalsOf(lines, 18);
    expect(t[Billing.oneTime]!.total, 18000 + 3240);
    expect(t[Billing.monthly]!.total, 29500);
    final p1 = saveProposal(null, l, 'Launch', today, 18, lines);
    final p2 = saveProposal(p1, l, 'Launch', today, 18, lines);
    expect((p1.number, p2.number, p2.version, p1.status), ('P-1001', 'P-1001', 2, 'Superseded'));
    expect(saveProposal(null, l, 'Other', today, 0, lines).number, 'P-1002');
  });

  test('CSV preview flags bad, missing and duplicate rows', () {
    lead('Old', email: 'old@x.in');
    final rows = previewCsv('name,company_name,email,phone\nA,Acme,a@acme.in,9876543210\n,NoName,,\nB,Beta,old@x.in,\nC,Gamma,bad,\nD,Delta,,9876543210');
    expect([for (final r in rows) r.status], ['Ready', 'Missing name or company', 'Duplicate', 'Bad email', 'Duplicate']);
    importRows(rows.take(1).toList(), today);
    expect(leads.last.phone, '+919876543210');
    expect(leads.last.next, isNotNull);
  });

  test('leave days and balance', () {
    leaves.add(LeaveRequest('Casual leave', today, today.add(const Duration(days: 2)), 'cover'));
    leaves.add(LeaveRequest('Casual leave', today, today, 'cover')..status = 'Approved');
    expect((daysWith('Pending'), daysWith('Approved'), daysLeft), (3, 1, 14));
  });
}
