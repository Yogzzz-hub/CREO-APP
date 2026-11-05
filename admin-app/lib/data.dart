// App data, kept in memory. Starts empty; the forms in the app add to it.
// ponytail: in-memory only, lost on restart. Replace each list with calls to the live /api/v1 endpoints.
import 'package:flutter/foundation.dart';

/// Bumped after every change so all screens rebuild.
final changed = ValueNotifier(0);
void save(VoidCallback change) {
  change();
  changed.value++;
}

enum S { ok, bad, wait }

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

/// "Thursday 5 Nov"
String longDate(DateTime d) => '${_days[d.weekday - 1]} ${d.day} ${monthName(d).substring(0, 3)}';

/// "5 Nov"
String dm(DateTime d) => '${d.day} ${monthName(d).substring(0, 3)}';

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
DateTime get today {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// One CSV cell: always quoted, inner quotes doubled, and a leading = + - @ tab or CR
/// prefixed with ' so spreadsheets show it as text instead of running it as a formula.
String csvCell(Object v) {
  var s = '$v';
  if (s.isNotEmpty && '=+-@\t\r'.contains(s[0])) s = "'$s";
  return '"${s.replaceAll('"', '""')}"';
}

String csvRow(List<Object> cells) => cells.map(csvCell).join(',');

/// Names link records together (a task's client, a person's pod), so each name must be unique.
bool nameTaken(Iterable<String> names, String name) => names.any((n) => n.trim().toLowerCase() == name.trim().toLowerCase());

/// Case-insensitive search across a few fields.
bool matches(String q, List<String> fields) => q.isEmpty || fields.any((f) => f.toLowerCase().contains(q.toLowerCase()));

// ---------- Plans and clients ----------
class Plan {
  Plan(this.name, this.price, this.posts, this.reels, this.stories, this.turnaround, this.extras);
  String name, turnaround, extras;
  int price, posts, reels, stories;
  String get includes => '$posts posts, $reels reels, $stories stories · $turnaround${extras.isEmpty ? '' : ' · $extras'}';
}

/// The agency's plans, as listed on the live site.
final plans = [
  Plan('Starter Growth', 25000, 8, 4, 10, '48 h turnaround', ''),
  Plan('Brand Accelerator', 50000, 15, 8, 20, '24 h turnaround', 'pod lead'),
  Plan('Scale', 100000, 30, 16, 40, '12 h turnaround', 'unlimited revisions'),
];
Plan? planNamed(String? name) => plans.where((p) => p.name == name).firstOrNull;

class Client {
  Client({required this.name, this.contact = '', this.email = '', this.industry = '', this.plan, this.pod = ''});
  String name, contact, email, industry, pod;
  String? plan;
  int? customFee; // set when a discount proposal is accepted
  bool paid = false, upi = false;
  String fonts = '', colours = '', audience = '', instagram = '';
  int get fee => paid ? (customFee ?? planNamed(plan)?.price ?? 0) : 0;
}

final clients = <Client>[];
List<Client> get paidClients => clients.where((c) => c.paid).toList();
List<Client> get unpaidClients => clients.where((c) => !c.paid).toList();
List<String> get clientNames => [for (final c in clients) c.name];

int get mrr => paidClients.fold(0, (s, c) => s + c.fee);
int get upiTotal => paidClients.where((c) => c.upi).fold(0, (s, c) => s + c.fee);
int get cardTotal => mrr - upiTotal;
int clientsOn(String plan) => paidClients.where((c) => c.plan == plan).length;

class Negotiation {
  Negotiation(this.client, this.fromPlan, this.toPlan, this.proposed, this.notes);
  String client, fromPlan, toPlan, notes, status = 'Waiting';
  int proposed;
  DateTime date = DateTime.now();
}

final negotiations = <Negotiation>[];
List<Negotiation> get waitingProposals => negotiations.where((n) => n.status == 'Waiting').toList();

const payMethods = ['Card, Razorpay', 'UPI or bank transfer'];

class Invoice {
  Invoice(this.client, this.scope, this.amount, this.method, this.date);
  String client, scope, method;
  int amount;
  DateTime date;
  int get number => invoices.indexOf(this) + 1001;
}

final invoices = <Invoice>[];

/// Invoiced amount per month for the last 6 months, oldest first.
List<(String, int)> invoicedByMonth(DateTime now) => [
      for (var i = 5; i >= 0; i--)
        (
          monthName(DateTime(now.year, now.month - i)).substring(0, 3),
          invoices
              .where((v) => v.date.year == DateTime(now.year, now.month - i).year && v.date.month == DateTime(now.year, now.month - i).month)
              .fold(0, (s, v) => s + v.amount),
        ),
    ];

// ---------- Sales ----------
const leadStages = ['New', 'Contacted', 'Proposal', 'Negotiation', 'Won', 'Lost'];
const priorities = ['Urgent', 'High', 'Medium', 'Low'];

class Lead {
  Lead(this.company, this.rep, this.priority, this.value);
  String company, rep, priority, stage = 'New';
  int value, touchpoints = 0;
  DateTime last = DateTime.now();
  bool get open => stage != 'Won' && stage != 'Lost';
}

final leads = <Lead>[];
int get pipelineValue => leads.where((l) => l.open).fold(0, (s, l) => s + l.value);
String get winRate {
  final won = leads.where((l) => l.stage == 'Won').length, lost = leads.where((l) => l.stage == 'Lost').length;
  return won + lost == 0 ? '—' : '${100 * won ~/ (won + lost)}%';
}

// ---------- Content ----------
enum Draft { review, revision, approved, published }

const formats = ['Reel', 'Post', 'Story'];

class Deliverable {
  Deliverable(this.title, this.client, this.format, this.pod, this.date);
  String title, client, format, pod;
  DateTime date; // planned posting date
  Draft state = Draft.review;
  final notes = <String>[];
}

final deliverables = <Deliverable>[];
List<Deliverable> drafts(Draft d) => deliverables.where((x) => x.state == d).toList();

/// "2 reels, 1 post, 1 story"
String formatCounts(Iterable<Deliverable> list) => [
      for (final (one, many) in const [('reel', 'reels'), ('post', 'posts'), ('story', 'stories')])
        if (list.where((d) => d.format.toLowerCase() == one).length case final n when n > 0) '$n ${n == 1 ? one : many}',
    ].join(', ');

enum Stage { todo, making, review, done }

const stageNames = ['To do', 'Making', 'Review', 'Done'];

class Task {
  Task(this.title, this.client, this.who, this.pod, this.priority, this.due);
  String title, client, who, pod, priority;
  DateTime due;
  DateTime? doneAt;
  Stage stage = Stage.todo;
}

final tasks = <Task>[];
List<Task> tasksIn(Stage s) => tasks.where((t) => t.stage == s).toList();

/// The publishing statuses used by Instagram Connect on the web.
const postStatuses = [
  'Awaiting client approval', 'Approved, needs a time', 'Scheduled', 'Processing with Instagram', 'Published',
  'Publishing failed', 'Paused', 'Needs reconciliation', 'Canceled',
];

class Post {
  Post(this.title, this.client, this.when, this.status, {this.source});
  String title, client, status;
  DateTime when;
  final Deliverable? source; // the draft this post came from, so actions touch only its own posts
  bool get finished => status == 'Published' || status == 'Canceled';
}

final posts = <Post>[];

// ---------- Team ----------
enum Kind { staff, sales, freelancer }

class Person {
  Person(this.name, this.email, this.kind, {this.role = '', this.pod = '', this.skills = ''});
  String name, email, role, pod, skills;
  Kind kind;
  bool active = true;
  int rate = 0, quota = 0, commission = 0; // freelancer ₹/hour; sales target ₹ and commission %
  bool invited = true; // an invite link was sent; they set their own password
}

final people = <Person>[];
List<Person> peopleOf(Kind k) => people.where((p) => p.kind == k).toList();
List<String> get staffNames => [for (final p in people.where((p) => p.kind != Kind.sales)) p.name];

class Pod {
  Pod(this.name, this.lead, this.hours);
  String name, lead;
  int hours; // hours per sprint
  final standups = <String>[];
  List<Person> get members => people.where((p) => p.pod == name).toList();
}

final pods = <Pod>[];
List<String> get podNames => [for (final p in pods) p.name];

/// Open tasks per person. 20 or more is too much; 5 or fewer is free to take work.
const overloadAt = 20, freeAt = 5, maxLoad = 35;
int openTasks(String who) => tasks.where((t) => t.who == who && t.stage != Stage.done).length;
List<(String, int)> get workload => [for (final p in people.where((p) => p.kind != Kind.sales && p.active)) (p.name, openTasks(p.name))]
  ..sort((a, b) => b.$2.compareTo(a.$2));
List<(String, int)> get overloaded => workload.where((w) => w.$2 >= overloadAt).toList();

String get onTimeRate {
  final done = tasks.where((t) => t.doneAt != null).toList();
  if (done.isEmpty) return '—';
  return '${100 * done.where((t) => !t.doneAt!.isAfter(t.due.add(const Duration(days: 1)))).length ~/ done.length}%';
}

String get revisionRate => deliverables.isEmpty ? '—' : '${100 * drafts(Draft.revision).length ~/ deliverables.length}%';

class Leave {
  Leave(this.who, this.start, this.end, this.reason);
  String who, reason, status = 'Pending';
  DateTime start, end;
  int get days => end.difference(start).inDays + 1;
}

final leaves = <Leave>[];
List<Leave> leavesIn(String status) => leaves.where((l) => l.status == status).toList();
List<Leave> get onLeaveToday => leaves.where((l) => l.status == 'Approved' && !today.isBefore(l.start) && !today.isAfter(l.end)).toList();

// ---------- Inbox ----------
class Msg {
  Msg(this.from, this.text) : at = DateTime.now();
  String from, text;
  DateTime at;
}

class Channel {
  Channel(this.name, {this.group = true});
  String name;
  bool group;
  final messages = <Msg>[];
}

final channels = <Channel>[];

class Ticket {
  Ticket(this.client, this.subject, this.priority, this.agent) : opened = DateTime.now(), id = tickets.length + 1;
  String client, subject, priority, agent;
  DateTime opened;
  int id;
  DateTime? closedAt;
  bool get closed => closedAt != null;
  final replies = <Msg>[];
}

final tickets = <Ticket>[];
List<Ticket> get openTickets => tickets.where((t) => !t.closed).toList();
int get solvedToday => tickets.where((t) => t.closed && sameDay(t.closedAt!, DateTime.now())).length;

// ---------- Signed-in admin ----------
class Me {
  String name = 'Admin', role = 'Agency admin', email = '', phone = '', agency = '';
}

final me = Me();

// ---------- Decisions shown on Home ----------
List<Leave> get pendingLeaves => leavesIn('Pending');

/// How many things on Home need the admin.
int get decisionCount =>
    (drafts(Draft.review).isNotEmpty ? 1 : 0) + (pendingLeaves.isNotEmpty ? 1 : 0) + (overloaded.isNotEmpty ? 1 : 0) + (waitingProposals.isNotEmpty ? 1 : 0);
