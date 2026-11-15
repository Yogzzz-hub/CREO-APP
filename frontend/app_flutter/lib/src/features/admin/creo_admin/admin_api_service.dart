import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/auth_session.dart';
import '../../../core/auth_repository.dart' show HttpError;
import 'data.dart';

AdminApiService? currentAdminApi;

class AdminApiService {
  AdminApiService(this.session)
    : accountId = session.current?.user.id ?? '',
      _generation = session.beginReadGeneration;
  final AuthSession session;
  final String accountId;
  final int _generation;

  bool _loading = false;
  bool get isLoading => _loading;

  String? _error;
  String? get error => _error;

  Map<String, dynamic>? liveDashboard;
  Map<String, dynamic>? settings;
  bool settingsLoaded = false;
  List<Map<String, dynamic>> team = [];
  List<Map<String, dynamic>> sales = [];
  List<Map<String, dynamic>> freelancers = [];
  List<Map<String, dynamic>> supportTickets = [];
  List<Map<String, dynamic>> leaveRequests = [];
  List<Map<String, dynamic>> transactions = [];
  final Set<String> _writes = {};
  final Set<String> _uncertainWrites = {};

  bool get _sameAccount =>
      accountId.isNotEmpty &&
      session.current?.user.id == accountId &&
      session.isCurrent(_generation) &&
      session.phase == SessionPhase.authenticated;

  bool get connected => true;

  static Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  Future<dynamic> _writeOnce(
    String key,
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (!_sameAccount)
      throw StateError(
        'The signed-in account changed. Reopen the admin workspace.',
      );
    if (_uncertainWrites.contains(key))
      throw StateError('Refresh the affected list before retrying this save.');
    if (!_writes.add(key)) {
      throw StateError('That save is already in progress.');
    }
    try {
      return await session.request(method, path, body: body);
    } on HttpError catch (error) {
      if (error.status == 0 || error.status >= 500) _uncertainWrites.add(key);
      rethrow;
    } finally {
      _writes.remove(key);
    }
  }

  /// Refresh all Admin dashboard modules from real endpoints
  Future<void> refreshAll() async {
    _loading = true;
    _error = null;
    try {
      await Future.wait([
        fetchDashboard(),
        fetchProfile(),
        fetchClients(),
        fetchTickets(),
        fetchSettings(),
        fetchTeam(),
        fetchSales(),
        fetchFreelancers(),
        fetchLeave(),
        fetchTasks(),
        fetchDeliverables(),
        fetchNegotiations(),
        fetchTransactions(),
      ]);
    } catch (e) {
      _error = e.toString();
      debugPrint('Admin refresh error: $e');
    } finally {
      _loading = false;
      changed.value++;
    }
  }

  /// GET /api/v1/admin/dashboard
  Future<void> fetchDashboard() async {
    try {
      final res = await session.request('GET', '/api/v1/admin/dashboard');
      if (!_sameAccount) return;
      {
        liveDashboard = _asMap(res);

        // Parse KPIs
        final kpi = res['kpi_data'] as Map<String, dynamic>?;
        if (kpi != null) {
          final mrrMinor = (kpi['mrr_minor'] as num?)?.toInt() ?? 0;
          serverMrr = mrrMinor ~/ 100;
        }

        save(() {});
      }
    } catch (e) {
      debugPrint('Error fetching admin dashboard: $e');
    }
  }

  static List<dynamic> _asList(dynamic res) {
    if (res is List) return res;
    if (res is Map && res['items'] is List) return res['items'] as List;
    return const [];
  }

  /// GET /api/v1/admin/clients
  Future<void> fetchClients() async {
    try {
      final dynamic res = await session.request('GET', '/api/v1/admin/clients');
      if (!_sameAccount) return;
      final list = _asList(res);
      if (!_sameAccount) return;
      _reconcileCreateKeys(
        'create:client:',
        list.whereType<Map>().map((i) => (i['email'] ?? '').toString()),
      );
      {
        final serverClients = <Client>[];
        for (final raw in list) {
          final item = _asMap(raw);
          final name =
              item['company_name'] as String? ??
              item['full_name'] as String? ??
              'Client';
          final email = item['email'] as String? ?? '';
          final contact = item['full_name'] as String? ?? '';
          final instagram = item['instagram_username'] as String? ?? '';
          final stage =
              (item['derived_onboarding_stage'] as num?)?.toInt() ?? 0;

          final clientId =
              item['client_id']?.toString() ??
              item['id']?.toString() ??
              item['user_id']?.toString();
          // Keep open client details bound to the refreshed server record.
          final c =
              clients
                  .where((row) => clientId != null && row.serverId == clientId)
                  .firstOrNull ??
              Client(name: name);
          c.name = name;
          c.contact = contact;
          c.email = email;
          c.plan = (item['plan_display_name'] ?? item['plan_name'])?.toString();
          c.serverId = clientId;
          c.customFee = num.tryParse('${item['monthly_price'] ?? ''}')?.round();
          // Subscription state is authoritative, independently of onboarding progress.
          c.paid = item.containsKey('subscription_status')
              ? {'active', 'trialing'}.contains(
                  item['subscription_status']?.toString().toLowerCase(),
                )
              : stage >= 3;
          c.instagram = instagram;
          serverClients.add(c);
        }

        save(() {
          clients.clear();
          clients.addAll(serverClients);
        });
      }
    } catch (e) {
      debugPrint('Error fetching admin clients: $e');
    }
  }

  /// GET /api/v1/admin/support/tickets
  Future<void> fetchTickets() async {
    try {
      final dynamic res = await session.request(
        'GET',
        '/api/v1/admin/support/tickets',
      );
      if (!_sameAccount) return;
      final list = _asList(res);
      final serverTickets = <Ticket>[];
      supportTickets = list.whereType<Map>().map(_asMap).toList();
      for (final item in supportTickets) {
        final t = Ticket(
          (item['client'] ?? 'Client').toString(),
          (item['subject'] ?? item['title'] ?? 'Support request').toString(),
          (item['priority'] ?? 'medium').toString().toUpperCase(),
          _asMap(item['assignee'])['full_name']?.toString() ?? '',
        );
        t.serverId = item['id']?.toString();
        final date = DateTime.tryParse((item['created_at'] ?? '').toString());
        if (date != null) t.opened = date.toLocal();
        if ((item['status'] ?? '').toString().toLowerCase() == 'closed')
          t.closedAt = t.opened;
        serverTickets.add(t);
      }
      save(() {
        tickets.clear();
        tickets.addAll(serverTickets);
      });
    } catch (e) {
      debugPrint('Error fetching admin tickets: $e');
    }
  }

  Future<void> fetchSettings() async {
    try {
      settings = _asMap(await session.request('GET', '/api/v1/admin/settings'));
      if (!_sameAccount) return;
      settingsLoaded = true;
      _uncertainWrites.remove('settings');
      changed.value++;
    } catch (e) {
      debugPrint('Admin settings load failed: $e');
    }
  }

  Future<void> fetchProfile() async {
    try {
      final profile = _asMap(await session.request('GET', '/api/v1/users/me'));
      if (!_sameAccount) return;
      me.name = (profile['full_name'] ?? me.name).toString();
      me.email = (profile['email'] ?? me.email).toString();
      me.phone = (profile['phone'] ?? '').toString();
      me.role = (profile['role'] ?? me.role).toString();
      changed.value++;
    } catch (e) {
      debugPrint('Admin profile load failed: $e');
    }
  }

  Future<void> saveSettings(Map<String, dynamic> values) async {
    settings = _asMap(
      await _writeOnce(
        'settings',
        'POST',
        '/api/v1/admin/settings',
        body: values,
      ),
    );
    settings = _asMap(settings?['settings']).isEmpty
        ? {...?settings, ...values}
        : _asMap(settings?['settings']);
    changed.value++;
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
  }) async {
    if (!_writes.add('profile'))
      throw StateError('That save is already in progress.');
    try {
      await session.updateProfile(fullName: name, phone: phone);
    } finally {
      _writes.remove('profile');
    }
    me.name = name;
    me.phone = phone;
    changed.value++;
  }

  Future<void> fetchTeam() async {
    try {
      team = _asList(
        await session.request('GET', '/api/v1/admin/teams'),
      ).whereType<Map>().map(_asMap).toList();
      if (!_sameAccount) return;
      _reconcileCreateKeys(
        'create:staff:',
        team.map((i) => (i['email'] ?? '').toString()),
      );
      save(() {
        people.removeWhere((p) => p.kind == Kind.staff);
        for (final item in team) {
          final fullName = (item['full_name'] ?? item['name'] ?? 'Team member')
              .toString();
          final p = Person(
            fullName,
            (item['email'] ?? '').toString(),
            Kind.staff,
            role: (item['role'] ?? '').toString(),
            pod: (item['team_lead_name'] ?? item['pod_name'] ?? '').toString(),
            skills: item['skills'] is List
                ? (item['skills'] as List).join(', ')
                : '',
          );
          p.serverId = item['id']?.toString();
          p.active =
              (item['account_status'] ?? '').toString().toLowerCase() ==
              'active';
          people.add(p);
        }
      });
    } catch (e) {
      debugPrint('Admin team load failed: $e');
    }
  }

  Future<void> fetchSales() async {
    try {
      sales = _asList(
        await session.request('GET', '/api/v1/admin/bde'),
      ).whereType<Map>().map(_asMap).toList();
      if (!_sameAccount) return;
      _reconcileCreateKeys(
        'create:sales:',
        sales.map((i) => (i['email'] ?? '').toString()),
      );
      save(() {
        people.removeWhere((p) => p.kind == Kind.sales);
        for (final item in sales) {
          final p =
              Person(
                  (item['full_name'] ?? item['name'] ?? '').toString(),
                  (item['email'] ?? '').toString(),
                  Kind.sales,
                  role: (item['designation'] ?? 'Sales').toString(),
                )
                ..quota = (item['monthly_quota'] as num?)?.toInt() ?? 0
                ..commission = (item['commission_rate'] as num?)?.toInt() ?? 0;
          p.serverId = item['id']?.toString();
          p.active = item['is_active'] == true;
          people.add(p);
        }
      });
    } catch (e) {
      debugPrint('Admin sales load failed: $e');
    }
  }

  Future<void> fetchFreelancers() async {
    try {
      freelancers = _asList(
        await session.request('GET', '/api/v1/admin/freelancers'),
      ).whereType<Map>().map(_asMap).toList();
      if (!_sameAccount) return;
      _reconcileCreateKeys(
        'create:freelancer:',
        freelancers.map((i) => (i['email'] ?? '').toString()),
      );
      save(() {
        people.removeWhere((p) => p.kind == Kind.freelancer);
        for (final item in freelancers) {
          final p = Person(
            (item['full_name'] ?? '').toString(),
            (item['email'] ?? '').toString(),
            Kind.freelancer,
            role: (item['specialty'] ?? '').toString(),
            skills: item['skills'] is List
                ? (item['skills'] as List).join(', ')
                : '',
          )..rate = (item['hourly_rate'] as num?)?.toInt() ?? 0;
          p.serverId = item['id']?.toString() ?? item['user_id']?.toString();
          p.active =
              item['is_active'] == true ||
              item['status']?.toString().toUpperCase() == 'ACTIVE';
          people.add(p);
        }
      });
    } catch (e) {
      debugPrint('Admin freelancer load failed: $e');
    }
  }

  Future<void> fetchLeave() async {
    try {
      leaveRequests = _asList(
        await session.request('GET', '/api/v1/admin/leave'),
      ).whereType<Map>().map(_asMap).toList();
      if (!_sameAccount) return;
      final parsed = <Leave>[];
      for (final item in leaveRequests) {
        final start = DateTime.tryParse((item['start_date'] ?? '').toString());
        final end = DateTime.tryParse((item['end_date'] ?? '').toString());
        if (start == null || end == null) continue;
        final status = (item['status'] ?? 'pending').toString();
        final leave =
            Leave(
                (item['employee_name'] ?? item['name'] ?? 'Team member')
                    .toString(),
                start,
                end,
                (item['reason'] ?? '').toString(),
              )
              ..status = status.isEmpty
                  ? 'Pending'
                  : '${status[0].toUpperCase()}${status.substring(1)}'
              ..serverId = item['id']?.toString();
        parsed.add(leave);
      }
      save(() {
        leaves.clear();
        leaves.addAll(parsed);
      });
    } catch (e) {
      debugPrint('Admin leave load failed: $e');
    }
  }

  Future<void> fetchTasks() async {
    try {
      final board = _asMap(
        await session.request('GET', '/api/v1/tasks/kanban'),
      );
      if (!_sameAccount) return;
      final parsed = <Task>[];
      const columns = <String, Stage>{
        'backlog': Stage.todo,
        'in_production': Stage.making,
        'internal_qa': Stage.review,
        'client_review': Stage.review,
        'ready_to_publish': Stage.review,
        'completed': Stage.done,
      };
      for (final entry in columns.entries) {
        for (final raw in _asList(board[entry.key])) {
          if (raw is! Map) continue;
          final item = _asMap(raw);
          final blueprint = _asMap(item['blueprint']);
          final title =
              (blueprint['title'] ??
                      blueprint['concept_name'] ??
                      item['deliverable_type'] ??
                      'Task')
                  .toString();
          final due = (item['due_date'] ?? '').toString();
          final clientId = (item['client_id'] ?? '').toString();
          final signature = '$clientId|$title|$due';
          final task =
              Task(
                  title,
                  (item['client_company'] ?? item['client_name'] ?? 'Client')
                      .toString(),
                  (item['assignee_name'] ?? 'Unassigned').toString(),
                  (item['pod'] ?? '').toString(),
                  (blueprint['priority'] ?? 'Medium').toString(),
                  DateTime.tryParse(due)?.toLocal() ?? DateTime.now(),
                )
                ..serverId = item['id']?.toString()
                ..stage = entry.value;
          parsed.add(task);
          _uncertainWrites.remove('task-create:$signature');
        }
      }
      save(() {
        tasks.clear();
        tasks.addAll(parsed);
      });
    } catch (e) {
      debugPrint('Admin task load failed: $e');
    }
  }

  Future<void> fetchDeliverables() async {
    try {
      final rows = _asList(
        await session.request('GET', '/api/v1/admin/deliverables'),
      );
      if (!_sameAccount) return;
      final parsed = <Deliverable>[];
      for (final raw in rows) {
        if (raw is! Map) continue;
        final item = _asMap(raw);
        final status = (item['status'] ?? '').toString();
        final date =
            DateTime.tryParse(
              (item['scheduled_at'] ?? item['created_at'] ?? '').toString(),
            )?.toLocal() ??
            DateTime.now();
        final draft =
            Deliverable(
                (item['title'] ?? 'Deliverable').toString(),
                (item['client'] ?? 'Client').toString(),
                (item['deliverable_type'] ?? item['type'] ?? 'reel').toString(),
                '',
                date,
              )
              ..serverId = item['id']?.toString()
              ..serverStatus = status;
        draft.state = switch (status) {
          'pending_qa' || 'pending_approval' => Draft.review,
          'qa_rejected' || 'revision_requested' => Draft.revision,
          'approved' || 'scheduled' || 'publishing' => Draft.approved,
          'published' => Draft.published,
          _ => Draft.review,
        };
        if (item['description'] is String &&
            (item['description'] as String).isNotEmpty)
          draft.notes.add(item['description'] as String);
        parsed.add(draft);
      }
      save(() {
        deliverables.clear();
        deliverables.addAll(parsed);
      });
    } catch (e) {
      debugPrint('Admin deliverable load failed: $e');
    }
  }

  Future<void> fetchNegotiations() async {
    try {
      final rows = _asList(
        await session.request('GET', '/api/v1/admin/negotiations'),
      );
      if (!_sameAccount) return;
      final parsed = <Negotiation>[];
      for (final raw in rows) {
        if (raw is! Map) continue;
        final item = _asMap(raw);
        final offer =
            item['counterPrice'] ??
            item['agreedAmount'] ??
            _amountFromOffer(item['proposedOffer']);
        final negotiation = Negotiation(
          (item['clientName'] ?? 'Client').toString(),
          'Current plan',
          (item['targetTopic'] ?? 'Custom plan').toString(),
          (offer as num?)?.toInt() ?? int.tryParse('$offer') ?? 0,
          (item['notes'] ?? '').toString(),
        )..serverId = item['id']?.toString();
        negotiation.status = switch ((item['status'] ?? '')
            .toString()
            .toLowerCase()) {
          'proposal sent' || 'pending' || 'waiting' => 'Waiting',
          'accepted' => 'Accepted',
          'rejected' || 'declined' => 'Rejected',
          'countered' => 'Countered',
          final status => status,
        };
        parsed.add(negotiation);
      }
      save(() {
        negotiations.clear();
        negotiations.addAll(parsed);
      });
    } catch (e) {
      debugPrint('Admin proposals load failed: $e');
    }
  }

  static int? _amountFromOffer(dynamic offer) {
    if (offer is! String) return null;
    return int.tryParse(offer.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  Future<void> fetchTransactions() async {
    try {
      transactions = _asList(
        await session.request('GET', '/api/v1/admin/transactions'),
      ).whereType<Map>().map(_asMap).toList();
      if (!_sameAccount) return;
      final parsed = <Invoice>[];
      for (final item in transactions) {
        final dateText = (item['date'] ?? '').toString();
        final date = DateTime.tryParse(dateText) ?? _transactionDate(dateText);
        if (item['is_paid'] != true || date == null) continue;
        final invoice = Invoice(
          (item['client'] ?? 'Client').toString(),
          (item['scope'] ?? 'Paid transaction').toString(),
          ((item['amount'] as num?) ?? 0).round(),
          (item['method'] ?? 'Unknown').toString(),
          date,
        )..serverId = (item['raw_sub_id'] ?? item['id'])?.toString();
        parsed.add(invoice);
      }
      save(() {
        invoices.clear();
        invoices.addAll(parsed);
      });
    } catch (e) {
      debugPrint('Admin transaction load failed: $e');
    }
  }

  static DateTime? _transactionDate(String value) {
    final match = RegExp(
      r'^([A-Za-z]{3}) (\d{1,2}), (\d{4})$',
    ).firstMatch(value);
    if (match == null) return null;
    const months = <String, int>{
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    final month = months[match.group(1)];
    final day = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (month == null || day == null || year == null) return null;
    return DateTime(year, month, day);
  }

  void _reconcileCreateKeys(String prefix, Iterable<String> emails) {
    final present = emails.map((e) => e.toLowerCase()).toSet();
    _uncertainWrites.removeWhere(
      (key) =>
          key.startsWith(prefix) &&
          !present.contains(key.substring(prefix.length).toLowerCase()),
    );
  }

  Future<void> createLeave(Map<String, dynamic> body) async {
    await _writeOnce(
      'leave-create:${body['start_date']}',
      'POST',
      '/api/v1/admin/leave',
      body: body,
    );
    await fetchLeave();
  }

  Future<Map<String, dynamic>> createStaff(Map<String, dynamic> body) async {
    final email = (body['email'] ?? '').toString().toLowerCase();
    if (team.any((r) => (r['email'] ?? '').toString().toLowerCase() == email))
      throw StateError('This email already appears in the team roster.');
    return _asMap(
      await _writeOnce(
        'create:staff:$email',
        'POST',
        '/api/v1/admin/teams',
        body: body,
      ),
    );
  }

  Future<Map<String, dynamic>> createSales(Map<String, dynamic> body) async {
    final email = (body['email'] ?? '').toString().toLowerCase();
    if (sales.any((r) => (r['email'] ?? '').toString().toLowerCase() == email))
      throw StateError('This email already appears in sales.');
    return _asMap(
      await _writeOnce(
        'create:sales:$email',
        'POST',
        '/api/v1/admin/bde/onboard',
        body: body,
      ),
    );
  }

  Future<Map<String, dynamic>> createFreelancer(
    Map<String, dynamic> body,
  ) async {
    final email = (body['email'] ?? '').toString().toLowerCase();
    if (freelancers.any(
      (r) => (r['email'] ?? '').toString().toLowerCase() == email,
    ))
      throw StateError('This email already appears in freelancers.');
    return _asMap(
      await _writeOnce(
        'create:freelancer:$email',
        'POST',
        '/api/v1/admin/freelancers',
        body: body,
      ),
    );
  }

  Future<Map<String, dynamic>> createClient(Map<String, dynamic> body) async {
    final email = (body['email'] ?? '').toString().toLowerCase();
    if (clients.any((r) => r.email.toLowerCase() == email))
      throw StateError('This email already appears in clients.');
    return _asMap(
      await _writeOnce(
        'create:client:$email',
        'POST',
        '/api/v1/admin/clients/onboard',
        body: body,
      ),
    );
  }

  Future<void> createTicket(Map<String, dynamic> body) async {
    await _writeOnce(
      'ticket:${body['title']}',
      'POST',
      '/api/v1/tickets',
      body: body,
    );
    await fetchTickets();
  }

  Future<void> replyTicket(String id, String message) async {
    await _writeOnce(
      'ticket-reply:$id',
      'POST',
      '/api/v1/admin/support/tickets/$id/messages',
      body: {'message_text': message},
    );
    await fetchTickets();
  }

  Future<void> fetchTicketMessages(String id, Ticket ticket) async {
    final rows = _asList(
      await session.request(
        'GET',
        '/api/v1/admin/support/tickets/$id/messages',
      ),
    );
    final messages = rows.whereType<Map>().map(_asMap).toList();
    save(() {
      ticket.replies
        ..clear()
        ..addAll(
          messages.map((m) {
            final msg = Msg(
              (m['sender_name'] ?? 'Team member').toString(),
              (m['message'] ?? '').toString(),
            );
            msg.at =
                DateTime.tryParse(
                  (m['created_at'] ?? '').toString(),
                )?.toLocal() ??
                msg.at;
            return msg;
          }),
        );
    });
  }

  Future<void> updateTicketStatus(String id, String status) async {
    await _writeOnce(
      'ticket-status:$id',
      'PATCH',
      '/api/v1/admin/support/tickets/$id/status',
      body: {'status': status},
    );
    await fetchTickets();
  }

  Future<void> updateLeave(String id, bool approve) async {
    await _writeOnce(
      'leave:$id',
      'POST',
      '/api/v1/admin/leave/$id/${approve ? 'approve' : 'reject'}',
    );
    await fetchLeave();
  }

  Future<Map<String, dynamic>> createTask(Map<String, dynamic> body) async {
    final signature =
        '${body['client_id']}|${body['title']}|${body['due_date']}';
    final result = _asMap(
      await _writeOnce(
        'task-create:$signature',
        'POST',
        '/api/v1/tasks',
        body: body,
      ),
    );
    await fetchTasks();
    return result;
  }

  Future<Map<String, dynamic>> createFreelancerTask(
    String freelancerId,
    Map<String, dynamic> body,
  ) async {
    final result = _asMap(
      await _writeOnce(
        'freelance-task:${body['client_id']}|${body['task_title']}|${body['due_date']}',
        'POST',
        '/api/v1/admin/freelancers/$freelancerId/assign',
        body: body,
      ),
    );
    await fetchTasks();
    return result;
  }

  Future<void> moveTask(String id, String status) async {
    await _writeOnce(
      'task-move:$id:$status',
      'PATCH',
      '/api/v1/tasks/$id/move',
      body: {'to_status': status},
    );
    await fetchTasks();
  }

  Future<void> updateDeliverableStatus(
    String id,
    String status, {
    String reason = '',
  }) async {
    await _writeOnce(
      'deliverable:$id:$status',
      'PATCH',
      '/api/v1/admin/deliverables/$id/status',
      body: {'status': status, 'reason': reason},
    );
    await fetchDeliverables();
  }

  Future<void> withdrawDeliverable(String id, String reason) async {
    await _writeOnce(
      'deliverable-withdraw:$id',
      'POST',
      '/api/v1/deliverables/$id/withdraw',
      body: {'reason': reason},
    );
    await fetchDeliverables();
  }

  Future<Map<String, dynamic>> createNegotiation(
    Map<String, dynamic> body,
  ) async {
    final result = _asMap(
      await _writeOnce(
        'negotiation-create:${body['client_id']}:${body['target_topic']}',
        'POST',
        '/api/v1/admin/negotiations',
        body: body,
      ),
    );
    await fetchNegotiations();
    return result;
  }

  Future<void> actionNegotiation(String id, Map<String, dynamic> body) async {
    await _writeOnce(
      'negotiation:$id:${body['action']}',
      'PATCH',
      '/api/v1/admin/negotiations/$id',
      body: body,
    );
    await fetchNegotiations();
  }

  Future<void> offboardClient(String id) async {
    if (!clients.any((client) => client.serverId == id)) {
      throw StateError('Refresh and choose a current client.');
    }
    final result = _asMap(
      await _writeOnce(
        'offboard:$id',
        'POST',
        '/api/v1/admin/clients/${Uri.encodeComponent(id)}/offboard',
      ),
    );
    if (result['status'] != 'offboarded' || result['client_id'] != id) {
      _uncertainWrites.add('offboard:$id');
      throw StateError(
        'Offboarding could not be confirmed. Verify the client status before retrying.',
      );
    }
    await fetchClients();
  }

  final _accessPlans = <String, Set<String>>{};
  final _confirmedActivations = <String>{};

  void _requireAccessAdmin() {
    if (!_sameAccount ||
        !{
          'admin',
          'super_admin',
        }.contains(session.current?.user.role.toLowerCase())) {
      throw StateError(
        'Sign in as an administrator to manage client activation.',
      );
    }
  }

  Future<(Map<String, dynamic>, List<Map<String, dynamic>>)> clientAccess(
    String clientId,
  ) async {
    _requireAccessAdmin();
    final id = Uri.encodeComponent(clientId);
    final result = await Future.wait<dynamic>([
      session.request('GET', '/api/v1/admin/clients/$id'),
      session.request('GET', '/api/v1/payments/plans?client_id=$id'),
    ]);
    _requireAccessAdmin();
    final detail = _asMap(result[0]);
    if ((detail['client_id'] ?? detail['id'])?.toString() != clientId) {
      throw StateError(
        'The server returned another client. Refresh the client list.',
      );
    }
    final options = _asList(result[1])
        .whereType<Map>()
        .map(_asMap)
        .where((row) => (row['id']?.toString() ?? '').isNotEmpty)
        .toList();
    _accessPlans[clientId] = options.map((row) => row['id'].toString()).toSet();
    return (detail, options);
  }

  Future<void> activateClient(
    String clientId,
    String planId,
    String paymentMethod,
    String notes,
  ) async {
    _requireAccessAdmin();
    if (_accessPlans[clientId]?.contains(planId) != true ||
        notes.trim().isEmpty ||
        !{
          'upi',
          'bank_transfer',
          'cash',
          'test_access',
        }.contains(paymentMethod)) {
      throw StateError(
        'Load this client and select a server plan, activation method and notes.',
      );
    }
    final key = 'client-activation:$clientId';
    if (_confirmedActivations.contains(clientId)) {
      throw StateError(
        'Activation was already confirmed. Refresh client status.',
      );
    }
    final result = _asMap(
      await _writeOnce(
        key,
        'POST',
        '/api/v1/admin/clients/${Uri.encodeComponent(clientId)}/bypass-payment',
        body: {
          'plan_id': planId,
          'payment_method': paymentMethod,
          'notes': notes.trim(),
        },
      ),
    );
    _requireAccessAdmin();
    if (result['status'] != 'success' ||
        result['client_id'] != clientId ||
        (result['subscription_id']?.toString() ?? '').isEmpty) {
      _uncertainWrites.add(key);
      throw StateError(
        'Activation could not be confirmed. Check server status before retrying.',
      );
    }
    _confirmedActivations.add(clientId);
    await fetchClients();
  }
}
