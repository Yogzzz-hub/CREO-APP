// App data, kept in memory. Starts empty: team leads assign tasks on the site, the app has no backend yet.
// ponytail: in-memory only, lost on restart. Replace each list with calls to /api/v1/admin/freelancer/* and /api/v1/admin/leave.
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

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// "5 Nov"
String dm(DateTime d) => '${d.day} ${_months[d.month - 1].substring(0, 3)}';

/// "5 Nov, 11:00"
String when(DateTime d) => '${dm(d)}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

DateTime get today {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Case-insensitive search across a few fields.
bool matches(String q, List<String> fields) => q.isEmpty || fields.any((f) => f.toLowerCase().contains(q.toLowerCase()));

/// Phone as the site stores it: 10 digits get +91, anything else gets a + in front. Empty stays empty.
String normalPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  return digits.length == 10 ? '+91$digits' : '+$digits';
}

/// A link a person can open: http or https with a host.
bool validUrl(String s) {
  final u = Uri.tryParse(s.trim());
  return u != null && (u.scheme == 'https' || u.scheme == 'http') && u.host.contains('.');
}

// ---------- Tasks ----------
/// Where a task is. The site folds its many server statuses into the last four for its filter.
enum Status {
  assigned('Not started'),
  working('In progress'),
  review('In QA review'),
  revision('Revisions needed'),
  done('Approved & paid');

  const Status(this.label);
  final String label;

  /// The filter a task shows under. Not started counts as In progress, like the site.
  Status get bucket => this == assigned ? working : this;
}

/// The four filters at the top of the Work tab, in the site's order.
const buckets = [Status.working, Status.review, Status.revision, Status.done];

/// One upload of the finished work: a file or a cloud link.
class Submission {
  Submission({required this.version, required this.name, this.url = '', this.bytes, this.notes = ''}) : at = DateTime.now();
  final int version;
  final String name, url, notes;
  final int? bytes;
  final DateTime at;
}

/// A line in the task's history: who did what, and why.
class Event {
  Event(this.label, this.by, [this.note = '']) : at = DateTime.now();
  final String label, by, note;
  final DateTime at;
}

/// The site pays ₹4,500 a task when the team lead sets no fee.
const defaultFee = 4500;

class Task {
  Task({
    required this.client,
    required this.title,
    this.brief = '',
    this.format = '16:9 4K Video',
    this.due,
    this.fee = defaultFee,
    this.sourceUrl = '',
    this.length = '',
    this.hook = '',
    this.audio = '',
    this.referenceUrl = '',
    this.status = Status.assigned,
  });
  final String client, title, brief, format, sourceUrl, length, hook, audio, referenceUrl;
  final DateTime? due;
  final int fee;
  Status status;
  final submissions = <Submission>[];
  final history = <Event>[];

  bool get late => due != null && due!.isBefore(today) && status != Status.done && status != Status.review;
}

final tasks = <Task>[];

List<Task> tasksIn(Status bucket) => tasks.where((t) => t.status.bucket == bucket).toList();
int countIn(Status bucket) => tasks.where((t) => t.status.bucket == bucket).length;

/// Paid out: approved tasks only.
int get earned => tasks.where((t) => t.status == Status.done).fold(0, (s, t) => s + t.fee);

/// Every assigned milestone, paid or not.
int get expected => tasks.fold(0, (s, t) => s + t.fee);

void startWork(Task t) => save(() => t.status = Status.working);

/// Sends a new version to QA. The first is "submitted", later ones are "resubmitted".
void submit(Task t, {required String name, String url = '', int? bytes, String notes = ''}) => save(() {
      final v = t.submissions.length + 1;
      t.submissions.add(Submission(version: v, name: name, url: url, bytes: bytes, notes: notes));
      t.history.add(Event(v == 1 ? 'Submitted for QA' : 'New version resubmitted', me.name, notes));
      t.status = Status.review;
    });

/// File types and size the site accepts for an upload.
const uploadTypes = ['mp4', 'mov', 'png', 'jpg', 'jpeg', 'pdf', 'zip', 'psd'];
const maxUploadBytes = 500 * 1024 * 1024;

/// 1536000 -> "1.46 MB"
String mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';

// ---------- Time off ----------
const blackoutReasons = ['Holiday / Vacation', 'Personal Commitment', 'Studio Maintenance', 'Medical / Rest'];

/// Dates the freelancer cannot take work. Team lead and admin sign it off.
class Blackout {
  Blackout(this.reason, this.start, this.end, this.notes);
  final String reason, notes;
  final DateTime start, end;
  String status = 'Pending';
  int get days => end.difference(start).inDays + 1;
  bool get upcoming => status == 'Approved' && !end.isBefore(today);
}

final blackouts = <Blackout>[];
List<Blackout> get upcomingBlackouts => blackouts.where((b) => b.upcoming).toList();
List<Blackout> get pendingBlackouts => blackouts.where((b) => b.status == 'Pending').toList();
int daysOf(List<Blackout> list) => list.fold(0, (s, b) => s + b.days);

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

/// The contacts a freelancer has in the Workspace Hub.
final channels = [
  Channel('Creo Ops Network', 'Operations updates for freelancers and staff'),
  Channel('Creo Super Admin', 'Super admin and executive support', group: false),
  Channel('Creo Operations Admin', 'Briefs, payouts and scheduling', group: false),
];

// ---------- Signed-in freelancer ----------
class Me {
  String name = 'Freelancer';
  String phone = '';
  // Set by the platform admin; the freelancer cannot change it.
  final String email = '';
}

final me = Me();
