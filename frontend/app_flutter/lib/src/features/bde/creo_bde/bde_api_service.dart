import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/auth_repository.dart' show friendlyError;
import '../../../core/auth_session.dart';
import 'data.dart';

class BdeApiService {
  BdeApiService(this.session);
  final AuthSession session;
  bool _loading = false;
  bool get isLoading => _loading;

  String? _error;
  String? get error => _error;

  Map<String, dynamic>? liveMetrics;

  static Stage _mapStage(String? status) {
    switch (status?.toLowerCase()) {
      case 'new':
        return Stage.fresh;
      case 'contacted':
        return Stage.contacted;
      case 'meeting_scheduled':
        return Stage.meeting;
      case 'proposal_sent':
        return Stage.proposal;
      case 'negotiation':
        return Stage.negotiation;
      case 'converted':
        return Stage.won;
      case 'lost':
        return Stage.lost;
      default:
        return Stage.contacted;
    }
  }

  static String _stageToStatus(Stage stage) {
    switch (stage) {
      case Stage.fresh:
        return 'new';
      case Stage.contacted:
        return 'contacted';
      case Stage.qualified:
      case Stage.meeting:
        return 'meeting_scheduled';
      case Stage.proposal:
        return 'proposal_sent';
      case Stage.negotiation:
        return 'negotiation';
      case Stage.won:
        return 'converted';
      case Stage.lost:
      case Stage.disqualified:
        return 'lost';
      case Stage.nurture:
        return 'contacted';
    }
  }

  static Temp _mapTemp(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'hot':
        return Temp.hot;
      case 'warm':
        return Temp.warm;
      case 'cold':
        return Temp.cold;
      default:
        return Temp.warm;
    }
  }

  static String _tempToPriority(Temp temp) {
    switch (temp) {
      case Temp.hot:
        return 'hot';
      case Temp.warm:
        return 'warm';
      case Temp.cold:
        return 'cold';
      case Temp.unknown:
        return 'warm';
    }
  }

  static List<dynamic> _asList(dynamic res) {
    if (res is List) return res;
    if (res is Map && res['items'] is List) return res['items'] as List;
    return const [];
  }

  /// Initial load or refresh of all BDE dashboard data from real backend.
  Future<void> refreshAll() async {
    _loading = true;
    _error = null;
    try {
      await Future.wait([
        fetchLeads(),
        fetchMetrics(),
        fetchPlans(),
      ]);
    } catch (e) {
      _error = friendlyError(e);
      debugPrint('BDE refresh error: $e');
    } finally {
      _loading = false;
      changed.value++;
    }
  }

  /// Fetch live leads from GET /api/v1/bde/leads
  Future<void> fetchLeads({String? priority, String? status, String? search}) async {
    try {
      final query = <String, String>{};
      if (priority != null && priority.isNotEmpty) query['priority'] = priority;
      if (status != null && status.isNotEmpty) query['status'] = status;
      if (search != null && search.isNotEmpty) query['search'] = search;

      final queryString = query.isNotEmpty
          ? '?${query.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}'
          : '';

      final dynamic res = await session.request('GET', '/api/v1/bde/leads$queryString');
      final list = _asList(res);
      if (list.isNotEmpty || res is Map) {
        final newLeads = <Lead>[];
        for (final raw in list) {
          if (raw is! Map<String, dynamic>) continue;
          final lead = Lead(
            id: raw['id']?.toString(),
            name: raw['name'] as String? ?? 'Prospect',
            company: raw['company_name'] as String? ?? 'Brand',
            email: raw['email'] as String? ?? '',
            phone: raw['phone'] as String? ?? '',
            requirements: raw['requirements'] as String? ?? '',
            source: raw['lead_source'] as String? ?? 'Inbound Website',
            value: (raw['estimated_deal_value'] as num?)?.toInt() ?? 0,
            temp: _mapTemp(raw['priority'] as String?),
            stage: _mapStage(raw['status'] as String?),
            created: DateTime.tryParse(raw['created_at']?.toString() ?? ''),
          );

          // If next_follow_up_at is given, add scheduled commitment
          final followUpStr = raw['next_follow_up_at']?.toString();
          if (followUpStr != null && followUpStr.isNotEmpty) {
            final due = DateTime.tryParse(followUpStr);
            if (due != null) {
              lead.booked = lead.value;
            }
          }

          newLeads.add(lead);
        }

        save(() {
          leads.clear();
          leads.addAll(newLeads);
        });
      }
    } catch (e) {
      debugPrint('Error fetching leads: $e');
      rethrow;
    }
  }

  /// Fetch live metrics from GET /api/v1/bde/metrics
  Future<Map<String, dynamic>?> fetchMetrics() async {
    try {
      final res = await session.request('GET', '/api/v1/bde/metrics');
      liveMetrics = Map<String, dynamic>.from(res);
      return liveMetrics;
    } catch (e) {
      debugPrint('Error fetching BDE metrics: $e');
    }
    return null;
  }

  /// Fetch live subscription tiers from GET /api/v1/plans
  Future<void> fetchPlans() async {
    try {
      final dynamic res = await session.request('GET', '/api/v1/plans');
      final list = _asList(res);
      if (list.isNotEmpty) {
        final serverPlans = <Plan>[];
        for (final item in list) {
          if (item is! Map<String, dynamic>) continue;
          final name = item['display_name'] as String? ?? item['name'] as String? ?? 'Plan';
          final price = (item['monthly_price'] as num?)?.toInt() ??
              ((item['price_minor'] as num?)?.toInt() ?? 0) ~/ 100;
          final highlights = (item['highlights'] as List?)?.map((e) => e.toString()).toList() ??
              <String>[
                '${item['poster_quota'] ?? 0} posters',
                '${item['reel_quota'] ?? 0} reels',
                '${item['story_quota'] ?? 0} stories',
              ];
          serverPlans.add(Plan(name, price, highlights));
        }
        if (serverPlans.isNotEmpty) {
          plans = serverPlans;
        }
      }
    } catch (e) {
      debugPrint('Error fetching plans: $e');
    }
  }

  /// Create a new lead on backend via POST /api/v1/bde/leads
  Future<Lead?> createLead({
    required String name,
    required String company,
    String? email,
    String? phone,
    int? dealValue,
    Temp temp = Temp.warm,
    Stage stage = Stage.fresh,
    String? requirements,
    DateTime? nextFollowUp,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name.trim(),
        'company_name': company.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        'estimated_deal_value': dealValue ?? 0,
        'priority': _tempToPriority(temp),
        'status': _stageToStatus(stage),
        'requirements': requirements?.trim() ?? '',
        if (nextFollowUp != null) 'next_follow_up_at': nextFollowUp.toUtc().toIso8601String(),
      };

      final res = await session.request('POST', '/api/v1/bde/leads', body: body);
      final m = Map<String, dynamic>.from(res);
      final newLead = Lead(
        id: m['id']?.toString(),
        name: m['name'] as String? ?? name,
        company: m['company_name'] as String? ?? company,
        email: m['email'] as String? ?? (email ?? ''),
        phone: m['phone'] as String? ?? (phone ?? ''),
        requirements: m['requirements'] as String? ?? (requirements ?? ''),
        value: (m['estimated_deal_value'] as num?)?.toInt() ?? (dealValue ?? 0),
        temp: _mapTemp(m['priority'] as String?),
        stage: _mapStage(m['status'] as String?),
        created: DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
      );

      save(() => leads.insert(0, newLead));
      return newLead;
    } catch (e) {
      debugPrint('Error creating lead: $e');
      rethrow;
    }
  }

  /// Update stage on backend via PATCH /api/v1/bde/leads/{id}
  Future<void> updateLeadStage(Lead lead, Stage newStage) async {
    final oldStage = lead.stage;
    save(() => lead.stage = newStage);

    if (lead.id != null) {
      try {
        await session.request('PATCH', '/api/v1/bde/leads/${lead.id}', body: {
          'status': _stageToStatus(newStage),
        });
      } catch (e) {
        debugPrint('Error updating lead stage: $e');
        // Revert on error
        save(() => lead.stage = oldStage);
        rethrow;
      }
    }
  }

  /// Log activity (Call, WhatsApp, Meeting, Note) via POST /api/v1/bde/leads/{id}/activities
  Future<void> logActivity(Lead lead, {
    required String type,
    required String summary,
    String? outcome,
    DateTime? nextFollowUp,
  }) async {
    save(() => lead.activities.insert(0, Activity(type, summary, outcome ?? '')));

    if (lead.id != null) {
      try {
        await session.request('POST', '/api/v1/bde/leads/${lead.id}/activities', body: {
          'activity_type': type.toLowerCase(),
          'summary': summary,
          if (outcome != null) 'outcome': outcome,
          if (nextFollowUp != null) 'scheduled_follow_up': nextFollowUp.toUtc().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Error logging activity: $e');
      }
    }
  }
}
