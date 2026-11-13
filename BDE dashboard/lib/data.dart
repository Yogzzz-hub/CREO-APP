// App data, kept in memory. Starts empty; the forms in the app add to it.
// ponytail: in-memory only, lost on restart. Replace each list with calls to /api/v1/bde and /api/v1/crm.
import 'package:flutter/foundation.dart';

/// Bumped after every change so all screens rebuild.
final changed = ValueNotifier(0);
void save(VoidCallback change) {
  change();
  changed.value++;
}

/// Indian rupee grouping: 235000 -> ₹2,35,000.
String inr(int n) {
  final s = n.abs().toString();
  final sign = n < 0 ? '-' : '';
  if (s.length <= 3) return '$sign₹$s';
  var head = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (head.length > 2) {
    parts.insert(0, head.substring(head.length - 2));
    head = head.substring(0, head.length - 2);
  }
  if (head.isNotEmpty) parts.insert(0, head);
  return '$sign₹${parts.join(',')},${s.substring(s.length - 3)}';
}

const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
String monthName(DateTime d) => _months[d.month - 1];

/// "Thu 5 Nov"
String shortDate(DateTime d) => '${_days[d.weekday - 1].substring(0, 3)} ${d.day} ${monthName(d).substring(0, 3)}';

/// "5 Nov"
String dm(DateTime d) => '${d.day} ${monthName(d).substring(0, 3)}';

/// "5 Nov, 11:00"
String when(DateTime d) => '${dm(d)}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// 1.0 -> "1", 2.5 -> "2.5".
String plain(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
bool thisMonth(DateTime d) => d.year == DateTime.now().year && d.month == DateTime.now().month;
DateTime get today {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// One address: no spaces, one @, and a dot in the domain (name@brand.in). The server must check again.
bool validEmail(String s) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s.trim());

/// Case-insensitive search across a few fields.
bool matches(String q, List<String> fields) => q.isEmpty || fields.any((f) => f.toLowerCase().contains(q.toLowerCase()));

/// Phone as the site stores it: 10 digits get +91, anything else gets a + in front. Empty stays empty.
String normalPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  return digits.length == 10 ? '+91$digits' : '+$digits';
}

// ---------- Leads ----------
enum Stage {
  fresh('New'),
  contacted('Contacted'),
  qualified('Qualified'),
  meeting('Meeting scheduled'),
  proposal('Proposal sent'),
  negotiation('Negotiation'),
  won('Won'),
  lost('Lost'),
  nurture('Nurture'),
  disqualified('Disqualified');

  const Stage(this.label);
  final String label;
  bool get open => this != won && this != lost && this != disqualified;
}

Stage stageNamed(String label) => Stage.values.firstWhere((s) => s.label == label);

/// The four columns of the BDE queue. The site leaves `qualified` out of every column; here it sits under Contacted.
enum Lane {
  contacted('Contacted', [Stage.fresh, Stage.contacted, Stage.qualified, Stage.meeting], Stage.contacted),
  negotiation('In negotiation', [Stage.proposal, Stage.negotiation], Stage.negotiation),
  won('Won', [Stage.won], Stage.won),
  lost('Lost', [Stage.lost], Stage.lost);

  const Lane(this.label, this.stages, this.stage);
  final String label;
  final List<Stage> stages;
  final Stage stage; // where a lead lands when moved into this lane
}

enum Temp {
  hot('Hot'),
  warm('Warm'),
  cold('Cold'),
  unknown('Unknown');

  const Temp(this.label);
  final String label;
}

class Activity {
  Activity(this.type, this.summary, [this.outcome = '']) : at = DateTime.now();
  final String type, summary, outcome;
  final DateTime at;
}

class Lead {
  Lead({
    required this.name,
    required this.company,
    this.email = '',
    this.phone = '',
    this.requirements = '',
    this.industry = '',
    this.location = '',
    this.source = 'Inbound website',
    this.value = 0,
    this.temp = Temp.warm,
    this.stage = Stage.contacted,
  }) : created = DateTime.now();
  String name, company, email, phone, requirements, industry, location, source;
  int value, booked = 0;
  Temp temp;
  Stage stage;
  final DateTime created;
  DateTime? wonAt;
  String consent = 'Unknown'; // Opted in, Opted out
  int? score; // qualification score out of 100
  int evidence = 0; // % of the five qualification factors known
  final activities = <Activity>[];

  List<FollowUp> get pending => followUps.where((f) => f.lead == this && !f.done).toList()..sort((a, b) => a.due.compareTo(b.due));
  FollowUp? get next => pending.firstOrNull;
}

final leads = <Lead>[];
List<Lead> inLane(Lane l) => leads.where((x) => l.stages.contains(x.stage)).toList();
List<Lead> get openLeads => leads.where((l) => l.stage.open).toList();
int get pipelineValue => openLeads.fold(0, (s, l) => s + l.value);
int get wonCount => leads.where((l) => l.stage == Stage.won).length;
String get conversion => leads.isEmpty ? '—' : '${(100 * wonCount / leads.length).round()}%';

/// Removes a lead and everything that points at it, so nothing is left orphaned.
void deleteLead(Lead l) {
  leads.remove(l);
  followUps.removeWhere((f) => f.lead == l);
  proposals.removeWhere((p) => p.lead == l);
  referrals.removeWhere((r) => r.lead == l);
  drafts.removeWhere((d) => d.lead == l);
}

void setStage(Lead l, Stage s, {String reason = '', int? booked}) {
  l.stage = s;
  if (s == Stage.won) {
    l.booked = booked ?? l.value;
    l.wonAt = DateTime.now();
  }
  l.activities.add(Activity('Stage', 'Moved to ${s.label}', reason));
}

/// Moves the lead's next follow-up to [due], or adds one if it has none.
void setFollowUp(Lead l, DateTime due, {String title = 'Follow-up call', String kind = 'Call'}) {
  final n = l.next;
  if (n != null) {
    n.due = due;
  } else {
    followUps.add(FollowUp(l, title, kind, due));
  }
}

/// The +3d button: next follow-up at 11:00, three days from today.
DateTime plus3() => today.add(const Duration(days: 3, hours: 11));

/// Five factors scored 0 to 100. Missing ones stay null; until all five are known the lead stays Unknown
/// unless the BDE overrides it.
const factors = ['Service fit', 'Intent', 'Urgency', 'Engagement', 'Decision maker'];
const hotAt = 70, warmAt = 40; // ponytail: agency settings decide these on the site; fixed here

void qualify(Lead l, List<int?> scores, Temp? override, String reason) {
  final known = scores.whereType<int>().toList();
  l.score = known.isEmpty ? null : (known.reduce((a, b) => a + b) / known.length).round();
  l.evidence = 100 * known.length ~/ factors.length;
  l.temp = override ??
      (known.length < factors.length
          ? Temp.unknown
          : l.score! >= hotAt
              ? Temp.hot
              : l.score! >= warmAt
                  ? Temp.warm
                  : Temp.cold);
  l.activities.add(Activity('Qualification', 'Score ${l.score ?? '—'}/100 · ${l.evidence}% evidence · ${l.temp.label}', reason));
}

/// Opting out suppresses every pending message draft for the lead.
void setConsent(Lead l, String status, String purpose, String evidence) {
  l.consent = status;
  if (status == 'Opted out') {
    for (final d in drafts.where((d) => d.lead == l && d.status == 'Draft')) {
      d.status = 'Suppressed';
    }
  }
  l.activities.add(Activity('WhatsApp permission', '$status · $purpose', evidence));
}

// ---------- Follow-ups (CRM next actions) ----------
const actionKinds = ['Call', 'Message', 'Meeting', 'Research', 'Proposal', 'Referral'];

class FollowUp {
  FollowUp(this.lead, this.title, this.kind, this.due);
  final Lead lead;
  String title, kind;
  DateTime due;
  DateTime? doneAt;
  bool get done => doneAt != null;
  bool get overdue => !done && due.isBefore(DateTime.now());
  bool get dueToday => !done && sameDay(due, DateTime.now());
}

final followUps = <FollowUp>[];
List<FollowUp> get pendingFollowUps => followUps.where((f) => !f.done).toList()..sort((a, b) => a.due.compareTo(b.due));
int get dueTodayCount => followUps.where((f) => f.dueToday && !f.overdue).length;
int get overdueCount => followUps.where((f) => f.overdue).length;

/// Complete or snooze a follow-up. Returns a message when something is missing, else null.
String? resolve(FollowUp f, {required bool complete, required String reason, String nextTitle = '', DateTime? due}) {
  if (reason.trim().isEmpty) return complete ? 'Add the conversation outcome' : 'Add a reason for snoozing';
  if (!complete) {
    if (due == null) return 'Pick a new due date';
    f.due = due;
    f.lead.activities.add(Activity('Snoozed', f.title, reason));
    return null;
  }
  final last = f.lead.pending.length == 1 && f.lead.stage.open;
  if (last && (nextTitle.trim().isEmpty || due == null)) return 'This is the lead\'s last action: add the next one and its due date';
  f.doneAt = DateTime.now();
  f.lead.activities.add(Activity('Completed', f.title, reason));
  if (nextTitle.trim().isNotEmpty && due != null) followUps.add(FollowUp(f.lead, nextTitle.trim(), f.kind, due));
  return null;
}

/// Follow-ups this month done on time, out of those that came due.
String get onTimeRate {
  final due = followUps.where((f) => thisMonth(f.due) && (f.done || f.overdue)).toList();
  if (due.isEmpty) return 'No due actions';
  return '${100 * due.where((f) => f.done && !f.doneAt!.isAfter(f.due)).length ~/ due.length}%';
}

// ---------- CSV import ----------
class ImportRow {
  ImportRow(this.row, this.name, this.company, this.email, this.phone, this.status);
  final int row;
  final String name, company, email, phone, status; // status: Ready, Missing name or company, Duplicate, Bad email
}

/// Columns: name, company_name, email, phone. A header row is skipped.
/// ponytail: plain comma split, no quoted commas; add a CSV parser if real exports need it.
List<ImportRow> previewCsv(String text) {
  final rows = <ImportRow>[];
  final seen = {for (final l in leads) ...[l.email.toLowerCase(), l.phone]}.where((s) => s.isNotEmpty).toSet();
  for (final (i, line) in text.split('\n').indexed) {
    final c = line.split(',').map((s) => s.trim()).toList();
    if (line.trim().isEmpty || (i == 0 && c.first.toLowerCase() == 'name')) continue;
    String at(int n) => n < c.length ? c[n] : '';
    final email = at(2), phone = normalPhone(at(3));
    final status = at(0).isEmpty || at(1).isEmpty
        ? 'Missing name or company'
        : email.isNotEmpty && !validEmail(email)
            ? 'Bad email'
            : seen.contains(email.toLowerCase()) || seen.contains(phone)
                ? 'Duplicate'
                : 'Ready';
    seen.addAll([email.toLowerCase(), phone].where((s) => s.isNotEmpty));
    rows.add(ImportRow(i + 1, at(0), at(1), email, phone, status));
  }
  return rows;
}

void importRows(List<ImportRow> rows, DateTime due) {
  for (final r in rows) {
    final l = Lead(name: r.name, company: r.company, email: r.email, phone: r.phone, source: 'CSV import', temp: Temp.unknown, stage: Stage.fresh);
    leads.add(l);
    followUps.add(FollowUp(l, 'Initial qualification call', 'Call', due));
  }
}

// ---------- Proposals ----------
enum Billing {
  oneTime('One-time'),
  monthly('Monthly'),
  quarterly('Quarterly'),
  annual('Annual');

  const Billing(this.label);
  final String label;
}

class Line {
  Line({this.title = '', this.scope = '', this.qty = 1, this.price = 0, this.discount = 0, this.billing = Billing.oneTime});
  String title, scope;
  double qty, discount; // discount in %
  int price; // ₹ per unit
  Billing billing;
  int get gross => (qty * price).round();
  int get off => (gross * discount / 100).round();
  Line copy() => Line(title: title, scope: scope, qty: qty, price: price, discount: discount, billing: billing);
}

class Totals {
  const Totals(this.subtotal, this.discount, this.tax, this.total);
  final int subtotal, discount, tax, total;
}

/// One total per billing period: recurring charges are never added to one-time charges.
Map<Billing, Totals> totalsOf(List<Line> lines, double taxPct) => {
      for (final b in Billing.values)
        if (lines.where((l) => l.billing == b) case final ls when ls.isNotEmpty)
          b: () {
            final sub = ls.fold(0, (s, l) => s + l.gross), off = ls.fold(0, (s, l) => s + l.off);
            final tax = ((sub - off) * taxPct / 100).round();
            return Totals(sub, off, tax, sub - off + tax);
          }(),
    };

class Proposal {
  Proposal(this.lead, this.number, this.version, this.title, this.validUntil, this.taxPct, this.lines,
      {this.summary = '', this.scope = '', this.terms = ''});
  final Lead lead;
  final String number;
  final int version;
  final String title, summary, scope, terms;
  final DateTime validUntil;
  final double taxPct;
  final List<Line> lines;
  final created = DateTime.now();
  String status = 'In review'; // waits for the BDE head; Superseded once revised
  Map<Billing, Totals> get totals => totalsOf(lines, taxPct);
}

final proposals = <Proposal>[];
int get toReviewCount => proposals.where((p) => p.status == 'In review').length;

/// Saving a revision keeps the number, adds a version and supersedes the old one.
Proposal saveProposal(Proposal? original, Lead lead, String title, DateTime validUntil, double tax, List<Line> lines,
    {String summary = '', String scope = '', String terms = ''}) {
  final numbers = {for (final p in proposals) p.number};
  final p = Proposal(lead, original?.number ?? 'P-${1001 + numbers.length}', (original?.version ?? 0) + 1, title, validUntil, tax, lines,
      summary: summary, scope: scope, terms: terms);
  original?.status = 'Superseded';
  proposals.insert(0, p);
  lead.activities.add(Activity('Proposal', '${p.number} v${p.version}: $title'));
  return p;
}

// ---------- Referrals and messages ----------
class Referral {
  Referral(this.lead, this.referrer, this.source, this.notes) : at = DateTime.now();
  final Lead lead;
  final String referrer, source, notes;
  final DateTime at;
  String status = 'Submitted'; // the BDE head verifies and qualifies it
}

final referrals = <Referral>[];

class MessageDraft {
  MessageDraft(this.lead, this.body) : at = DateTime.now(), status = lead.consent == 'Opted out' ? 'Suppressed' : 'Draft';
  final Lead lead;
  final String body;
  final DateTime at;
  String status;
}

final drafts = <MessageDraft>[];

int get bookedThisMonth => leads.where((l) => l.wonAt != null && thisMonth(l.wonAt!)).fold(0, (s, l) => s + l.booked);
int get winsThisMonth => leads.where((l) => l.wonAt != null && thisMonth(l.wonAt!)).length;
int get newThisMonth => leads.where((l) => thisMonth(l.created)).length;
List<Lead> get needsNextStep => openLeads.where((l) => l.next == null).toList();

// ---------- Plans ----------
class Plan {
  const Plan(this.name, this.price, this.includes);
  final String name;
  final int price;
  final List<String> includes;
}

/// The agency's plans, as listed on the live site.
const plans = [
  Plan('Starter Growth', 25000, ['8 static posters a month', '4 short video reels a month', '10 story templates', '48 h turnaround']),
  Plan('Brand Accelerator', 50000,
      ['15 static posters a month', '8 short video reels a month', '20 story templates', '24 h turnaround', 'Dedicated creative pod lead']),
  Plan('Scale', 100000, ['30 static posters a month', '16 high-production reels', '40 story templates', '12 h turnaround', 'Unlimited revisions']),
];

class Negotiation {
  Negotiation(this.client, this.email, this.fromPlan, this.toPlan, this.standard, this.proposed, this.notes) : date = DateTime.now();
  final String client, email, fromPlan, toPlan, notes;
  final int standard, proposed;
  final DateTime date;
  String status = 'Waiting'; // the admin decides
}

final negotiations = <Negotiation>[];

// ---------- Chat ----------
class Msg {
  Msg(this.from, this.text) : at = DateTime.now();
  final String from, text;
  final DateTime at;
}

class Channel {
  Channel(this.name, this.about, {this.group = true});
  final String name, about;
  final bool group;
  final messages = <Msg>[];
}

/// The channels a BDE has in the Workspace Hub.
final channels = [
  Channel('bde-sales-hub', 'BDE outreach and pipeline, sales reps and admin'),
  Channel('general', 'Standups, milestones and announcements'),
  Channel('Creo Super Admin', 'Super admin and executive support', group: false),
];

// ---------- Leave ----------
const allowance = 18;
const leaveKinds = ['Casual leave', 'Medical / sick leave', 'Vacation / PTO', 'Sales travel / conference'];

class LeaveRequest {
  LeaveRequest(this.kind, this.start, this.end, this.notes);
  final String kind, notes;
  final DateTime start, end;
  String status = 'Pending'; // the agency admin approves or rejects
  int get days => end.difference(start).inDays + 1;
}

final leaves = <LeaveRequest>[];
int daysWith(String status) => leaves.where((l) => l.status == status).fold(0, (s, l) => s + l.days);
int get daysLeft => (allowance - daysWith('Approved') - daysWith('Pending')).clamp(0, allowance);

// ---------- Signed-in BDE ----------
class Me {
  String name = 'BDE';
}

final me = Me();
