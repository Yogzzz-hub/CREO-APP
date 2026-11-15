import 'package:flutter/foundation.dart';

import '../../core/auth_repository.dart';
import '../../core/auth_session.dart';

typedef LoadWorkstation = Future<WorkstationData> Function();

bool hasWorkstationHome(AuthUser user) =>
    user.mustResetPassword != true &&
    const ['editor', 'designer'].contains(user.role);

class WorkstationRepository {
  const WorkstationRepository(this.session);
  final AuthSession session;

  Future<WorkstationData> load() async {
    final user = session.current?.user;
    if (session.phase != SessionPhase.authenticated ||
        user == null ||
        !hasWorkstationHome(user)) {
      throw const HttpError(
        status: 403,
        code: 'FORBIDDEN',
        message:
            'Sign in with an editor or designer account to open this workspace.',
      );
    }
    final json = await session.request('GET', '/api/v1/admin/pod-dashboard');
    try {
      return WorkstationData.fromJson(json);
    } on FormatException {
      throw const HttpError(
        status: 0,
        code: 'INVALID_RESPONSE',
        message: 'Your workspace could not be read. Please try again.',
      );
    }
  }
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected object');
  }
  return value;
}

String _text(Object? value, [String fallback = '']) {
  if (value == null) return fallback;
  if (value is! String) throw const FormatException('Expected text');
  return value;
}

List<Map<String, dynamic>> _rows(Object? value) {
  if (value is! List) throw const FormatException('Expected list');
  return value.map(_object).toList(growable: false);
}

class WorkstationTask {
  const WorkstationTask({
    required this.id,
    required this.client,
    required this.title,
    required this.format,
    required this.status,
    this.assignedTo,
    this.assigneeId,
    this.assigneeEmail,
    this.assigneeName,
    this.due,
    this.feedback,
    this.fileUrl,
    this.version,
    this.source = const {},
  });
  final String id, client, title, format, status;
  final String? assignedTo, assigneeId, assigneeEmail, assigneeName;
  final DateTime? due;
  final String? feedback, fileUrl;
  final int? version;
  final Map<String, dynamic> source;

  factory WorkstationTask.fromJson(Map<String, dynamic> json) {
    final assignee = json['assignee'] == null
        ? null
        : _object(json['assignee']);
    final blueprint = json['blueprint'] == null
        ? null
        : _object(json['blueprint']);
    final media = json['deliverable'] == null
        ? null
        : _object(json['deliverable']);
    final id = _text(json['id']);
    if (id.isEmpty) throw const FormatException('Missing task identifier');
    final format = _text(json['deliverable_type'], 'Deliverable');
    final concept = _text(blueprint?['concept_name']).isNotEmpty
        ? _text(blueprint?['concept_name'])
        : _text(blueprint?['title']);
    final version = media?['version'];
    if (version != null && version is! num) {
      throw const FormatException('Invalid version');
    }
    return WorkstationTask(
      id: id,
      client: _text(json['client_name'], 'Client'),
      title: concept.isEmpty ? format.replaceAll('_', ' ') : concept,
      format: format,
      status: _text(json['status']),
      assignedTo: json['assigned_to'] == null
          ? null
          : _text(json['assigned_to']),
      assigneeId: assignee?['id'] == null ? null : _text(assignee?['id']),
      assigneeEmail: assignee?['email'] == null
          ? null
          : _text(assignee?['email']),
      assigneeName: _text(json['assignee_name']),
      due: DateTime.tryParse(_text(json['due_date'] ?? json['sla_due_at'])),
      feedback: _text(
        media?['rejection_comment'] ??
            json['rejection_comment'] ??
            json['qa_feedback'] ??
            json['feedback'],
      ),
      fileUrl: media?['file_url'] == null ? null : _text(media?['file_url']),
      version: (version as num?)?.toInt(),
      source: json,
    );
  }

  // Same ID/email/name fallbacks as React creative-roles.ts. Server ownership
  // remains authoritative; this scopes the display and does not authorize writes.
  bool assignedToUser(AuthUser user) =>
      (user.id.isNotEmpty &&
          (assignedTo == user.id || assigneeId == user.id)) ||
      (user.email.isNotEmpty &&
          assigneeEmail?.toLowerCase() == user.email.toLowerCase()) ||
      (user.fullName.isNotEmpty &&
          assigneeName?.toLowerCase() == user.fullName.toLowerCase());

  bool eligibleBacklog(AuthUser user) {
    if (assignedToUser(user)) return true;
    if ((assignedTo?.isNotEmpty ?? false) ||
        (assigneeId?.isNotEmpty ?? false)) {
      return false;
    }
    final formats = user.role == 'editor'
        ? const ['reel', 'story', 'shoot_day']
        : const ['static_post', 'carousel'];
    return formats.contains(format.toLowerCase());
  }
}

class WorkstationMember {
  const WorkstationMember(this.name, this.role, this.craft);
  final String name, role, craft;
  factory WorkstationMember.fromJson(Map<String, dynamic> json) =>
      WorkstationMember(
        _text(json['full_name'], _text(json['name'], 'Team member')),
        _text(json['role']),
        _text(json['craft_title'], _text(json['role']).replaceAll('_', ' ')),
      );
}

class WorkstationNotice {
  const WorkstationNotice(this.title, this.message);
  final String title, message;
  factory WorkstationNotice.fromJson(Map<String, dynamic> json) =>
      WorkstationNotice(_text(json['title']), _text(json['message']));
}

class WorkstationData {
  const WorkstationData({
    required this.podName,
    this.members = const [],
    this.backlog = const [],
    this.inProduction = const [],
    this.inQa = const [],
    this.completed = const [],
    this.notices = const [],
    this.clientReview = const [],
    this.readyToPublish = const [],
    this.clients = const [],
  });
  final String podName;
  final List<WorkstationMember> members;
  final List<WorkstationTask> backlog, inProduction, inQa, completed;
  final List<WorkstationNotice> notices;
  final List<WorkstationTask> clientReview, readyToPublish;
  final List<Map<String, dynamic>> clients;
  factory WorkstationData.fromJson(Map<String, dynamic> json) {
    final pod = _object(json['pod']), tasks = _object(json['tasks']);
    final name = _text(pod['name']);
    if (name.isEmpty) throw const FormatException('Missing pod');
    List<WorkstationTask> group(String key) =>
        _rows(tasks[key]).map(WorkstationTask.fromJson).toList(growable: false);
    return WorkstationData(
      podName: name,
      members: _rows(
        json['members'],
      ).map(WorkstationMember.fromJson).toList(growable: false),
      backlog: group('backlog'),
      inProduction: group('in_production'),
      inQa: group('internal_qa'),
      completed: group('completed'),
      clientReview: tasks['client_review'] == null
          ? []
          : group('client_review'),
      readyToPublish: tasks['ready_to_publish'] == null
          ? []
          : group('ready_to_publish'),
      clients: json['clients'] == null ? [] : _rows(json['clients']),
      notices: _rows(
        json['notifications'],
      ).map(WorkstationNotice.fromJson).toList(growable: false),
    );
  }

  List<WorkstationTask> get active => _sorted([...inProduction, ...inQa]);
  List<WorkstationTask> get feedback => _sorted([
    ...inProduction,
    ...inQa,
    ...backlog,
  ]).where((task) => task.feedback?.trim().isNotEmpty ?? false).toList();
  List<WorkstationTask> tasks(
    AuthUser user, {
    bool allPod = false,
    bool archived = false,
  }) => _sorted(
    (archived ? completed : active)
        .where((task) => allPod || task.assignedToUser(user))
        .toList(),
  );
  int dueByToday(AuthUser user, DateTime now) {
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tasks(user)
        .where(
          (task) => task.due != null && task.due!.toLocal().isBefore(tomorrow),
        )
        .length;
  }

  static List<WorkstationTask> _sorted(List<WorkstationTask> rows) =>
      rows..sort((a, b) {
        if (a.due == null) return b.due == null ? 0 : 1;
        if (b.due == null) return -1;
        return a.due!.compareTo(b.due!);
      });
}

class WorkstationController extends ChangeNotifier {
  WorkstationController(this.load);
  final LoadWorkstation load;
  WorkstationData? data;
  HttpError? error;
  bool loading = false;
  bool _disposed = false;
  int _epoch = 0;
  Future<void>? _pending;

  Future<void> refresh() {
    if (_disposed) return Future<void>.value();
    return _pending ??= _refresh().whenComplete(() => _pending = null);
  }

  Future<void> _refresh() async {
    final epoch = ++_epoch;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final next = await load();
      if (_disposed || epoch != _epoch) return;
      data = next;
    } catch (exception) {
      if (_disposed || epoch != _epoch) return;
      error = exception is HttpError
          ? exception
          : const HttpError(
              status: 0,
              code: 'WORKSPACE_UNAVAILABLE',
              message: 'Your workspace could not be loaded. Please try again.',
            );
      if (error!.status == 401 ||
          error!.status == 403 ||
          const [
            'SESSION_CANCELLED',
            'SESSION_REVOKED',
            'ACCOUNT_SUSPENDED',
          ].contains(error!.code)) {
        data = null;
      }
    } finally {
      if (!_disposed && epoch == _epoch) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    data = null;
    super.dispose();
  }
}
