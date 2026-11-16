/// Server-confirmed client setup and subscription state.
class ClientPortalAccess {
  const ClientPortalAccess({
    required this.stage,
    required this.emailVerified,
    required this.setupComplete,
    required this.subscriptionActive,
  });

  final int stage;
  final bool emailVerified, setupComplete, subscriptionActive;

  factory ClientPortalAccess.fromJson(
    Map<String, dynamic> status, {
    Map<String, dynamic>? subscription,
  }) {
    final stage = status['stage'];
    if (stage is! int ||
        stage < 0 ||
        stage > 8 ||
        status['is_complete'] is! bool) {
      throw const FormatException('Your setup progress could not be verified.');
    }
    final checklist = status['checklist'];
    final verified =
        stage >= 1 &&
        !(checklist is Map && checklist['email_verified'] == false);
    var paid = false;
    if (stage >= 3) {
      if (subscription == null) {
        throw const FormatException('Your subscription could not be verified.');
      }
      final details = subscription['subscription'];
      final state = details is Map ? details['status'] : null;
      final active = subscription['is_active'];
      if (active is! bool && state is! String) {
        throw const FormatException('Your subscription could not be verified.');
      }
      paid =
          subscription['is_expired'] != true &&
          !{
            'expired',
            'canceled',
            'cancelled',
            'past_due',
            'incomplete',
          }.contains(state) &&
          (active is bool ? active : {'active', 'trialing'}.contains(state));
    }
    return ClientPortalAccess(
      stage: stage,
      emailVerified: verified,
      setupComplete: stage == 8 && status['is_complete'] == true,
      subscriptionActive: paid,
    );
  }

  bool get canUseWorkspace =>
      emailVerified && setupComplete && subscriptionActive;

  String get nextAction {
    if (!emailVerified) return 'Verify your email';
    if (stage == 1) return 'Review service agreement';
    if (!subscriptionActive) return 'Choose or renew your plan';
    if (stage == 3) return 'Complete brand questionnaire';
    return 'Finalize and launch workspace';
  }

  String get lockReason => !subscriptionActive
      ? 'Activate your plan and complete setup to unlock your workspace.'
      : 'Complete your brand questionnaire and workspace setup to unlock production features.';
}
