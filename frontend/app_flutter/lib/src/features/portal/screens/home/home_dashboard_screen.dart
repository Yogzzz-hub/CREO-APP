import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/creo_card.dart';
import '../../widgets/creo_animations.dart';
import '../../models/dashboard_model.dart';
import 'creative_pod_detail_screen.dart';

class HomeDashboardScreen extends StatelessWidget {
  final DashboardData data;
  final VoidCallback onNavigateToReview;
  final VoidCallback onNavigateToCalendar;
  final VoidCallback onNavigateToChat;
  final VoidCallback onNavigateToBilling;

  const HomeDashboardScreen({
    super.key,
    required this.data,
    required this.onNavigateToReview,
    required this.onNavigateToCalendar,
    required this.onNavigateToChat,
    required this.onNavigateToBilling,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Eyebrow & Title ──
          CreoFadeSlide(
            delay: Duration.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_today()} · ${data.pendingDeliverableCount == 0 ? 'Nothing needs you right now' : '${data.pendingDeliverableCount} things need you'}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: isDark ? CreoColors.mist : CreoColors.lightMist,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Section 1: Needs your decision ──
          CreoFadeSlide(
            delay: const Duration(milliseconds: 70),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Needs your decision',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? CreoColors.mist : CreoColors.lightMist,
                  ),
                ),
                const SizedBox(height: 10),

                // Deliverables waiting review card
                CreoCard(
                  onTap: onNavigateToReview,
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: CreoColors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.assignment_outlined, color: CreoColors.amber, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.pendingDeliverableCount == 0 ? 'No drafts to review' : 'Review ${data.pendingDeliverableCount} drafts',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? CreoColors.ivory : CreoColors.lightEspresso,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              data.pendingDeliverableCount == 0 ? 'Drafts from your pod will appear here' : 'Awaiting your approval',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: isDark ? CreoColors.mist : CreoColors.lightMist,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: CreoColors.amber,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Section 2: This week's batch progress ──
          CreoFadeSlide(
            delay: const Duration(milliseconds: 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "This week's batch",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? CreoColors.mist : CreoColors.lightMist,
                  ),
                ),
                const SizedBox(height: 10),
                CreoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                              child: Row(
                            children: [
                              const CreoPulseDot(color: AppColors.amber, size: 7),
                              const SizedBox(width: 8),
                              Flexible(
                                  child: Text(
                                'Ready for your review',
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? CreoColors.ivory : CreoColors.lightEspresso,
                                ),
                              )),
                            ],
                          )),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: CreoColors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${data.pendingDeliverableCount} awaiting',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: CreoColors.amber,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 5-Step Pipeline Indicator
                      Row(
                        children: [
                          _buildStepBar(context, 'Brief', true),
                          const SizedBox(width: 4),
                          _buildStepBar(context, 'Prod', true),
                          const SizedBox(width: 4),
                          _buildStepBar(context, 'QA', true),
                          const SizedBox(width: 4),
                          _buildStepBar(context, 'Review', true, isCurrent: true),
                          const SizedBox(width: 4),
                          _buildStepBar(context, 'Schedule', false),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Section 3: The Burnished Amber Retainer Card ──
          CreoFadeSlide(
            delay: const Duration(milliseconds: 200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your plan this cycle',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? CreoColors.mist : CreoColors.lightMist,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: CreoColors.amber,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: CreoColors.amber.withValues(alpha: 0.28),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RETAINER QUOTA',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: CreoColors.onAmber.withValues(alpha: 0.7),
                            ),
                          ),
                          Text(
                            data.renewalDate == null ? 'No renewal date' : 'Renews ${_shortDate(data.renewalDate!)}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: CreoColors.onAmber.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data.planName ?? 'No active plan',
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: CreoColors.onAmber,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Quota Progress Bars with smooth Animated Progression
                      _buildQuotaRow('Reels (9:16)', data.reelsQuota.used, data.reelsQuota.quota),
                      const SizedBox(height: 12),
                      _buildQuotaRow('Posts (1:1)', data.postersQuota.used, data.postersQuota.quota),
                      const SizedBox(height: 12),
                      _buildQuotaRow('Stories', data.storiesQuota.used, data.storiesQuota.quota),

                      const SizedBox(height: 20),
                      const Divider(color: Colors.black12, height: 1),
                      const SizedBox(height: 14),

                      GestureDetector(
                        onTap: onNavigateToBilling,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Buy instant add-on credits',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: CreoColors.onAmber.withValues(alpha: 0.9),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const Icon(Icons.arrow_forward_rounded, size: 16, color: CreoColors.onAmber),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Section 4: Coming Up (Next 7 Days) ──
          CreoFadeSlide(
            delay: const Duration(milliseconds: 260),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Coming up · Next 7 days',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? CreoColors.mist : CreoColors.lightMist,
                      ),
                    ),
                    GestureDetector(
                      onTap: onNavigateToCalendar,
                      child: const Text(
                        'Open calendar >',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: CreoColors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CreoCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Text(
                    'Nothing scheduled in the next 7 days',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: isDark ? CreoColors.mist : CreoColors.lightMist,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Section 5: Your Creative Pod ──
          CreoFadeSlide(
            delay: const Duration(milliseconds: 320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                        child: Text(
                      'Your creative pod',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? CreoColors.mist : CreoColors.lightMist,
                      ),
                    )),
                    InkWell(
                      onTap: () => CreativePodDetailScreen.show(context, onOpenChat: onNavigateToChat),
                      child: const Text(
                        'View Roster & Call Slots →',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.amber),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => CreativePodDetailScreen.show(context, onOpenChat: onNavigateToChat),
                  child: CreoCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: CreoColors.amber.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  _initials(_podLead?.name),
                                  style: const TextStyle(
                                    color: CreoColors.amber,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _podLead?.name ?? 'Pod not assigned yet',
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? CreoColors.ivory : CreoColors.lightEspresso,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _podLead == null
                                      ? 'Your team appears here once assigned'
                                      : '${_podLead!.roleLabel}${_podLead!.podName == null ? '' : ' · ${_podLead!.podName}'}',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: isDark ? CreoColors.mist : CreoColors.lightMist,
                                  ),
                                ),
                              ],
                            )),
                          ],
                        )),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black12,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Meet your pod',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? CreoColors.ivory : CreoColors.lightEspresso,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  /// The pod lead, or the first assigned person, or null before a pod is assigned.
  TeamHandler? get _podLead {
    if (data.assignedTeam.isEmpty) return null;
    return data.assignedTeam.firstWhere((m) => m.role == 'team_lead', orElse: () => data.assignedTeam.first);
  }

  static String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '–';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String _today() {
    final n = DateTime.now();
    return '${_days[n.weekday - 1]} ${n.day} ${_months[n.month - 1]}';
  }

  static String _shortDate(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : '${d.day} ${_months[d.month - 1]}';
  }

  Widget _buildStepBar(BuildContext context, String label, bool isDone, {bool isCurrent = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: isCurrent ? 5 : 4,
            decoration: BoxDecoration(
              color: isCurrent
                  ? CreoColors.amber
                  : isDone
                      ? (isDark ? CreoColors.amber.withValues(alpha: 0.5) : CreoColors.amber.withValues(alpha: 0.4))
                      : (isDark ? Colors.white12 : Colors.black12),
              borderRadius: BorderRadius.circular(2),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: CreoColors.amber.withValues(alpha: 0.5),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
              color: isCurrent ? CreoColors.amber : (isDark ? CreoColors.mist : CreoColors.lightMist),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaRow(String label, int used, int quota) {
    final progress = (used / quota).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CreoColors.onAmber.withValues(alpha: 0.85),
              ),
            ),
            Text(
              '$used / $quota',
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: CreoColors.onAmber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: progress),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, val, _) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: val,
              backgroundColor: Colors.black12,
              valueColor: const AlwaysStoppedAnimation(Colors.black87),
              minHeight: 6,
            ),
          ),
        ),
      ],
    );
  }
}
