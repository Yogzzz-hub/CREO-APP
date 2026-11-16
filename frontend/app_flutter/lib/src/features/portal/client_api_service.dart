import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/auth_session.dart';
import 'models/dashboard_model.dart';
import 'models/deliverable_model.dart';
import 'portal_repository.dart';

class ClientApiService {
  ClientApiService(this.session);
  final AuthSession session;
  late final _repository = PortalRepository(session);

  bool _loading = false;
  bool get isLoading => _loading;

  String? _error;
  String? get error => _error;

  DashboardData? liveDashboard;

  bool get onboardingComplete =>
      (session.current?.user.onboardingStage ?? 0) >= 8;
  List<DeliverableItem> liveDeliverables = [];

  static List<dynamic> _asList(dynamic res) {
    if (res is List) return res;
    if (res is Map && res['items'] is List) return res['items'] as List;
    return const [];
  }

  /// Initial load or refresh of all Client portal data from real backend.
  Future<void> refreshAll({VoidCallback? onDone}) async {
    if (_loading) return;
    _loading = true;
    _error = null;
    try {
      await Future.wait([
        fetchDashboard(),
        if (onboardingComplete) fetchDeliverables(),
      ]);
    } catch (e) {
      _error =
          'Unable to load workspace. Check connection, onboarding and subscription, then retry.';
    } finally {
      _loading = false;
      onDone?.call();
    }
  }

  Future<DashboardData> fetchDashboard() async {
    final generation = session.beginReadGeneration;
    final result = await _repository.read('/api/v1/portal/dashboard');
    if (!session.isCurrent(generation)) throw StateError('Session changed');
    return liveDashboard = DashboardData.fromJson(result);
  }

  Future<List<DeliverableItem>> fetchDeliverables() async {
    final generation = session.beginReadGeneration;
    final items = <String, DeliverableItem>{};
    final seenCursors = <String>{};
    String? cursor;
    do {
      final query = cursor == null
          ? ''
          : '&cursor_id=${Uri.encodeQueryComponent(cursor)}';
      final result = await _repository.read(
        '/api/v1/portal/deliverables?limit=200$query',
      );
      if (!session.isCurrent(generation)) throw StateError('Session changed');
      if (result['items'] is! List) {
        throw const FormatException('Invalid deliverables response');
      }
      final page = _asList(result)
          .map(
            (item) => DeliverableItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
      for (final item in page) {
        items[item.id] = item;
      }
      if (result['has_more'] != true) break;
      if (page.isEmpty || !seenCursors.add(page.last.id)) {
        throw const FormatException('Invalid pagination cursor');
      }
      cursor = page.last.id;
    } while (true);
    liveDeliverables = items.values.toList();
    return liveDeliverables;
  }

  /// POST /api/v1/deliverables/{id}/approve
  Future<void> approveDeliverable(String id) async {
    await _repository.approveDeliverable(id);
  }

  /// POST /api/v1/deliverables/{id}/request-changes
  Future<void> requestChanges(String id, String feedback) async {
    if (feedback.trim().isEmpty) {
      throw ArgumentError('Describe the requested changes.');
    }
    await _repository.requestDeliverableChanges(id, feedback.trim());
  }
}
