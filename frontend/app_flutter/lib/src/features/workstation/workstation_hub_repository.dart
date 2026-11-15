import '../../core/auth_repository.dart';
import '../../core/auth_session.dart';

typedef WorkspaceRecord = Map<String, dynamic>;

List<WorkspaceRecord> workspaceRows(WorkspaceRecord value) {
  final rows = value['items'];
  if (rows is! List || rows.any((row) => row is! Map<String, dynamic>)) {
    throw const FormatException('The workspace returned an invalid list.');
  }
  return List.unmodifiable(rows.cast<WorkspaceRecord>());
}

String workspaceText(Object? value, [String fallback = '']) =>
    value is String && value.isNotEmpty ? value : fallback;

class _PendingWorkspaceWrite {
  _PendingWorkspaceWrite(this.confirmedBy);
  final bool Function(WorkspaceRecord) confirmedBy;
  bool uncertain = false;
}

/// Shared by reopened pages for this session only. The journal is not an offline
/// queue: ambiguous non-idempotent writes stay blocked until a server read proves
/// the intended effect. No automatic retry, and no journal survives logout.
class _WorkspaceWrites {
  _WorkspaceWrites._(this.generation);
  static final _sessions = Expando<_WorkspaceWrites>();
  int generation;
  final Map<String, _PendingWorkspaceWrite> pending = {};
  static _WorkspaceWrites forSession(AuthSession session) {
    final existing = _sessions[session];
    if (existing != null) return existing;
    final owner = _WorkspaceWrites._(session.beginReadGeneration);
    session.addListener(() {
      if (session.phase == SessionPhase.clearing ||
          session.phase == SessionPhase.signedOut ||
          owner.generation != session.beginReadGeneration) {
        owner.pending.clear();
        owner.generation = session.beginReadGeneration;
      }
    });
    _sessions[session] = owner;
    return owner;
  }

  Future<WorkspaceRecord> run(
    String key,
    Future<WorkspaceRecord> Function() send, {
    bool Function(WorkspaceRecord)? confirmedBy,
    bool Function(WorkspaceRecord)? accepts,
  }) async {
    if (pending.containsKey(key)) {
      throw const HttpError(
        status: 0,
        code: 'WRITE_UNCONFIRMED',
        message:
            'The previous request is pending or its outcome is unconfirmed. Refresh the server history/status before attempting this action again.',
      );
    }
    final entry = _PendingWorkspaceWrite(confirmedBy ?? (_) => false);
    pending[key] = entry;
    try {
      final result = await send();
      if (accepts != null && !accepts(result)) {
        throw const FormatException(
          'The mutation response could not be verified.',
        );
      }
      if (identical(pending[key], entry)) pending.remove(key);
      return result;
    } catch (error) {
      if (identical(pending[key], entry)) {
        if ((error is HttpError &&
                (error.status >= 500 ||
                    {
                      'TIMEOUT',
                      'NETWORK_ERROR',
                      'INVALID_RESPONSE',
                    }.contains(error.code))) ||
            error is FormatException) {
          entry.uncertain = true;
          throw HttpError(
            status: error is HttpError ? error.status : 0,
            code: 'WRITE_UNCONFIRMED',
            message:
                'The request outcome is unconfirmed. Refresh server history/status before another action. Your draft has been retained.',
          );
        } else {
          pending.remove(key);
        }
      }
      rethrow;
    }
  }

  bool observe(String key, WorkspaceRecord value) {
    final entry = pending[key];
    if (entry?.uncertain == true && entry!.confirmedBy(value)) {
      pending.remove(key);
      return true;
    }
    return false;
  }
}

/// Uses the existing session transport. No independent tokens or private caches.
class WorkstationHubRepository {
  WorkstationHubRepository(this.session)
    : _ownerId = session.current?.user.id,
      _ownerGeneration = session.beginReadGeneration;
  final AuthSession session;
  final String? _ownerId;
  final int _ownerGeneration;
  late final _writes = _WorkspaceWrites.forSession(session);
  final Map<String, Set<String>> _historyIds = {};
  final Map<String, WorkspaceRecord> _confirmedMessages = {};
  WorkspaceRecord? takeConfirmedMessage(String id, {required bool direct}) =>
      _confirmedMessages.remove('message:$direct:$id');
  final Set<String> _channels = {}, _contacts = {};
  static const staffRoles = {
    'editor',
    'designer',
    'team_lead',
    'admin',
    'super_admin',
  };
  String get role => session.current?.user.role ?? '';

  void requireAccess({bool publishing = false}) {
    final current = session.current;
    if (session.phase != SessionPhase.authenticated ||
        current == null ||
        !session.isCurrent(_ownerGeneration) ||
        current.user.id != _ownerId ||
        current.user.mustResetPassword == true ||
        !(staffRoles.contains(role) || (!publishing && role == 'freelancer'))) {
      _channels.clear();
      _contacts.clear();
      throw const HttpError(
        status: 403,
        code: 'WORKSPACE_FORBIDDEN',
        message: 'This workspace is unavailable for the current session.',
      );
    }
  }

  Future<List<WorkspaceRecord>> channels() async {
    requireAccess();
    if (role == 'freelancer') return const [];
    final rows = workspaceRows(
      await session.request('GET', '/api/v1/chat/channels'),
    );
    _channels
      ..clear()
      ..addAll(rows.map((row) => workspaceText(row['id'])));
    return rows;
  }

  Future<List<WorkspaceRecord>> contacts() async {
    requireAccess();
    final rows = workspaceRows(
      await session.request('GET', '/api/v1/chat/contacts'),
    );
    // The server is authoritative; its returned contacts already enforce role access.
    _contacts
      ..clear()
      ..addAll(rows.map((row) => workspaceText(row['id'])));
    return rows;
  }

  void _thread(String id, bool direct) {
    requireAccess();
    if (!(direct ? _contacts : _channels).contains(id) ||
        (!direct && role == 'freelancer')) {
      throw const HttpError(
        status: 403,
        code: 'THREAD_FORBIDDEN',
        message: 'Choose a conversation available to your account.',
      );
    }
  }

  Future<List<WorkspaceRecord>> messages(
    String id, {
    required bool direct,
  }) async {
    _thread(id, direct);
    final query = Uri(
      queryParameters: {direct ? 'other_user_id' : 'channel': id},
    ).query;
    final rows = workspaceRows(
      await session.request('GET', '/api/v1/chat/messages?$query'),
    );
    final key = 'message:$direct:$id';
    for (final row in rows) {
      if (_writes.observe(key, row)) _confirmedMessages[key] = row;
    }
    _historyIds[key] = rows.map((row) => workspaceText(row['id'])).toSet();
    return rows;
  }

  Future<WorkspaceRecord> send(
    String id,
    String message, {
    required bool direct,
    WorkspaceRecord attachment = const {},
  }) async {
    _thread(id, direct);
    if (message.length > 10000) {
      throw const FormatException(
        'Messages must be no longer than 10,000 characters.',
      );
    }
    if (message.trim().isEmpty && attachment['attachment_url'] == null) {
      throw const FormatException('Write a message or choose an attachment.');
    }
    final key = 'message:$direct:$id';
    final baselineKnown = _historyIds.containsKey(key);
    final previousIds = Set<String>.of(_historyIds[key] ?? {});
    return _writes.run(
      key,
      () => session.request(
        'POST',
        '/api/v1/chat/messages',
        body: {
          if (direct) 'recipient_id': id else 'channel': id,
          if (direct) 'thread_type': 'direct',
          'message': message.trim(),
          for (final key in [
            'attachment_url',
            'attachment_name',
            'attachment_type',
            'attachment_size',
          ])
            if (attachment.containsKey(key)) key: attachment[key],
        },
      ),
      accepts: (result) => workspaceText(result['id']).isNotEmpty,
      confirmedBy: (row) =>
          baselineKnown &&
          !previousIds.contains(row['id']) &&
          row['sender_id'] == _ownerId &&
          row['message'] ==
              (message.trim().isEmpty
                  ? attachment['attachment_name']
                  : message.trim()) &&
          row['attachment_url'] == attachment['attachment_url'],
    );
  }

  Future<List<WorkspaceRecord>> jobs({
    int offset = 0,
    String status = '',
    String clientId = '',
  }) async {
    requireAccess(publishing: true);
    if (offset < 0) throw const FormatException('Invalid page.');
    final query = Uri(
      queryParameters: {
        'offset': '$offset',
        if (status.isNotEmpty) 'status': status,
        if (clientId.isNotEmpty) 'client_id': clientId,
      },
    ).query;
    return workspaceRows(
      await session.request('GET', '/api/v1/publishing/jobs?$query'),
    );
  }

  Future<List<WorkspaceRecord>> publishingClients() async {
    requireAccess(publishing: true);
    return workspaceRows(await session.request('GET', '/api/v1/admin/clients'));
  }

  Future<WorkspaceRecord> createGroup(
    String name,
    String description,
    List<String> members, {
    bool pod = false,
  }) async {
    requireAccess();
    if (!{'admin', 'super_admin', 'team_lead'}.contains(role)) {
      throw const HttpError(
        status: 403,
        code: 'ACTION_FORBIDDEN',
        message: 'Only leads and administrators can create groups.',
      );
    }
    final cleanName = name.trim().replaceFirst(RegExp(r'^#+'), '');
    if (cleanName.length < 2 ||
        cleanName.length > 60 ||
        description.trim().length > 255 ||
        members.any((id) => !_contacts.contains(id))) {
      throw const FormatException(
        'Check the group name, description and available members.',
      );
    }
    final group = await _writes.run(
      'create-group',
      () => session.request(
        'POST',
        '/api/v1/chat/groups',
        body: {
          'name': cleanName,
          'desc': description.trim(),
          'member_ids': members,
          'is_pod_channel': pod,
        },
      ),
      accepts: (result) => workspaceText(result['id']).isNotEmpty,
    );
    _channels.add(workspaceText(group['id']));
    return group;
  }

  Future<WorkspaceRecord> publishingDetails(String id) async {
    requireAccess(publishing: true);
    final detail = await session.request(
      'GET',
      '/api/v1/publishing/deliverables/${Uri.encodeComponent(id)}',
    );
    _writes.observe('publishing:$id', detail);
    return detail;
  }

  Future<List<WorkspaceRecord>> publishingHistory(String id) async {
    requireAccess(publishing: true);
    return workspaceRows(
      await session.request(
        'GET',
        '/api/v1/publishing/deliverables/${Uri.encodeComponent(id)}/history',
      ),
    );
  }

  Future<WorkspaceRecord> publishingAction(String id, String action) async {
    requireAccess(publishing: true);
    if (!{
          'pause',
          'resume',
          'cancel',
          'retry',
          'reconcile',
          'publish_now',
          'use_calendar',
        }.contains(action) ||
        ({'retry', 'reconcile'}.contains(action) &&
            !{'admin', 'super_admin'}.contains(role)) ||
        ({'pause', 'publish_now'}.contains(action) &&
            !{'team_lead', 'admin', 'super_admin'}.contains(role))) {
      throw const HttpError(
        status: 403,
        code: 'ACTION_FORBIDDEN',
        message: 'This action is unavailable for your role.',
      );
    }
    final detail = await publishingDetails(id);
    if (detail['can_manage'] != true) {
      throw const HttpError(
        status: 403,
        code: 'ACTION_FORBIDDEN',
        message: 'The server has not permitted this action.',
      );
    }
    return _writes.run(
      'publishing:$id',
      () => session.request(
        'POST',
        '/api/v1/publishing/deliverables/${Uri.encodeComponent(id)}/action',
        body: {'action': action},
      ),
      accepts: (result) =>
          workspaceText(result['id']).isNotEmpty ||
          (action == 'reconcile' &&
              result['status'] == 'reconciliation_queued'),
      confirmedBy: (value) {
        final job = value['job'];
        if (job is! Map) return false;
        return switch (action) {
          'cancel' => job['status'] == 'canceled',
          'pause' => job['status'] == 'paused',
          'resume' || 'retry' => {
            'scheduled',
            'processing',
            'published',
          }.contains(job['status']),
          'publish_now' => {'processing', 'published'}.contains(job['status']),
          'use_calendar' =>
            value['calendar_publish_at'] != null &&
                DateTime.tryParse('${job['scheduled_at']}') ==
                    DateTime.tryParse('${value['calendar_publish_at']}'),
          _ => false,
        };
      },
    );
  }

  Future<WorkspaceRecord> schedule(
    String id, {
    String? localTime,
    String timezone = 'Asia/Kolkata',
    required String caption,
    required String mediaType,
    int? fold,
  }) async {
    requireAccess(publishing: true);
    if (!{'IMAGE', 'REELS', 'STORIES'}.contains(mediaType) ||
        caption.length > 2200 ||
        (fold != null && fold != 0 && fold != 1) ||
        timezone.trim().isEmpty) {
      throw const FormatException(
        'Check the format, caption, timezone and daylight-saving choice.',
      );
    }
    final detail = await publishingDetails(id);
    if (detail['can_manage'] != true) {
      throw const HttpError(
        status: 403,
        code: 'ACTION_FORBIDDEN',
        message: 'The server has not permitted scheduling.',
      );
    }
    return _writes.run(
      'publishing:$id',
      () => session.request(
        'POST',
        '/api/v1/deliverables/${Uri.encodeComponent(id)}/schedule',
        body: {
          if (localTime != null) 'local_time': localTime,
          'timezone': timezone.trim(),
          'fold': fold,
          'caption': mediaType == 'STORIES' ? '' : caption,
          'media_type': mediaType,
        },
      ),
      accepts: (result) =>
          workspaceText(result['id']).isNotEmpty &&
          workspaceText(result['status']).isNotEmpty,
    );
  }

  Future<WorkspaceRecord> planCalendar() async {
    requireAccess(publishing: true);
    if (!{'team_lead', 'admin', 'super_admin'}.contains(role)) {
      throw const HttpError(
        status: 403,
        code: 'ACTION_FORBIDDEN',
        message: 'A lead or administrator must plan calendar posts.',
      );
    }
    return _writes.run(
      'plan-calendar',
      () => session.request(
        'POST',
        '/api/v1/publishing/plan-calendar',
        requestTimeout: const Duration(minutes: 2),
      ),
      accepts: (result) => result['planned'] is num && result['skipped'] is num,
    );
  }
}
