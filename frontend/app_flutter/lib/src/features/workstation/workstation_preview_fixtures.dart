import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/auth_repository.dart';
import '../../core/auth_session.dart';
import '../../core/session_store.dart';

/// Deterministic development data. This library is imported only by the separate
/// debug journey entrypoint, never by production main.dart.
class PreviewAssignment {
  PreviewAssignment(this.id, this.title, this.format, this.status, {this.fee});
  final String id, title, format;
  String status;
  final num? fee;
  final List<Map<String, dynamic>> deliveries = [];

  Map<String, dynamic> json(String userId) => {
    'id': id,
    'title': title,
    'client_id': 'sample-brand',
    'client_name': 'Sample Studio',
    'assigned_to': userId,
    'assignee': {'id': userId},
    'deliverable_type': format,
    'format': format,
    'status': status,
    'created_at': '2026-11-08T09:00:00Z',
    'due_date': '2026-11-12',
    'sla_due_at': '2026-11-12T10:00:00Z',
    'milestone_fee': fee,
    'is_revision': status == 'revision_requested',
    'is_near_sla': false,
    'hours_remaining': 48,
    'blueprint': {
      'title': title,
      'concept_name': title,
      'instructions':
          'Sample brief: open with the product story, keep the brand lockup inside the safe area, and end on a clear call to action.',
      'hook': 'A small idea. A memorable first impression.',
      'audio_notes': 'Keep dialogue clear and music below the voice track.',
      'target_duration': '30–45s',
    },
    'deliverable': deliveries.isEmpty ? null : deliveries.last,
    'deliverables': deliveries,
  };
}

class PreviewSessionStore implements SessionStore {
  PreviewSessionStore(this.value);
  StoredSession? value;
  @override
  Future<StoredSession?> read() async => value;
  @override
  Future<void> write(StoredSession? session) async => value = session;
}

class WorkstationPreviewFixtures extends http.BaseClient {
  WorkstationPreviewFixtures({this.role = 'editor'}) {
    if (!kDebugMode || !const ['editor', 'freelancer'].contains(role)) {
      throw StateError(
        'This fixture transport is available only for a debug editor/freelancer preview.',
      );
    }
    for (final task in assignments.where(
      (task) => [
        'internal_qa',
        'revision_requested',
        'completed',
      ].contains(task.status),
    )) {
      final id = 'sample-delivery-${task.id}';
      task.deliveries.add({
        'id': id,
        'version': 1,
        'status': task.status == 'revision_requested'
            ? 'qa_rejected'
            : task.status == 'completed'
            ? 'approved'
            : 'pending_qa',
        'file_url': null,
        'rejection_comment': task.status == 'revision_requested'
            ? 'Sample QA feedback: keep the opening title inside the safe area and reduce music under the voice.'
            : null,
        'created_at': '2026-11-09T09:00:00Z',
      });
      history[id] = [
        {
          'id': 'sample-history-${task.id}',
          'version': 1,
          'action': task.status == 'revision_requested'
              ? 'qa_rejected'
              : 'submitted',
          'action_label': task.status == 'revision_requested'
              ? 'Sample QA changes requested'
              : 'Sample submission for QA',
          'actor_name': 'Sample Pod Lead',
          'reason': 'Sample audit trail. This is demonstration content.',
          'created_at': '2026-11-09T09:00:00Z',
        },
      ];
    }
  }

  final String role;
  final assignments = [
    PreviewAssignment(
      'sample-assigned',
      'Autumn launch · First cut',
      'reel',
      'backlog',
      fee: 3200,
    ),
    PreviewAssignment(
      'sample-production',
      'Behind the brand · Story edit',
      'story',
      'in_production',
      fee: 1800,
    ),
    PreviewAssignment(
      'sample-qa',
      'Product spotlight · QA review',
      'reel',
      'internal_qa',
      fee: 2400,
    ),
    PreviewAssignment(
      'sample-revision',
      'Launch story · Revision',
      'reel',
      'revision_requested',
    ),
    PreviewAssignment(
      'sample-review',
      'Studio story · Client review',
      'reel',
      'client_review',
      fee: 2000,
    ),
    PreviewAssignment(
      'sample-ready',
      'Brand story · Ready to publish',
      'reel',
      'ready_to_publish',
      fee: 2500,
    ),
    PreviewAssignment(
      'sample-completed',
      'Product details · Approved edit',
      'reel',
      'completed',
      fee: 1600,
    ),
  ];
  final List<Map<String, dynamic>> leaves = [
    {
      'id': 'sample-leave',
      'start_date': '2026-12-14',
      'end_date': '2026-12-15',
      'reason':
          'Sample planned leave. Handover notes shared with the pod lead.',
      'status': 'pending',
      'is_self': true,
      'can_cancel': true,
      'team_lead_name': 'Sample Pod Lead',
    },
  ];
  final List<Map<String, dynamic>> messages = [
    {
      'id': 'sample-message',
      'sender_id': 'sample-admin',
      'sender_name': 'Sample Admin',
      'message':
          'Welcome to the sample workspace. Messages here stay in memory and never reach a live account.',
      'created_at': '2026-11-09T10:00:00Z',
      'channel': 'sample-pod',
      'recipient_id': 'preview-member',
    },
  ];
  final List<Map<String, dynamic>> notifications = [
    {
      'id': 'sample-notice',
      'title': 'Sample feedback received',
      'message':
          'A sample assignment is ready to review. This notification stays in memory.',
      'is_read': false,
      'created_at': '2026-11-09T10:00:00Z',
    },
  ];
  final Map<String, List<Map<String, dynamic>>> history = {};
  int _serial = 0;
  String name = 'Sample Creative', phone = '';
  String get userId => 'preview-$role';
  Map<String, dynamic> get profile => {
    'id': userId,
    'email': '$role@example.invalid',
    'full_name': name,
    'phone': phone,
    'role': role,
    'account_status': 'active',
    'onboarding_stage': 4,
    'onboarding_status': 'completed',
    'terms_accepted': true,
    'must_reset_password': false,
    'sign_in_methods': ['password'],
  };
  String get token {
    String encode(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    return '${encode({'typ': 'JWT'})}.${encode({'sub': userId, 'exp': 4102444800})}.development-preview-only';
  }

  AuthSession createSession() {
    final store = PreviewSessionStore(
      StoredSession(token, 'preview-refresh-only', userId),
    );
    return AuthSession(
      store: store,
      repository: AuthRepository(
        store: store,
        origin: Uri.parse('https://preview.example.invalid'),
        client: this,
      ),
    );
  }

  Map<String, dynamic> get podDashboard {
    List<Map<String, dynamic>> bucket(String status) => assignments
        .where(
          (task) =>
              task.status == status ||
              (status == 'in_production' &&
                  task.status == 'revision_requested'),
        )
        .map((task) => task.json(userId))
        .toList();
    return {
      'pod': {
        'id': 'sample-pod',
        'name': 'Sample Creative Pod',
        'lead': {'id': 'sample-lead', 'name': 'Sample Pod Lead'},
      },
      'clients': [
        {'id': 'sample-brand', 'name': 'Sample Studio'},
      ],
      'members': [
        {
          'id': userId,
          'full_name': name,
          'role': role,
          'craft_title': 'Sample Creative',
        },
        {
          'id': 'sample-lead',
          'full_name': 'Sample Pod Lead',
          'role': 'team_lead',
          'craft_title': 'Pod Lead',
        },
      ],
      'notifications': [
        {
          'id': 'sample-notice',
          'title': 'Sample feedback received',
          'message':
              'Your latest cut is ready for a review pass. This is demonstration content.',
        },
      ],
      'tasks': {
        for (final status in [
          'backlog',
          'in_production',
          'internal_qa',
          'client_review',
          'ready_to_publish',
          'completed',
        ])
          status: bucket(status),
      },
    };
  }

  Map<String, dynamic> get job => {
    'id': 'sample-job',
    'deliverable_id': 'sample-delivery',
    'title': 'Sample approved brand story',
    'client_name': 'Sample Studio',
    'client_id': 'sample-brand',
    'status': 'scheduled',
    'stage': 'waiting',
    'scheduled_at': '2026-11-15T10:00:00Z',
    'timezone': 'Asia/Kolkata',
    'caption': 'A sample brand story, ready for the next chapter.',
    'media_type': 'REELS',
    'version': 1,
    'approved': true,
  };

  http.StreamedResponse _response(Object body, {int status = 200}) =>
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        status,
        headers: {'content-type': 'application/json'},
      );
  http.StreamedResponse _missing(String message) => _response({
    'error': {'code': 'PREVIEW_NOT_AVAILABLE', 'message': message},
  }, status: 404);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // This transport owns no real HTTP client and has no forwarding fallback.
    if (!kDebugMode ||
        request.url.scheme != 'https' ||
        request.url.host != 'preview.example.invalid' ||
        request.url.userInfo.isNotEmpty ||
        request.url.port != 443) {
      throw http.ClientException(
        'Development preview cannot access live network destinations.',
      );
    }
    final path = request.url.path, method = request.method;
    final body = request is http.Request && request.body.isNotEmpty
        ? jsonDecode(request.body) as Map<String, dynamic>
        : <String, dynamic>{};
    if (path == '/api/v1/auth/me') {
      return _response({...profile, 'access_token': token});
    }
    if (path == '/api/v1/auth/refresh') {
      return _response({'access_token': token});
    }
    if (path == '/api/v1/auth/logout') return _response({'status': 'success'});
    if (path.startsWith('/api/v1/notifications')) {
      if (path == '/api/v1/notifications/mark-all-read' && method == 'POST') {
        final updated = notifications
            .where((item) => item['is_read'] != true)
            .length;
        for (final item in notifications) {
          item['is_read'] = true;
        }
        return _response({'status': 'all_read', 'updated': updated});
      }
      if (path == '/api/v1/notifications' && method == 'DELETE') {
        final deleted = notifications.length;
        notifications.clear();
        return _response({'status': 'all_deleted', 'deleted': deleted});
      }
      if (method == 'PATCH' && path.endsWith('/read')) {
        final id = path.split('/')[4];
        for (final item in notifications.where((item) => item['id'] == id)) {
          item['is_read'] = true;
        }
        return _response({'status': 'read', 'id': id});
      }
      if (method == 'DELETE') {
        final id = path.split('/').last;
        notifications.removeWhere((item) => item['id'] == id);
        return _response({'status': 'deleted', 'id': id});
      }
      return _response({
        'unread_count': notifications
            .where((item) => item['is_read'] != true)
            .length,
        'items': [
          for (final item in notifications)
            {
              ...item,
              'link': role == 'freelancer'
                  ? '/freelancer/tasks'
                  : '/workstation/tasks?taskId=sample-assigned',
            },
        ],
      });
    }
    if (path == '/api/v1/users/me') {
      if (method == 'PATCH') {
        name = body['full_name'] as String? ?? name;
        phone = body['phone'] as String? ?? phone;
      }
      return _response(profile);
    }
    if (path == '/api/v1/admin/pod-dashboard' && method == 'GET') {
      return _response(podDashboard);
    }
    if (path == '/api/v1/admin/freelancer/my-tasks' && method == 'GET') {
      return _response(assignments.map((task) => task.json(userId)).toList());
    }
    if (path == '/api/v1/admin/leave') {
      if (method == 'POST') {
        leaves.add({
          'id': 'sample-leave-${++_serial}',
          ...body,
          'status': 'pending',
          'is_self': true,
          'can_cancel': true,
          'team_lead_name': 'Sample Pod Lead',
        });
        return _response(leaves.last);
      }
      return _response(leaves);
    }
    if (path.startsWith('/api/v1/admin/leave/') && method == 'DELETE') {
      leaves.removeWhere(
        (leave) => leave['id'] == request.url.pathSegments.last,
      );
      return _response({'status': 'cancelled'});
    }
    if (path == '/api/v1/tasks' && method == 'POST') {
      final task = PreviewAssignment(
        'sample-created-${++_serial}',
        '${body['title']}',
        '${body['deliverable_type']}',
        'backlog',
      );
      assignments.add(task);
      return _response(task.json(userId));
    }
    if ((path.startsWith('/api/v1/deliverables/tasks/') &&
            path.endsWith('/start')) ||
        (path.startsWith('/api/v1/admin/freelancer/tasks/') &&
            path.endsWith('/start-work'))) {
      final id = request.url.pathSegments[request.url.pathSegments.length - 2];
      final matches = assignments.where((task) => task.id == id);
      if (matches.isEmpty) return _missing('Sample task not found.');
      matches.single.status = 'in_production';
      return _response({'status': 'in_production', 'task_id': id});
    }
    if (path == '/api/v1/admin/freelancer/submit-work' && method == 'POST') {
      final matches = assignments.where((task) => task.id == body['task_id']);
      if (matches.isEmpty) return _missing('Sample task not found.');
      final task = matches.single;
      final id = 'sample-delivery-${++_serial}',
          version = task.deliveries.length + 1;
      task.deliveries.add({
        'id': id,
        'version': version,
        'file_url': null,
        'status': 'pending_qa',
        'created_at': '2026-11-09T10:00:00Z',
      });
      task.status = 'internal_qa';
      history[id] = [
        {
          'id': 'sample-history-$_serial',
          'version': version,
          'action': 'submitted',
          'action_label': 'Sample submission',
          'actor_name': name,
          'reason':
              body['submission_notes'] ??
              'Preview cloud link submitted in memory only.',
          'created_at': '2026-11-09T10:00:00Z',
        },
      ];
      return _response({
        'status': 'success',
        'message': 'Sample submission recorded in memory.',
        'deliverable_id': id,
        'version': version,
      });
    }
    if (path.startsWith('/api/v1/deliverables/') && path.endsWith('/history')) {
      return _response(history[request.url.pathSegments[3]] ?? []);
    }
    if (path == '/api/v1/chat/contacts') {
      return _response([
        {
          'id': 'sample-admin',
          'name': 'Sample Admin',
          'email': 'admin@example.invalid',
          'role': 'admin',
          'is_super_admin': false,
        },
      ]);
    }
    if (path == '/api/v1/chat/channels') {
      return _response(
        role == 'freelancer'
            ? []
            : [
                {
                  'id': 'sample-pod',
                  'name': 'sample-creative-pod',
                  'label': 'Sample Creative Pod',
                  'desc': 'Sample team discussion',
                  'is_pod_channel': true,
                  'unread_count': 1,
                },
              ],
      );
    }
    if (path == '/api/v1/chat/messages') {
      if (method == 'POST') {
        final message = {
          'id': 'sample-message-${++_serial}',
          ...body,
          'sender_id': userId,
          'sender_name': name,
          'created_at': '2026-11-09T10:01:00Z',
        };
        messages.add(message);
        return _response(message);
      }
      return _response(messages);
    }
    if (path == '/api/v1/admin/clients') {
      return _response([
        {'client_id': 'sample-brand', 'company_name': 'Sample Studio'},
      ]);
    }
    if (path == '/api/v1/publishing/jobs') {
      return _response(
        request.url.queryParameters['offset'] == '0' ||
                request.url.queryParameters['offset'] == null
            ? [job]
            : [],
      );
    }
    if (path == '/api/v1/publishing/deliverables/sample-delivery') {
      return _response({
        'deliverable_id': 'sample-delivery',
        'job': job,
        'can_manage': false,
        'timezone': 'Asia/Kolkata',
        'file_type': 'video/mp4',
      });
    }
    if (path == '/api/v1/publishing/deliverables/sample-delivery/history') {
      return _response([
        {
          'id': 'sample-publishing-history',
          'action': 'scheduled',
          'status': 'scheduled',
          'created_at': '2026-11-09T10:00:00Z',
          'message': 'Sample scheduling history. Nothing was published.',
        },
      ]);
    }
    return _missing(
      'This action is not provided by the isolated development fixture. No live request was sent.',
    );
  }
}
