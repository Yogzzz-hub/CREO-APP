class TeamHandler {
  final String id;
  final String name;
  final String email;
  final String role;
  final String roleLabel;
  final String? podName;

  TeamHandler({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.roleLabel,
    this.podName,
  });

  factory TeamHandler.fromJson(Map<String, dynamic> json) {
    return TeamHandler(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['full_name']?.toString() ?? 'Specialist',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      roleLabel: json['role_label']?.toString() ?? json['role']?.toString() ?? 'Pod Specialist',
      podName: json['pod_name']?.toString(),
    );
  }
}

class QuotaItem {
  final int quota;
  final int used;
  final int remaining;

  QuotaItem({required this.quota, required this.used, required this.remaining});

  factory QuotaItem.fromJson(Map<String, dynamic> json) {
    final q = json['quota'] as int? ?? 0;
    final u = json['used'] as int? ?? 0;
    return QuotaItem(
      quota: q,
      used: u,
      remaining: json['remaining'] as int? ?? (q - u).clamp(0, q),
    );
  }
}

class DashboardData {
  final int pendingDeliverableCount;
  final int openTicketCount;
  final String? brandSummary;
  final String? instagramUsername;
  final bool instagramConnected;
  final String? planName;
  final String? planTier;
  final String? renewalDate;
  final int daysRemaining;
  final QuotaItem reelsQuota;
  final QuotaItem postersQuota;
  final QuotaItem storiesQuota;
  final List<TeamHandler> assignedTeam;
  final List<Map<String, dynamic>> recentActivity;

  DashboardData({
    required this.pendingDeliverableCount,
    required this.openTicketCount,
    this.brandSummary,
    this.instagramUsername,
    required this.instagramConnected,
    this.planName,
    this.planTier,
    this.renewalDate,
    this.daysRemaining = 0,
    required this.reelsQuota,
    required this.postersQuota,
    required this.storiesQuota,
    required this.assignedTeam,
    required this.recentActivity,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final activePlan = json['active_plan'] as Map<String, dynamic>?;
    final quotas = (json['quotas'] as Map<String, dynamic>?) ?? (activePlan?['quotas'] as Map<String, dynamic>?) ?? {};

    return DashboardData(
      pendingDeliverableCount: json['pending_deliverable_count'] as int? ?? 0,
      openTicketCount: json['open_ticket_count'] as int? ?? 0,
      brandSummary: json['brand_summary']?.toString(),
      instagramUsername: json['instagram_username']?.toString(),
      instagramConnected: json['instagram_connected'] as bool? ?? false,
      planName: activePlan?['name']?.toString() ?? 'Growth Plan',
      planTier: activePlan?['tier']?.toString() ?? 'growth',
      renewalDate: activePlan?['current_period_end']?.toString(),
      daysRemaining: activePlan?['days_remaining'] as int? ?? 0,
      reelsQuota: QuotaItem.fromJson(quotas['reel'] as Map<String, dynamic>? ?? {'quota': 8, 'used': 4}),
      postersQuota: QuotaItem.fromJson(quotas['poster'] as Map<String, dynamic>? ?? quotas['static_post'] as Map<String, dynamic>? ?? {'quota': 15, 'used': 9}),
      storiesQuota: QuotaItem.fromJson(quotas['story'] as Map<String, dynamic>? ?? {'quota': 20, 'used': 14}),
      assignedTeam: (json['assigned_team'] as List<dynamic>?)
              ?.map((e) => TeamHandler.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recentActivity: (json['recent_activity'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
    );
  }
}

