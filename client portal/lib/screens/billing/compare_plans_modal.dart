import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/creo_pill_button.dart';
import '../../widgets/creo_animations.dart';

class ComparePlansModal extends StatelessWidget {
  final String currentPlanName;
  final VoidCallback? onOpenNegotiation;

  const ComparePlansModal({
    super.key,
    this.currentPlanName = 'Brand Accelerator',
    this.onOpenNegotiation,
  });

  static Future<void> show(BuildContext context, {String currentPlan = 'Brand Accelerator', VoidCallback? onNegotiate}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ComparePlansModal(
        currentPlanName: currentPlan,
        onOpenNegotiation: onNegotiate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final plans = [
      _PlanData(
        name: 'Starter Growth',
        price: '₹29,999',
        pricePeriod: '/ month',
        reelsQuota: 6,
        postsQuota: 6,
        storiesQuota: 10,
        revisionRounds: 1,
        sla: '3 Business Days turnaround',
        highlights: [
          'Full HD 1080p vertical reels',
          'Dedicated copywriter & hashtags',
          'Scheduled automated publishing',
        ],
        isCurrent: currentPlanName.toLowerCase().contains('starter'),
        isRecommended: false,
      ),
      _PlanData(
        name: 'Brand Accelerator',
        price: '₹49,999',
        pricePeriod: '/ month',
        reelsQuota: 12,
        postsQuota: 8,
        storiesQuota: 16,
        revisionRounds: 2,
        sla: '2 Business Days turnaround',
        highlights: [
          '4K Ultra HD cinematic color grading',
          'A/B Creative Hooks testing',
          'Weekly strategy sprint with Pod Lead',
          'Priority direct pod chat access',
        ],
        isCurrent: currentPlanName.toLowerCase().contains('accelerator') || currentPlanName.toLowerCase().contains('active'),
        isRecommended: true,
      ),
      _PlanData(
        name: 'Enterprise Scale',
        price: '₹89,999',
        pricePeriod: '/ month',
        reelsQuota: 24,
        postsQuota: 16,
        storiesQuota: 30,
        revisionRounds: 3,
        sla: '24-Hour VIP turnaround',
        highlights: [
          'Full-service creative pod allocation',
          'On-demand rush delivery tokens',
          'Monthly physical shoot in Chennai',
          'Executive Super Admin direct hotline',
        ],
        isCurrent: currentPlanName.toLowerCase().contains('scale') || currentPlanName.toLowerCase().contains('enterprise'),
        isRecommended: false,
      ),
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: isDark ? AppColors.line : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.mist.withAlpha(80) : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.amber.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.compare_arrows_rounded, color: AppColors.amber, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compare Plans & Quotas',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.ivory : AppColors.lightInk,
                        ),
                      ),
                      Text(
                        'Transparent monthly retainers with guaranteed turnaround SLAs',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.mist : AppColors.lightMist,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: isDark ? AppColors.mist : AppColors.lightMist),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.line),

          // Plans Carousel/List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: plans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (ctx, index) {
                final plan = plans[index];
                return CreoFadeSlide(
                  delay: Duration(milliseconds: 70 * index),
                  child: _buildPlanCard(context, plan, isDark),
                );
              },
            ),
          ),

          // Footer custom quote banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardBg : AppColors.lightSurface,
              border: Border(top: BorderSide(color: isDark ? AppColors.line : AppColors.lightBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Need custom quotas or annual terms?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.ivory : AppColors.lightInk,
                        ),
                      ),
                      Text(
                        'Book a 15-min strategy session with our director',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.mist : AppColors.lightMist,
                        ),
                      ),
                    ],
                  ),
                ),
                CreoPillButton(
                  label: 'Custom Quote',
                  icon: Icons.phone_in_talk_rounded,
                  isPrimary: false,
                  dense: true,
                  onPressed: () {
                    Navigator.pop(context);
                    onOpenNegotiation?.call();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, _PlanData plan, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBg : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: plan.isCurrent
              ? AppColors.amber
              : plan.isRecommended
                  ? AppColors.amber.withAlpha(120)
                  : (isDark ? AppColors.line : AppColors.lightBorder),
          width: plan.isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                plan.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.ivory : AppColors.lightInk,
                ),
              ),
              if (plan.isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withAlpha(35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.amber.withAlpha(100)),
                  ),
                  child: const Text(
                    'CURRENT PLAN',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.amber),
                  ),
                )
              else if (plan.isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withAlpha(35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.withAlpha(100)),
                  ),
                  child: const Text(
                    'RECOMMENDED',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFD8B4FE)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                plan.price,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppColors.ivory : AppColors.lightInk,
                ),
              ),
              Text(
                ' ${plan.pricePeriod}',
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.mist : AppColors.lightMist),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Quotas 3-box row
          Row(
            children: [
              Expanded(child: _quotaBox('${plan.reelsQuota}', 'Reels', Icons.movie_filter_rounded, isDark)),
              const SizedBox(width: 8),
              Expanded(child: _quotaBox('${plan.postsQuota}', 'Posts', Icons.image_outlined, isDark)),
              const SizedBox(width: 8),
              Expanded(child: _quotaBox('${plan.storiesQuota}', 'Stories', Icons.auto_awesome_rounded, isDark)),
            ],
          ),
          const SizedBox(height: 14),

          // Features
          _featureRow(Icons.refresh_rounded, '${plan.revisionRounds} revision rounds per deliverable', isDark),
          _featureRow(Icons.timer_outlined, plan.sla, isDark),
          ...plan.highlights.map((h) => _featureRow(Icons.check_circle_outline_rounded, h, isDark)),

          const SizedBox(height: 16),
          if (plan.isCurrent)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.line.withAlpha(60) : Colors.black.withAlpha(10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  'Active Retainer Tier',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? AppColors.mist : AppColors.lightMist),
                ),
              ),
            )
          else
            CreoPillButton(
              label: 'Switch to ${plan.name}',
              icon: Icons.bolt_rounded,
              isPrimary: plan.isRecommended,
              fullWidth: true,
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Switched to ${plan.name}! Order confirmed.'),
                    backgroundColor: AppColors.amber,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _quotaBox(String value, String label, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.line : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 14, color: AppColors.amber),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? AppColors.ivory : AppColors.lightInk),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: isDark ? AppColors.mist : AppColors.lightMist),
          ),
        ],
      ),
    );
  }

  Widget _featureRow(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: isDark ? AppColors.ivory.withAlpha(220) : AppColors.lightInk),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanData {
  final String name;
  final String price;
  final String pricePeriod;
  final int reelsQuota;
  final int postsQuota;
  final int storiesQuota;
  final int revisionRounds;
  final String sla;
  final List<String> highlights;
  final bool isCurrent;
  final bool isRecommended;

  const _PlanData({
    required this.name,
    required this.price,
    required this.pricePeriod,
    required this.reelsQuota,
    required this.postsQuota,
    required this.storiesQuota,
    required this.revisionRounds,
    required this.sla,
    required this.highlights,
    required this.isCurrent,
    required this.isRecommended,
  });
}
