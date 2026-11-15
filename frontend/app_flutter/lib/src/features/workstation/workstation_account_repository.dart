import '../../core/auth_repository.dart';
import '../../core/auth_session.dart';
import 'workstation_data.dart';

/// Account-scoped contracts shared by the React member and freelancer pages.
/// Server flags, not the local role label, control cancellation permissions.
class WorkspaceLeave {
  const WorkspaceLeave({
    required this.id,
    required this.start,
    required this.end,
    required this.reason,
    required this.status,
    required this.isSelf,
    required this.canCancel,
    required this.reviewer,
  });
  final String id, start, end, reason, status, reviewer;
  final bool isSelf, canCancel;
  int get days =>
      DateTime.parse(end).difference(DateTime.parse(start)).inDays + 1;

  factory WorkspaceLeave.fromJson(Map<String, dynamic> json) {
    final start = json['start_date'], end = json['end_date'];
    if (json['id'] is! String ||
        start is! String ||
        end is! String ||
        DateTime.tryParse(start) == null ||
        DateTime.tryParse(end) == null ||
        DateTime.parse(end).isBefore(DateTime.parse(start)) ||
        json['reason'] is! String ||
        json['status'] is! String) {
      throw const FormatException('Invalid leave response');
    }
    return WorkspaceLeave(
      id: json['id'],
      start: start,
      end: end,
      reason: json['reason'],
      status: json['status'],
      isSelf: json['is_self'] == true,
      canCancel: json['can_cancel'] == true,
      reviewer: json['team_lead_name'] as String? ?? 'Not assigned',
    );
  }
}

class WorkspaceProfile {
  const WorkspaceProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
  });
  final String id, name, email, phone, role;
  factory WorkspaceProfile.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! String ||
        json['full_name'] is! String ||
        json['email'] is! String ||
        json['role'] is! String ||
        (json['phone'] != null && json['phone'] is! String)) {
      throw const FormatException('Invalid profile response');
    }
    return WorkspaceProfile(
      id: json['id'],
      name: json['full_name'],
      email: json['email'],
      phone: json['phone'] as String? ?? '',
      role: json['role'],
    );
  }
}

class WorkstationAccountRepository {
  WorkstationAccountRepository(this.session, {required this.freelancer})
    : _userId = session.current?.user.id,
      _role = session.current?.user.role,
      _generation = session.beginReadGeneration;
  final AuthSession session;
  final bool freelancer;
  final String? _userId, _role;
  final int _generation;

  void _check() {
    final user = session.current?.user;
    if (session.phase != SessionPhase.authenticated ||
        user == null ||
        !session.isCurrent(_generation) ||
        user.id != _userId ||
        user.role != _role ||
        user.mustResetPassword == true ||
        (freelancer
            ? user.role != 'freelancer'
            : !['editor', 'designer', 'team_lead'].contains(user.role))) {
      throw const HttpError(
        status: 403,
        code: 'FORBIDDEN',
        message: 'This workspace is no longer available for this account.',
      );
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    _check();
    final result = await session.request(method, path, body: body);
    _check();
    return result;
  }

  Future<List<WorkspaceLeave>> leaves() async {
    final response = await _request('GET', '/api/v1/admin/leave');
    final rows = response['items'];
    if (rows is! List) throw const FormatException('Invalid leave list');
    return rows
        .map((r) => WorkspaceLeave.fromJson(r as Map<String, dynamic>))
        .where((r) => r.isSelf)
        .toList(growable: false);
  }

  static String? validateLeave(
    String start,
    String end,
    String reason,
    DateTime now,
  ) {
    final first = DateTime.tryParse(start), last = DateTime.tryParse(end);
    if (first == null || last == null) return 'Choose a start and end date.';
    final today = DateTime.utc(
      now.toUtc().year,
      now.toUtc().month,
      now.toUtc().day,
    );
    if (DateTime.utc(first.year, first.month, first.day).isBefore(today)) {
      return 'Start date cannot be in the past.';
    }
    if (last.isBefore(first)) {
      return 'End date must be on or after the start date.';
    }
    if (reason.trim().isEmpty) return 'Enter a reason and handover notes.';
    return null;
  }

  Future<void> requestLeave(
    String start,
    String end,
    String reason, {
    String category = 'Planned Holiday / Break',
    DateTime? now,
  }) async {
    final error = validateLeave(start, end, reason, now ?? DateTime.now());
    if (error != null) throw ArgumentError(error);
    await _request(
      'POST',
      '/api/v1/admin/leave',
      body: {
        'start_date': start,
        'end_date': end,
        'reason': freelancer
            ? '[Freelancer Blackout: $category] ${reason.trim()}'
            : reason.trim(),
      },
    );
  }

  Future<void> cancelLeave(WorkspaceLeave leave) async {
    if (!leave.isSelf || !leave.canCancel) {
      throw const HttpError(
        status: 403,
        code: 'FORBIDDEN',
        message: 'This request cannot be cancelled.',
      );
    }
    await _request(
      'DELETE',
      '/api/v1/admin/leave/${Uri.encodeComponent(leave.id)}',
    );
  }

  Future<WorkspaceProfile> profile() async {
    final profile = WorkspaceProfile.fromJson(
      await _request('GET', '/api/v1/users/me'),
    );
    if (profile.id != _userId) throw const FormatException('Account changed');
    return profile;
  }

  Future<WorkspaceProfile> saveProfile(String name, String phone) async {
    if (name.trim().isEmpty) throw ArgumentError('Name cannot be empty.');
    _check();
    final user = await session.updateProfile(
      fullName: name.trim(),
      phone: phone.trim(),
    );
    _check();
    if (user.id != _userId) throw const FormatException('Account changed');
    return WorkspaceProfile(
      id: user.id,
      name: user.fullName,
      email: user.email,
      role: user.role,
      phone: phone.trim(),
    );
  }

  Future<WorkstationData> pod() async {
    if (freelancer) {
      throw StateError('Freelancers do not use the staff pod dashboard');
    }
    return WorkstationData.fromJson(
      await _request('GET', '/api/v1/admin/pod-dashboard'),
    );
  }
}
