import '../../core/auth_repository.dart';
import '../../core/auth_session.dart';

class WorkstationNotification {
  const WorkstationNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    this.link,
    this.createdAt,
  });
  final String id, title, message;
  final bool isRead;
  final String? link;
  final DateTime? createdAt;

  factory WorkstationNotification.fromJson(Map<String, dynamic> json) {
    final id = json['id'], title = json['title'], message = json['message'];
    final read = json['is_read'],
        link = json['link'],
        created = json['created_at'];
    if (id is! String ||
        id.trim().isEmpty ||
        title is! String ||
        message is! String ||
        read is! bool ||
        (link != null && link is! String) ||
        (created != null && created is! String)) {
      throw const FormatException(
        'Invalid notification. Refresh and try again.',
      );
    }
    final date = created == null || created == ''
        ? null
        : DateTime.tryParse(created as String);
    if (created != null && created != '' && date == null) {
      throw const FormatException('Invalid notification timestamp.');
    }
    return WorkstationNotification(
      id: id,
      title: title,
      message: message,
      isRead: read,
      link: link as String?,
      createdAt: date,
    );
  }
}

class WorkstationNotifications {
  const WorkstationNotifications({
    required this.items,
    required this.unreadCount,
  });
  final List<WorkstationNotification> items;

  /// This is the server count across the account, not just the latest 20 rows.
  final int unreadCount;
  factory WorkstationNotifications.fromJson(Map<String, dynamic> json) {
    final raw = json['items'], unread = json['unread_count'];
    if (raw is! List || unread is! int || unread < 0) {
      throw const FormatException(
        'Invalid notification list. Refresh and try again.',
      );
    }
    final rows = raw
        .map((row) {
          if (row is! Map<String, dynamic>) {
            throw const FormatException('Invalid notification item.');
          }
          return WorkstationNotification.fromJson(row);
        })
        .toList(growable: false);
    if (rows.map((row) => row.id).toSet().length != rows.length) {
      throw const FormatException('Duplicate notification identifiers.');
    }
    return WorkstationNotifications(
      items: List.unmodifiable(rows),
      unreadCount: unread,
    );
  }
}

/// Resolve only source-confirmed workspace destinations. A notification is data,
/// never authority to open arbitrary URLs or administrative routes.
String? notificationWorkspacePath(String? raw, String role) {
  if (raw == null ||
      raw.isEmpty ||
      !raw.startsWith('/') ||
      raw.startsWith('//') ||
      raw.contains('\\') ||
      RegExp(r'[\x00-\x20]').hasMatch(raw) ||
      raw.contains('..')) {
    return null;
  }
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.hasScheme || uri.hasAuthority || uri.hasFragment) {
    return null;
  }
  final freelancer = role == 'freelancer';
  if (!freelancer && role != 'editor' && role != 'designer') return null;
  final path = uri.path.length > 1 && uri.path.endsWith('/')
      ? uri.path.substring(0, uri.path.length - 1)
      : uri.path;
  String? target;
  if (const {
    '/admin/leave',
    '/admin/leaves',
    '/leave',
    '/leaves',
  }.contains(path)) {
    target = freelancer ? '/freelancer/leave' : '/workstation/schedule';
  } else if (const {
    '/slack',
    '/admin/slack',
    '/workstation/slack',
    '/workstation/chat',
    '/member/chat',
    '/member/slack',
  }.contains(path)) {
    target = freelancer ? '/slack' : '/workstation/slack';
  } else if (freelancer) {
    target = switch (path) {
      '/freelancer' || '/freelancer/tasks' => '/freelancer/tasks',
      '/freelancer/leave' => '/freelancer/leave',
      '/freelancer/settings' => '/freelancer/settings',
      _ => null,
    };
  } else {
    target = switch (path) {
      '/workstation' ||
      '/workstation/overview' ||
      '/member' ||
      '/member/overview' => '/workstation',
      '/workstation/tasks' ||
      '/member/tasks' ||
      '/workstation/handoff' ||
      '/member/handoff' => '/workstation/tasks',
      '/workstation/schedule' ||
      '/workstation/leave' ||
      '/member/schedule' ||
      '/member/leave' => '/workstation/schedule',
      '/workstation/settings' || '/member/settings' => '/workstation/settings',
      '/admin/publishing' ||
      '/workstation/publishing' ||
      '/member/publishing' => '/admin/publishing',
      _ => null,
    };
  }
  if (target == null) return null;
  final query = <String, String>{};
  final safeIdentifier = RegExp(r'^[a-zA-Z0-9_-]{1,128}$');
  if (target.endsWith('/tasks')) {
    final id = uri.queryParameters['taskId'] ?? uri.queryParameters['selected'];
    if (id != null && safeIdentifier.hasMatch(id)) query['taskId'] = id;
  }
  if (target == '/slack' || target == '/workstation/slack') {
    for (final key in ['dm', 'channel']) {
      final id = uri.queryParameters[key];
      if (id != null && safeIdentifier.hasMatch(id)) query[key] = id;
    }
  }
  return Uri(
    path: target,
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}

class _NotificationWrite {
  _NotificationWrite(this.operation, this.id);
  final String operation;
  final String? id;
  bool uncertain = false;
  bool confirmedBy(WorkstationNotifications data) => switch (operation) {
    'read' => data.items.any((row) => row.id == id && row.isRead),
    // With fewer than 20 rows the server returned the complete current set.
    'delete' =>
      data.items.length < 20 && !data.items.any((row) => row.id == id),
    'all_read' => data.unreadCount == 0,
    'all_deleted' => data.items.isEmpty && data.unreadCount == 0,
    _ => false,
  };
}

class _NotificationWrites {
  _NotificationWrites(this.generation);
  static final owners = Expando<_NotificationWrites>();
  int generation;
  _NotificationWrite? current;
  static _NotificationWrites forSession(AuthSession session) {
    final existing = owners[session];
    if (existing != null) return existing;
    final state = _NotificationWrites(session.beginReadGeneration);
    session.addListener(() {
      if (session.phase == SessionPhase.clearing ||
          session.phase == SessionPhase.signedOut ||
          state.generation != session.beginReadGeneration) {
        state.current = null;
        state.generation = session.beginReadGeneration;
      }
    });
    owners[session] = state;
    return state;
  }
}

class WorkstationNotificationsRepository {
  WorkstationNotificationsRepository(this.session)
    : _account = session.current?.user.id,
      _generation = session.beginReadGeneration;
  final AuthSession session;
  final String? _account;
  final int _generation;
  WorkstationNotifications? _snapshot;
  late final _writes = _NotificationWrites.forSession(session);
  bool get mutationBlocked => _writes.current != null;
  bool get mutationUnconfirmed => _writes.current?.uncertain == true;
  void _requireAccess() {
    final user = session.current?.user;
    if (session.phase != SessionPhase.authenticated ||
        !session.isCurrent(_generation) ||
        user == null ||
        user.id != _account ||
        user.mustResetPassword == true ||
        !const {'editor', 'designer', 'freelancer'}.contains(user.role)) {
      _snapshot = null;
      throw const HttpError(
        status: 403,
        code: 'NOTIFICATIONS_FORBIDDEN',
        message:
            'Sign in with an eligible workspace account to view notifications.',
      );
    }
  }

  Future<WorkstationNotifications> load() async {
    _requireAccess();
    final json = await session.request('GET', '/api/v1/notifications');
    _requireAccess();
    final next = WorkstationNotifications.fromJson(json);
    final pending = _writes.current;
    if (pending?.uncertain == true && pending!.confirmedBy(next)) {
      _writes.current = null;
    }
    _snapshot = next;
    return next;
  }

  void _known(String id) {
    if (_snapshot?.items.any((row) => row.id == id) != true) {
      throw const HttpError(
        status: 403,
        code: 'NOTIFICATION_UNAVAILABLE',
        message:
            'Refresh notifications and choose an item returned for your account.',
      );
    }
  }

  Future<WorkstationNotifications> markRead(String id) async {
    _requireAccess();
    _known(id);
    return _mutate(
      'read',
      'PATCH',
      '/api/v1/notifications/${Uri.encodeComponent(id)}/read',
      id: id,
    );
  }

  Future<WorkstationNotifications> delete(String id) async {
    _requireAccess();
    _known(id);
    return _mutate(
      'deleted',
      'DELETE',
      '/api/v1/notifications/${Uri.encodeComponent(id)}',
      id: id,
    );
  }

  Future<WorkstationNotifications> markAllRead() =>
      _mutate('all_read', 'POST', '/api/v1/notifications/mark-all-read');
  Future<WorkstationNotifications> clearAll() =>
      _mutate('all_deleted', 'DELETE', '/api/v1/notifications');

  Future<WorkstationNotifications> _mutate(
    String operation,
    String method,
    String path, {
    String? id,
  }) async {
    _requireAccess();
    if (_snapshot == null) {
      throw const FormatException(
        'Load notifications before taking an action.',
      );
    }
    if (_writes.current != null) {
      throw const HttpError(
        status: 0,
        code: 'NOTIFICATION_WRITE_UNCONFIRMED',
        message:
            'The previous notification request is pending or unconfirmed. Refresh to check its server state before another action.',
      );
    }
    final pending = _NotificationWrite(
      operation == 'deleted' ? 'delete' : operation,
      id,
    );
    _writes.current = pending;
    try {
      final result = await session.request(method, path);
      _requireAccess();
      if (result['status'] != operation ||
          (id != null && result['id'] != id) ||
          (operation == 'all_read' && result['updated'] is! num) ||
          (operation == 'all_deleted' && result['deleted'] is! num)) {
        throw const FormatException(
          'The notification action response could not be verified.',
        );
      }
      if (identical(_writes.current, pending)) _writes.current = null;
    } catch (error) {
      if (identical(_writes.current, pending)) {
        if (error is FormatException ||
            (error is HttpError &&
                (error.status >= 500 ||
                    const {
                      'TIMEOUT',
                      'NETWORK_ERROR',
                      'INVALID_RESPONSE',
                    }.contains(error.code)))) {
          pending.uncertain = true;
          throw const HttpError(
            status: 0,
            code: 'NOTIFICATION_WRITE_UNCONFIRMED',
            message:
                'The action outcome is unconfirmed. Notifications have been retained. Refresh to check the server state; the action will not be replayed.',
          );
        }
        _writes.current = null;
      }
      rethrow;
    }
    return load();
  }
}
