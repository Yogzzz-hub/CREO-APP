import 'package:creo_client_portal/models/dashboard_model.dart';
import 'package:creo_client_portal/models/deliverable_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quota remaining falls back to quota minus used, never below 0', () {
    expect(QuotaItem.fromJson({'quota': 8, 'used': 3}).remaining, 5);
    expect(QuotaItem.fromJson({'quota': 4, 'used': 9}).remaining, 0);
    expect(QuotaItem.fromJson({'quota': 4, 'used': 1, 'remaining': 2}).remaining, 2);
  });

  test('dashboard reads plan, quotas and team from the API shape', () {
    final d = DashboardData.fromJson({
      'pending_deliverable_count': 2,
      'instagram_connected': true,
      'active_plan': {
        'name': 'Scale',
        'tier': 'scale',
        'days_remaining': 12,
        'quotas': {
          'reel': {'quota': 12, 'used': 2},
          'static_post': {'quota': 16, 'used': 4},
          'story': {'quota': 16, 'used': 0},
        },
      },
      'assigned_team': [
        {'id': 7, 'full_name': 'Pod Lead', 'role': 'team_lead'},
      ],
    });
    expect(d.planName, 'Scale');
    expect(d.daysRemaining, 12);
    expect(d.reelsQuota.remaining, 10);
    expect(d.postersQuota.quota, 16);
    expect(d.assignedTeam.single.name, 'Pod Lead');
    expect(d.assignedTeam.single.roleLabel, 'team_lead');
    expect(d.openTicketCount, 0);
  });

  test('deliverable defaults and status helpers', () {
    final r = DeliverableItem.fromJson({'id': 1, 'deliverable_type': 'REEL', 'status': 'revision_requested'});
    expect(r.deliverableType, 'reel');
    expect(r.isVideo, isTrue);
    expect(r.inRevision, isTrue);
    expect(r.needsApproval, isFalse);
    expect(r.aspectRatioTag, '9:16');
    final p = DeliverableItem.fromJson({'type': 'carousel', 'status': 'published'});
    expect(p.isApproved, isTrue);
    expect(p.aspectRatioTag, '4:5');
    expect(p.title, 'Untitled Creative');
  });
}
