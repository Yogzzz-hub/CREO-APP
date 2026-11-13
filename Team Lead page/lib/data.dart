// App data, kept in memory. Starts empty: the lead adds pod members, clients and tasks with the forms.
// ponytail: in-memory only, lost on restart. Replace each list with calls to the site's /api/v1/admin/* endpoints
// (pod-dashboard, deliverables, leave, publishing, support).
import 'package:flutter/foundation.dart';

/// Bumped after every change so all screens rebuild.
final changed = ValueNotifier(0);
void save(VoidCallback change) {
  change();
  changed.value++;
}

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// "5 Nov"
String dm(DateTime d) => '${d.day} ${_months[d.month - 1].substring(0, 3)}';

/// "November 2026"
String monthName(DateTime d) => '${_months[d.month - 1]} ${d.year}';

/// "5 Nov, 11:00"
String when(DateTime d) => '${dm(d)}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// "2026-11-05"
String ymd(DateTime d) => d.toIso8601String().substring(0, 10);

DateTime get today {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// 1 -> "1 day", 3 -> "3 days".
String dayCount(int n) => '$n day${n == 1 ? '' : 's'}';

/// "1 task", "3 tasks"
String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

/// Case-insensitive search across a few fields.
bool matches(String q, List<String> fields) => q.isEmpty || fields.any((f) => f.toLowerCase().contains(q.toLowerCase()));

/// Phone as the site stores it: 10 digits get +91, anything else gets a + in front. Empty stays empty.
String normalPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  return digits.length == 10 ? '+91$digits' : '+$digits';
}

/// One CSV cell: always quoted, inner quotes doubled, and a leading = + - @ tab or CR
/// prefixed with ' so spreadsheets show it as text instead of running it as a formula.
String csvCell(Object v) {
  var s = '$v';
  if (s.isNotEmpty && '=+-@\t\r'.contains(s[0])) s = "'$s";
  return '"${s.replaceAll('"', '""')}"';
}

String csvRow(List<Object> cells) => cells.map(csvCell).join(',');

/// Why [name] cannot be a pod member's name, or null. Forms pick people by name, so names must be unique
/// (the lead included, [except] the person being renamed) and must not look like the "(you)" or " · " labels.
String? memberNameProblem(String name, {Member? except}) {
  final n = name.trim();
  if (n.contains('·') || n.toLowerCase().endsWith('(you)')) return 'Names cannot contain "·" or end with "(you)"';
  if (nameTaken(members.where((m) => m != except).map((m) => m.name), n)) return 'Already in the pod';
  return null;
}

/// True when another item already uses [name], ignoring case and spaces at the ends.
bool nameTaken(Iterable<String> names, String name) => names.any((n) => n.trim().toLowerCase() == name.trim().toLowerCase());

// ---------- Pod ----------
/// A person in the lead's pod. The lead is one too.
class Member {
  Member(this.name, this.role, {this.lead = false});
  String name, role;
  final bool lead;
}

/// The site shows a member at 100% load with 6 open tasks.
const capacity = 6;

class Pod {
  String name = 'Pod';
  String standup = '10:00 AM';
}

final pod = Pod();

/// The signed-in team lead. First in [members].
final me = Member('Team Lead', 'Pod Team Lead & QA Director', lead: true);
String phone = '';

// Set by the organisation admin; the lead cannot change it.
const email = '';

final members = <Member>[me];

/// Open tasks: everything not yet dispatched to the client.
List<Task> openTasks(Member m) => tasks.where((t) => t.who == m && t.stage != Stage.dispatched).toList();

/// Share of [capacity] in use, 0 to 100.
int load(Member m) => (openTasks(m).length * 100 ~/ capacity).clamp(0, 100);

bool onLeave(Member m, DateTime day) => leaves.any((l) => l.who == m && l.status == 'Approved' && !day.isBefore(l.start) && !day.isAfter(l.end));

/// Members working today (not on approved leave).
int get activeToday => members.where((m) => !onLeave(m, today)).length;

/// Moves backlog tasks off members over [capacity] to the least loaded member who is not on leave.
/// Returns how many moved.
int balanceLoads() {
  var moved = 0;
  save(() {
    for (final m in members) {
      while (openTasks(m).length > capacity) {
        final spare = members.where((o) => o != m && !onLeave(o, today)).toList()..sort((a, b) => openTasks(a).length.compareTo(openTasks(b).length));
        if (spare.isEmpty || openTasks(spare.first).length + 1 >= openTasks(m).length) break;
        final t = openTasks(m).where((t) => t.stage == Stage.backlog).firstOrNull;
        if (t == null) break;
        t.history.add(Event('Re-routed from ${m.name} to ${spare.first.name}', me.name));
        t.who = spare.first;
        moved++;
      }
    }
  });
  return moved;
}

// ---------- Clients ----------
/// Monthly assets a plan includes, as the site shows them on every account.
class Quota {
  const Quota(this.reels, this.stories, this.posts);
  final int reels, stories, posts;
  int get total => reels + stories + posts;
}

const plans = {'Starter Growth': Quota(4, 8, 8), 'Growth': Quota(4, 8, 8), 'Brand Accelerator': Quota(8, 12, 12), 'Scale': Quota(12, 16, 16)};

class Client {
  Client(this.name, this.plan, {this.email = ''});
  final String name, email;
  String plan;
  Quota get quota => plans[plan] ?? plans['Growth']!;
}

final clients = <Client>[];

/// Assets of [format] dispatched for [c] this month.
int delivered(Client c, Format format) => tasks
    .where(
      (t) =>
          t.client == c &&
          t.format == format &&
          t.stage == Stage.dispatched &&
          t.dispatched != null &&
          t.dispatched!.month == today.month &&
          t.dispatched!.year == today.year,
    )
    .length;

/// Share of this month's quota delivered, 0 to 100.
int burn(Client c) {
  final done = delivered(c, Format.reel) + delivered(c, Format.story) + delivered(c, Format.post) + delivered(c, Format.carousel);
  return c.quota.total == 0 ? 0 : (done * 100 ~/ c.quota.total).clamp(0, 100);
}

/// The pod's quota for the month across all clients.
int get podQuota => clients.fold(0, (s, c) => s + c.quota.total);

// ---------- Tasks ----------
enum Format {
  reel('Reel'),
  story('Story'),
  post('Post'),
  carousel('Carousel');

  const Format(this.label);
  final String label;
}

/// The task queue columns, in the site's order.
enum Stage {
  backlog('Backlog'),
  progress('In progress'),
  review('QA review'),
  dispatched('Dispatched');

  const Stage(this.label);
  final String label;
}

/// A line in the task's history: who did what, and why.
class Event {
  Event(this.label, this.by, [this.note = '']) : at = DateTime.now();
  final String label, by, note;
  final DateTime at;
}

/// The lead's QA checklist on the Review page. All three must be ticked to approve.
const checklist = [
  'Brand palette, contrast and type match the Brand DNA',
  'Format, safe zones and export settings are correct',
  'Copy, audio and pacing are client-ready',
];

class Task {
  Task({required this.title, required this.client, required this.format, required this.who, this.due, this.brief = ''}) : created = DateTime.now();
  final String title, brief;
  final Client client;
  final Format format;
  final DateTime created;
  Member who;
  DateTime? due, dispatched;
  Stage stage = Stage.backlog;

  /// Each send to QA is a new version.
  int version = 0;

  /// Why the task is stuck, or empty.
  String blocker = '';
  final history = <Event>[];
  final checks = List.filled(checklist.length, false);

  bool get late => due != null && due!.isBefore(today) && stage != Stage.dispatched;
}

final tasks = <Task>[];

List<Task> inStage(Stage s) => tasks.where((t) => t.stage == s).toList();
List<Task> get blocked => tasks.where((t) => t.blocker.isNotEmpty && t.stage != Stage.dispatched).toList();

Task assign({required String title, required Client client, required Format format, required Member who, DateTime? due, String brief = ''}) {
  final t = Task(title: title, client: client, format: format, who: who, due: due, brief: brief);
  save(() {
    t.history.add(Event('Assigned to ${who.name}', me.name));
    tasks.insert(0, t);
  });
  return t;
}

void startTask(Task t) => save(() {
  t.stage = Stage.progress;
  t.history.add(Event('Work started', t.who.name));
});

/// The creative hands a new version to the lead.
void sendToQa(Task t) => save(() {
  t.version++;
  t.stage = Stage.review;
  t.checks.fillRange(0, t.checks.length, false);
  t.history.add(Event('v${t.version} sent for lead QA', t.who.name));
});

/// Back to the creative with notes. Needs a reason, like the site.
void requestRevision(Task t, String notes) => save(() {
  t.stage = Stage.progress;
  t.history.add(Event('Revision requested on v${t.version}', me.name, notes));
});

/// Signed off and sent to the client. Only when every checklist item is ticked.
bool approve(Task t) {
  if (t.checks.contains(false)) return false;
  save(() {
    t.stage = Stage.dispatched;
    t.dispatched = DateTime.now();
    t.blocker = '';
    t.history.add(Event('Approved and sent to client', me.name));
  });
  return true;
}

void setBlocker(Task t, String reason) => save(() {
  t.blocker = reason;
  t.history.add(Event(reason.isEmpty ? 'Blocker cleared' : 'Blocked', me.name, reason));
});

void reassign(Task t, Member to) => save(() {
  t.history.add(Event('Re-routed from ${t.who.name} to ${to.name}', me.name));
  t.who = to;
});

/// Weekly report: one row per task.
String tasksCsv() => [
  csvRow(const ['Task', 'Client', 'Format', 'Assignee', 'Stage', 'Version', 'Due', 'Blocker']),
  for (final t in tasks) csvRow([t.title, t.client.name, t.format.label, t.who.name, t.stage.label, t.version, t.due == null ? '' : ymd(t.due!), t.blocker]),
].join('\n');

String clientsCsv() => [
  csvRow(const ['Client', 'Plan', 'Reels', 'Stories', 'Posts', 'Quota burn %']),
  for (final c in clients)
    csvRow([
      c.name,
      c.plan,
      '${delivered(c, Format.reel)}/${c.quota.reels}',
      '${delivered(c, Format.story)}/${c.quota.stories}',
      '${delivered(c, Format.post) + delivered(c, Format.carousel)}/${c.quota.posts}',
      burn(c),
    ]),
].join('\n');

// ---------- Standups ----------
class Standup {
  Standup(this.notes) : at = DateTime.now();
  final String notes;
  final DateTime at;
}

final standups = <Standup>[];

bool get standupLoggedToday => standups.any((s) => sameDay(s.at, today));

// ---------- Leave ----------
class Leave {
  Leave(this.who, this.start, this.end, this.reason);
  final Member who;
  final DateTime start, end;
  final String reason;

  /// Pending, Approved or Rejected. The lead's own requests go to the admin, not to the lead.
  String status = 'Pending';
  int get days => end.difference(start).inDays + 1;
}

final leaves = <Leave>[];

/// Requests from the pod that the lead decides.
List<Leave> get toDecide => leaves.where((l) => l.status == 'Pending' && l.who != me).toList();

/// Pending requests from the pod that start tomorrow.
int get startingTomorrow => toDecide.where((l) => sameDay(l.start, today.add(const Duration(days: 1)))).length;

/// Decides a pod member's pending request. Refuses the lead's own request (the admin decides it)
/// and requests already decided. Returns whether it changed anything.
bool decide(Leave l, bool ok) {
  if (l.who == me || l.status != 'Pending') return false;
  save(() => l.status = ok ? 'Approved' : 'Rejected');
  return true;
}

// ---------- Publishing ----------
/// The site's Instagram queue statuses that a lead can set from the app.
enum Post {
  scheduled('Scheduled'),
  paused('Paused'),
  published('Published'),
  canceled('Canceled');

  const Post(this.label);
  final String label;
}

class Slot {
  Slot(this.task, this.at);
  final Task task;
  DateTime at;
  Post status = Post.scheduled;
}

final slots = <Slot>[];

/// Queues approved work for Instagram. Refuses work that is not approved, already queued, or a time in the past.
bool schedule(Task t, DateTime at) {
  if (!readyToSchedule.contains(t) || !at.isAfter(DateTime.now())) return false;
  save(() => slots.add(Slot(t, at)));
  return true;
}

/// Only work the lead has approved can be put in the publishing queue, once.
List<Task> get readyToSchedule => inStage(Stage.dispatched).where((t) => !slots.any((s) => s.task == t && s.status != Post.canceled)).toList();

// ---------- Support ----------
enum Priority { urgent, high, medium }

class Ticket {
  Ticket(this.client, this.issue, this.priority) : opened = DateTime.now();
  final Client client;
  final String issue;
  final Priority priority;
  final DateTime opened;
  DateTime? closed;
  bool get open => closed == null;
}

final tickets = <Ticket>[];

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

/// Groups and admin contacts a team lead has in the Workspace Hub. Pod members are added as direct chats.
final channels = [
  Channel('all-pod-leads', 'Executive admin and all pod leads'),
  Channel('pod-team', 'Your pod: team lead, specialists and admin'),
  Channel('general', 'Standups, milestones and announcements'),
  Channel('Creo Super Admin', 'Super admin and executive support', group: false),
  Channel('Creo Operations Admin', 'Workspace admin', group: false),
];

/// One direct chat per pod member, made when they join.
final memberChats = <Member, Channel>{};

Member addMember(String name, String role) {
  final m = Member(name, role);
  save(() {
    members.add(m);
    memberChats[m] = Channel(name, role, group: false);
  });
  return m;
}

List<Channel> get allChannels => [
  ...channels,
  for (final m in members.skip(1))
    if (memberChats[m] != null) memberChats[m]!,
];
