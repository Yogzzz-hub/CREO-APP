import '../../core/auth_repository.dart';
import '../../core/auth_session.dart';
import 'workstation_data.dart';
import 'workstation_files.dart';

const staffTaskFormats = {
  'editor': ['reel', 'story', 'shoot_day'],
  'designer': ['static_post', 'carousel'],
};

String staffTaskColumn(String bucket) => switch (bucket) {
  'backlog' => 'Assigned',
  'in_production' => 'Production',
  'internal_qa' => 'QA',
  _ => 'Review',
};

const staffSelfChecks = {
  'brand': 'Brand palette, fonts & logo match the Brand DNA',
  'spec': 'Correct aspect ratio and resolution for the format',
  'audio': 'Audio level clean, no clipping (videos)',
  'copy': 'On-screen text proofread, safe zones respected',
  'guardrails': 'No brand do-not rules broken',
};

String staffSubmissionNotes(String notes, Set<String> checks) {
  final open = staffSelfChecks.keys.where((key) => !checks.contains(key));
  final summary =
      'Self-check ${staffSelfChecks.length - open.length}/${staffSelfChecks.length}'
      '${open.isEmpty ? '' : ' (open: ${open.join(', ')})'}';
  return [notes.trim(), summary].where((s) => s.isNotEmpty).join('\n');
}

class StaffTaskEntry {
  const StaffTaskEntry(this.task, this.column);
  final WorkstationTask task;
  final String column;
  bool get highPriority =>
      task.source['is_near_sla'] == true ||
      task.source['is_revision'] == true ||
      (task.source['hours_remaining'] is num &&
          (task.source['hours_remaining'] as num) < 0);
}

List<StaffTaskEntry> staffBoardEntries(WorkstationData data, AuthUser user) {
  final groups = {
    'backlog': data.backlog,
    'in_production': data.inProduction,
    'internal_qa': data.inQa,
    'client_review': data.clientReview,
    'ready_to_publish': data.readyToPublish,
    'completed': data.completed,
  };
  return [
    for (final group in groups.entries)
      for (final task in group.value)
        if (task.assignedToUser(user) || task.eligibleBacklog(user))
          StaffTaskEntry(task, staffTaskColumn(group.key)),
  ]..sort((a, b) {
    final due = a.task.due == null
        ? (b.task.due == null ? 0 : 1)
        : b.task.due == null
        ? -1
        : a.task.due!.compareTo(b.task.due!);
    return due == 0 ? a.task.title.compareTo(b.task.title) : due;
  });
}

class StaffTaskRepository {
  StaffTaskRepository(this.session);
  final AuthSession session;
  WorkstationData? _data;
  String? _account;
  int? _generation;
  final _pending = <String>{};
  final _uncertain = <String>{};

  AuthUser get user {
    final current = session.current?.user;
    if (session.phase != SessionPhase.authenticated ||
        current == null ||
        !hasWorkstationHome(current)) {
      throw const HttpError(
        status: 403,
        code: 'FORBIDDEN',
        message: 'An editor or designer session is required.',
      );
    }
    return current;
  }

  Future<WorkstationData> load() async {
    final id = user.id;
    final generation = session.beginReadGeneration;
    final data = await WorkstationRepository(session).load();
    if (user.id != id || !session.isCurrent(generation)) {
      throw const HttpError(
        status: 0,
        code: 'SESSION_CANCELLED',
        message: 'This workspace belongs to an ended session.',
      );
    }
    _data = data;
    _account = id;
    _generation = generation;
    _uncertain.clear();
    return data;
  }

  void _checkTask(WorkstationTask task) {
    final current = user;
    final known =
        _data != null &&
        _account == current.id &&
        _generation == session.beginReadGeneration &&
        staffBoardEntries(_data!, current).any((row) => row.task.id == task.id);
    if (!known) {
      throw const HttpError(
        status: 403,
        code: 'FORBIDDEN',
        message: 'Refresh your own task board before changing this task.',
      );
    }
  }

  Future<void> start(WorkstationTask task) async {
    _checkTask(task);
    await _write(
      task.id,
      () => session.request(
        'POST',
        '/api/v1/deliverables/tasks/${Uri.encodeComponent(task.id)}/start',
      ),
    );
  }

  Future<Map<String, dynamic>> _write(
    String key,
    Future<Map<String, dynamic>> Function() operation,
  ) async {
    if (_pending.contains(key) || _uncertain.contains(key)) {
      throw const HttpError(
        status: 409,
        code: 'RECONCILE_REQUIRED',
        message:
            'This operation is pending or its result is uncertain. Refresh the board before retrying.',
      );
    }
    _pending.add(key);
    try {
      return await operation();
    } on HttpError catch (error) {
      if (error.status >= 500 ||
          [
            'TIMEOUT',
            'NETWORK_ERROR',
            'INVALID_RESPONSE',
            'INVALID_WRITE_RESPONSE',
          ].contains(error.code)) {
        _uncertain.add(key);
      }
      rethrow;
    } finally {
      _pending.remove(key);
    }
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> fields) async {
    final current = user;
    if (!staffTaskFormats[current.role]!.contains(fields['deliverable_type'])) {
      throw const HttpError(
        status: 403,
        code: 'FORMAT_NOT_ALLOWED',
        message: 'Choose a format supported by your role.',
      );
    }
    if (_account != current.id ||
        _generation != session.beginReadGeneration ||
        !(_data?.clients.any((client) => client['id'] == fields['client_id']) ??
            false)) {
      throw const HttpError(
        status: 403,
        code: 'CLIENT_NOT_AVAILABLE',
        message: 'Choose a client returned by your pod.',
      );
    }
    return _write('create-task', () async {
      final result = await session.request(
        'POST',
        '/api/v1/tasks',
        body: fields,
      );
      if (result['id'] is! String || (result['id'] as String).isEmpty) {
        throw const HttpError(
          status: 0,
          code: 'INVALID_WRITE_RESPONSE',
          message:
              'The server did not return a task identifier. Refresh before creating another task.',
        );
      }
      return result;
    });
  }

  Future<Map<String, dynamic>> upload(
    WorkstationTask task,
    WorkstationFile file,
    String notes,
    Set<String> checks,
    void Function(double) progress,
  ) {
    _checkTask(task);
    // Existing server upload fallback creates a new version and routes to QA.
    // No retry after a timeout: the user must reconcile the board first.
    return _write(task.id, () async {
      final result = await WorkstationFileTransfer(session).upload(
        '/api/v1/deliverables/tasks/${Uri.encodeComponent(task.id)}/upload',
        file,
        notes: staffSubmissionNotes(notes, checks),
        onProgress: progress,
      );
      if (result['version'] is! num || (result['version'] as num) < 1) {
        throw const HttpError(
          status: 0,
          code: 'INVALID_WRITE_RESPONSE',
          message:
              'The server did not confirm the delivery version. Refresh before submitting again.',
        );
      }
      return result;
    });
  }
}
