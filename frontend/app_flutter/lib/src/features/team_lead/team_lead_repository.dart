import '../../core/auth_repository.dart';
import '../../core/auth_session.dart';
import '../workstation/workstation_data.dart';

/// Reads server-scoped reporting lines and delegates QA authority to the server.
class TeamLeadRepository {
  TeamLeadRepository(this.session) : _generation = session.beginReadGeneration;
  final AuthSession session;
  final int _generation;
  WorkstationData? _snapshot;
  List<Map<String, dynamic>> members = [];
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _leaves = [];
  Future<List<Map<String, dynamic>>> leaves() async {
    _check();
    final result = await session.request('GET', '/api/v1/admin/leave');
    _check();
    return _leaves = (result['items'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> decideLeave(
    Map<String, dynamic> leave, {
    required bool approve,
  }) async {
    _check();
    if (!_leaves.any((row) => identical(row, leave)) ||
        leave['id'] is! String ||
        leave['is_self'] != false ||
        leave['user_id'] == session.current?.user.id ||
        leave['status'] != 'pending' ||
        leave[approve ? 'can_approve' : 'can_reject'] != true) {
      throw const HttpError(
        status: 403,
        code: 'LEAVE_FORBIDDEN',
        message:
            'Only permitted pending pod-member requests can be reviewed. Your own leave requires another reviewer.',
      );
    }
    final status = approve ? 'approved' : 'rejected';
    await _write(
      'leave:${leave['id']}',
      'POST',
      '/api/v1/admin/leave/${Uri.encodeComponent(leave['id'])}/${approve ? 'approve' : 'reject'}',
      {},
      accepts: (result) =>
          result['id'] == leave['id'] && result['status'] == status,
    );
    _leaves = [];
  }

  Future<void> updateMember(
    Map<String, dynamic> member, {
    required int capacity,
    required List<String> skills,
    required bool accepting,
  }) async {
    _check();
    if (!members.any((row) => identical(row, member)) ||
        member['id'] is! String) {
      throw const HttpError(
        status: 403,
        code: 'OUTSIDE_POD',
        message: 'Choose a member from the current pod.',
      );
    }
    if (capacity < 1 || skills.any((skill) => skill.trim().isEmpty)) {
      throw ArgumentError(
        'Enter a positive daily capacity and nonempty skills.',
      );
    }
    await _write(
      'member:${member['id']}',
      'PATCH',
      '/api/v1/admin/teams/${Uri.encodeComponent(member['id'])}',
      {
        'daily_capacity': capacity,
        'skills': skills,
        'is_accepting_work': accepting,
      },
      accepts: (result) =>
          result['status'] == 'updated' &&
          result['user_id'] == member['id'] &&
          result['daily_capacity'] == capacity &&
          result['is_accepting_work'] == accepting &&
          result['skills'] is List,
    );
  }

  Future<Map<String, dynamic>> _write(
    String key,
    String method,
    String path,
    Map<String, dynamic> body, {
    bool Function(Map<String, dynamic>)? accepts,
  }) async {
    _check();
    if (!_pending.add(key)) {
      throw const HttpError(
        status: 409,
        code: 'WRITE_UNCONFIRMED',
        message:
            'This operation is pending or unconfirmed. Verify its server status before retrying.',
      );
    }
    try {
      final result = await session.request(method, path, body: body);
      _check();
      if (accepts != null ? !accepts(result) : result['id'] is! String) {
        throw const FormatException('Unverified response');
      }
      _pending.remove(key);
      return result;
    } catch (error) {
      if (error is HttpError &&
          error.status >= 400 &&
          error.status < 500 &&
          !{
            'TIMEOUT',
            'NETWORK_ERROR',
            'INVALID_RESPONSE',
          }.contains(error.code)) {
        _pending.remove(key);
        rethrow;
      }
      throw const HttpError(
        status: 0,
        code: 'WRITE_UNCONFIRMED',
        message:
            'The result is unconfirmed. Check server status before retrying.',
      );
    }
  }

  Future<void> createTask(Map<String, dynamic> fields) async {
    _check();
    if (!(_snapshot?.clients.any((row) => row['id'] == fields['client_id']) ??
        false)) {
      throw const HttpError(
        status: 403,
        code: 'OUTSIDE_POD',
        message: 'Choose a client assigned to this pod.',
      );
    }
    if (!{
          'reel',
          'story',
          'shoot_day',
          'static_post',
          'carousel',
        }.contains(fields['deliverable_type']) ||
        '${fields['title'] ?? ''}'.trim().isEmpty) {
      throw const HttpError(
        status: 400,
        code: 'INVALID_TASK',
        message: 'Enter a title and supported format.',
      );
    }
    await _write('create-task', 'POST', '/api/v1/tasks', {
      ...fields,
      'auto_dispatch': false,
    });
  }

  Future<List<Map<String, dynamic>>> tickets() async {
    _check();
    final data = _snapshot ?? await load();
    final result = await session.request(
      'GET',
      '/api/v1/admin/support/tickets',
    );
    _check();
    final clients = data.clients.map((row) => row['id']).toSet();
    return _tickets = (result['items'] as List)
        .cast<Map<String, dynamic>>()
        .where(
          (row) =>
              clients.contains(row['client_id']) ||
              row['client_id'] == session.current?.user.id,
        )
        .toList();
  }

  void _ticket(Map<String, dynamic> ticket) {
    _check();
    if (!_tickets.any((row) => identical(row, ticket))) {
      throw const HttpError(
        status: 403,
        code: 'OUTSIDE_POD',
        message: 'Reload the current pod support queue.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> messages(
    Map<String, dynamic> ticket,
  ) async {
    _ticket(ticket);
    final result = await session.request(
      'GET',
      '/api/v1/admin/support/tickets/${Uri.encodeComponent(ticket['id'])}/messages',
    );
    _check();
    return (result['items'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> reply(
    Map<String, dynamic> ticket,
    String message,
    String status,
  ) async {
    _ticket(ticket);
    if (message.trim().isEmpty) throw ArgumentError('Enter a reply.');
    await _write(
      'reply:${ticket['id']}',
      'POST',
      '/api/v1/admin/support/tickets/${Uri.encodeComponent(ticket['id'])}/messages',
      {'message_text': message.trim(), 'status': status},
    );
  }

  static final _journals = Expando<Map<String, Set<String>>>();
  Set<String> get _pending {
    final byGeneration = _journals[session] ??= {};
    return byGeneration.putIfAbsent('$_generation', () => <String>{});
  }

  void _check() {
    if (!session.isCurrent(_generation) ||
        session.phase != SessionPhase.authenticated ||
        session.current?.user.role != 'team_lead' ||
        session.current?.user.mustResetPassword == true) {
      _snapshot = null;
      throw const HttpError(
        status: 403,
        code: 'FORBIDDEN',
        message: 'Sign in with a team lead account.',
      );
    }
  }

  Future<WorkstationData> load() async {
    _check();
    final json = await session.request('GET', '/api/v1/admin/pod-dashboard');
    _check();
    members = (json['members'] as List).cast<Map<String, dynamic>>();
    return _snapshot = WorkstationData.fromJson(json);
  }

  Future<void> reassign(
    WorkstationTask task,
    Map<String, dynamic> member,
  ) async {
    _check();
    final data = _snapshot;
    if (data == null ||
        ![
          ...data.backlog,
          ...data.inProduction,
          ...data.inQa,
        ].any((row) => identical(row, task)) ||
        !members.any((row) => identical(row, member)) ||
        member['id'] is! String ||
        member['is_accepting_work'] == false ||
        !{'editor', 'designer', 'team_lead'}.contains(member['role'])) {
      throw const HttpError(
        status: 403,
        code: 'OUTSIDE_POD',
        message: 'Choose an available member and task from the current pod.',
      );
    }
    final key = 'assign:${task.id}';
    if (!_pending.add(key)) {
      throw const HttpError(
        status: 409,
        code: 'WRITE_UNCONFIRMED',
        message: 'The previous assignment is pending or unconfirmed.',
      );
    }
    try {
      final result = await session.request(
        'POST',
        '/api/v1/admin/pod-tasks/${Uri.encodeComponent(task.id)}/reassign',
        body: {'assignee_id': member['id']},
      );
      _check();
      if (result['status'] != 'success' ||
          result['task_id'] != task.id ||
          result['assigned_to'] != member['id']) {
        throw const FormatException('Unverified assignment');
      }
      _snapshot = null;
      _pending.remove(key);
    } catch (error) {
      if (error is HttpError &&
          error.status >= 400 &&
          error.status < 500 &&
          !{
            'TIMEOUT',
            'NETWORK_ERROR',
            'INVALID_RESPONSE',
          }.contains(error.code)) {
        _pending.remove(key);
        rethrow;
      }
      throw const HttpError(
        status: 0,
        code: 'WRITE_UNCONFIRMED',
        message:
            'Assignment outcome is unconfirmed. Verify server status before another assignment.',
      );
    }
  }

  Future<void> review(
    WorkstationTask task, {
    required bool approve,
    String comment = '',
  }) async {
    _check();
    if (!(_snapshot?.inQa.any((row) => identical(row, task)) ?? false)) {
      throw const HttpError(
        status: 409,
        code: 'STALE_TASK',
        message: 'Refresh the review queue before continuing.',
      );
    }
    if (!approve && comment.trim().isEmpty) {
      throw const HttpError(
        status: 400,
        code: 'NOTES_REQUIRED',
        message: 'Explain the changes needed.',
      );
    }
    if (!_pending.add(task.id)) {
      throw const HttpError(
        status: 409,
        code: 'WRITE_UNCONFIRMED',
        message:
            'The previous review is pending or unconfirmed. Check server status before another decision.',
      );
    }
    try {
      final response = await session.request(
        'POST',
        '/api/v1/admin/pod-tasks/${Uri.encodeComponent(task.id)}/qa-review',
        body: {
          'decision': approve ? 'approve' : 'reject',
          'comment': comment.trim(),
        },
      );
      _check();
      if (response['status'] != 'success' ||
          response['task_id'] != task.id ||
          response['new_task_status'] is! String) {
        throw const FormatException(
          'The review response could not be verified.',
        );
      }
      _snapshot = null;
      _pending.remove(task.id);
    } catch (error) {
      // Keep uncertain writes blocked across reopened pages. Never auto-retry QA.
      if (error is HttpError &&
          error.status >= 400 &&
          error.status < 500 &&
          !{
            'TIMEOUT',
            'NETWORK_ERROR',
            'INVALID_RESPONSE',
          }.contains(error.code)) {
        _pending.remove(task.id);
        rethrow;
      }
      throw const HttpError(
        status: 0,
        code: 'WRITE_UNCONFIRMED',
        message:
            'Review outcome is unconfirmed. Refresh the queue and verify the task on the server. Do not resubmit this decision.',
      );
    }
  }
}
