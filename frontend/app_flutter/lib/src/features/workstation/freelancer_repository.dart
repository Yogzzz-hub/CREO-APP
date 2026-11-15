import '../../core/auth_repository.dart';
import '../../core/auth_session.dart';

enum FreelancerTaskGroup { pending, review, revision, completed }

FreelancerTaskGroup freelancerTaskGroup(String status) {
  final value = status.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '_');
  if (const ['approved', 'completed', 'ready_to_publish'].contains(value)) {
    return FreelancerTaskGroup.completed;
  }
  if (const ['revision_requested', 'qa_rejected', 'revision'].contains(value)) {
    return FreelancerTaskGroup.revision;
  }
  if (const [
    'internal_qa',
    'pending_qa',
    'in_review',
    'ready_for_review',
    'qa_review',
  ].contains(value)) {
    return FreelancerTaskGroup.review;
  }
  return FreelancerTaskGroup.pending;
}

class FreelancerTask {
  const FreelancerTask({
    required this.id,
    required this.title,
    required this.status,
    this.client = 'Client',
    this.format = '',
    this.description = '',
    this.due,
    this.assignedAt,
    this.footage,
    this.reference,
    this.duration,
    this.audio,
    this.hook,
    this.fee,
    this.deliverables = const [],
  });
  final String id, title, status, client, format, description;
  final DateTime? due, assignedAt;
  final String? footage, reference, duration, audio, hook;
  final num? fee;
  final List<Map<String, dynamic>> deliverables;
  FreelancerTaskGroup get group => freelancerTaskGroup(status);
  bool get canStart =>
      const ['assigned', 'backlog'].contains(status.toLowerCase());
  String? get deliverableId =>
      deliverables.isEmpty ? null : deliverables.last['id'] as String?;

  factory FreelancerTask.fromJson(Map<String, dynamic> json) {
    final bp = json['blueprint'] is Map<String, dynamic>
        ? json['blueprint'] as Map<String, dynamic>
        : <String, dynamic>{};
    String? text(Object? value) =>
        value is String && value.trim().isNotEmpty ? value : null;
    final id = text(json['id']);
    if (id == null) throw const FormatException('Missing task identifier');
    final media = json['deliverables'];
    if (media != null && media is! List) {
      throw const FormatException('Invalid deliverables');
    }
    final rawFee = json['milestone_fee'] ?? bp['milestone_fee'];
    final fee = rawFee is num ? rawFee : num.tryParse('$rawFee');
    return FreelancerTask(
      id: id,
      title:
          text(json['title']) ??
          text(bp['title']) ??
          text(bp['concept_name']) ??
          text(json['deliverable_type']) ??
          'Assigned task',
      status: text(json['status']) ?? 'in_progress',
      client: text(json['client_name']) ?? 'Client',
      format: text(json['format']) ?? text(json['deliverable_type']) ?? '',
      description: text(json['description']) ?? text(bp['instructions']) ?? '',
      due: DateTime.tryParse('${json['due_date'] ?? json['sla_due_at'] ?? ''}'),
      assignedAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      footage:
          text(json['raw_footage_url']) ??
          text(bp['raw_footage_url']) ??
          text(bp['drive_url']) ??
          text(json['brief_url']) ??
          text(bp['brief_url']),
      reference: text(json['reference_url']) ?? text(bp['reference_url']),
      duration: text(json['target_duration']) ?? text(bp['target_duration']),
      audio: text(json['audio_notes']) ?? text(bp['audio_notes']),
      hook: text(json['hook']) ?? text(bp['hook']),
      fee: fee != null && fee.isFinite && fee >= 0 ? fee : null,
      deliverables: media == null
          ? const []
          : List.unmodifiable(
              (media as List).map((item) {
                if (item is! Map<String, dynamic>) {
                  throw const FormatException('Invalid deliverable');
                }
                return item;
              }),
            ),
    );
  }
}

/// Never accepts arbitrary task IDs for writes. The server-scoped assignment
/// read establishes the current account's action candidates; the backend must
/// still enforce authorization on every endpoint.
class FreelancerRepository {
  FreelancerRepository(this.session);
  final AuthSession session;
  String? _account;
  int? _generation;
  final Set<String> _known = {};
  final Set<String> _busy = {};
  final Set<String> _uncertain = {};

  String _guard() {
    final user = session.current?.user;
    if (session.phase != SessionPhase.authenticated ||
        user == null ||
        user.role != 'freelancer' ||
        user.mustResetPassword == true) {
      throw const HttpError(
        status: 403,
        code: 'FORBIDDEN',
        message: 'A verified freelancer session is required.',
      );
    }
    if (_account != user.id || _generation != session.beginReadGeneration) {
      _known.clear();
      _uncertain.clear();
      _account = user.id;
      _generation = session.beginReadGeneration;
    }
    return user.id;
  }

  Future<List<FreelancerTask>> load() async {
    final account = _guard();
    final response = await session.request(
      'GET',
      '/api/v1/admin/freelancer/my-tasks',
    );
    if (_guard() != account) {
      throw const HttpError(
        status: 0,
        code: 'SESSION_CANCELLED',
        message: 'Account changed.',
      );
    }
    final raw = response['items'] ?? response['tasks'];
    if (raw is! List) {
      throw const HttpError(
        status: 0,
        code: 'INVALID_RESPONSE',
        message: 'Assigned work could not be read.',
      );
    }
    try {
      final tasks = raw
          .map((row) => FreelancerTask.fromJson(row as Map<String, dynamic>))
          .toList();
      _known
        ..clear()
        ..addAll(tasks.map((t) => t.id));
      _uncertain.clear();
      return tasks;
    } on Object {
      throw const HttpError(
        status: 0,
        code: 'INVALID_RESPONSE',
        message: 'Assigned work could not be read.',
      );
    }
  }

  void requireTask(FreelancerTask task) {
    _guard();
    if (_uncertain.contains(task.id)) {
      throw const HttpError(
        status: 0,
        code: 'RECONCILE_REQUIRED',
        message:
            'The previous action may have reached the server. Close this form and refresh assigned work before submitting again.',
      );
    }
    if (!_known.contains(task.id)) {
      throw const HttpError(
        status: 403,
        code: 'TASK_FORBIDDEN',
        message: 'Reload your assigned work before continuing.',
      );
    }
  }

  Future<Map<String, dynamic>> _write(
    FreelancerTask task,
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    requireTask(task);
    if (!_busy.add(task.id)) {
      throw const HttpError(
        status: 0,
        code: 'ACTION_PENDING',
        message: 'This task already has an action in progress.',
      );
    }
    try {
      return await session.request(method, path, body: body);
    } on HttpError catch (error) {
      markUncertain(task, error);
      rethrow;
    } finally {
      _busy.remove(task.id);
    }
  }

  void markUncertain(FreelancerTask task, HttpError error) {
    if (error.status >= 500 ||
        const ['TIMEOUT', 'NETWORK_ERROR'].contains(error.code)) {
      _uncertain.add(task.id);
    }
  }

  Future<Map<String, dynamic>> start(FreelancerTask task) => _write(
    task,
    'PATCH',
    '/api/v1/admin/freelancer/tasks/${Uri.encodeComponent(task.id)}/start-work',
  );

  Future<Map<String, dynamic>> submitLink(
    FreelancerTask task,
    String link,
    String notes,
  ) {
    final uri = Uri.tryParse(link.trim());
    if (uri == null ||
        !const ['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const HttpError(
        status: 422,
        code: 'INVALID_ASSET_URL',
        message: 'Enter a valid http or https asset link.',
      );
    }
    return _write(
      task,
      'POST',
      '/api/v1/admin/freelancer/submit-work',
      body: {
        'task_id': task.id,
        if (task.deliverableId != null) 'deliverable_id': task.deliverableId,
        'asset_url': uri.toString(),
        if (notes.trim().isNotEmpty) 'submission_notes': notes.trim(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> history(FreelancerTask task) async {
    requireTask(task);
    if (task.deliverableId == null) return [];
    final response = await session.request(
      'GET',
      '/api/v1/deliverables/${Uri.encodeComponent(task.deliverableId!)}/history',
    );
    final rows = response['items'];
    if (rows is! List) {
      throw const HttpError(
        status: 0,
        code: 'INVALID_RESPONSE',
        message: 'History could not be read.',
      );
    }
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }
}
