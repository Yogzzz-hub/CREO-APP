import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/creo_card.dart';
import '../../widgets/creo_segmented_tabs.dart';
import 'compare_plans_modal.dart';
import 'pause_plan_modal.dart';
import 'plan_bargain_modal.dart';

class PlanAndBillingScreen extends StatefulWidget {
  final VoidCallback onTriggerRazorpayCheckout;

  const PlanAndBillingScreen({
    super.key,
    required this.onTriggerRazorpayCheckout,
  });

  @override
  State<PlanAndBillingScreen> createState() => _PlanAndBillingScreenState();
}

class _PlanAndBillingScreenState extends State<PlanAndBillingScreen> {
  int _selectedSubTab = 0; // 0: Retainer, 1: Add-ons, 2: Invoices
  // No plan until billing data is loaded from the backend.
  bool _isAutoPayActive = false;
  final String _currentPlan = 'No active plan';
  final String _renewalDate = '—';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main Page Title ──
          Text(
            'Plan & billing',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 14),

          // ── Sub-tabs ──
          CreoSegmentedTabs(
            tabs: const ['Retainer', 'Add-ons', 'Invoices'],
            selectedIndex: _selectedSubTab,
            onTabSelected: (index) => setState(() => _selectedSubTab = index),
          ),
          const SizedBox(height: 20),

          // ── Active Sub-tab View with Smooth Crossfade ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey<int>(_selectedSubTab),
              child: _selectedSubTab == 0
                  ? _buildRetainerView(context)
                  : _selectedSubTab == 1
                      ? _buildAddonsView(context)
                      : _buildInvoicesView(context),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ── Tab 1: Retainer Plan Overview ──
  Widget _buildRetainerView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gold / Amber Plan Card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: CreoColors.amber,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: CreoColors.amber.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 6),
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
                    'CURRENT RETAINER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: CreoColors.onAmber.withValues(alpha: 0.7),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 12, color: Colors.black87),
                        const SizedBox(width: 4),
                        Text(
                          _isAutoPayActive ? 'AutoPay Active' : 'AutoPay Paused',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _currentPlan,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: CreoColors.onAmber,
                    ),
                  ),
                  const Text(
                    '—',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: CreoColors.onAmber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Choose a plan to start your content retainer.',
                style: TextStyle(
                  fontSize: 13,
                  color: CreoColors.onAmber.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.black12, height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'No billing date yet',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: CreoColors.onAmber.withValues(alpha: 0.9),
                    ),
                  ),
                  const Text(
                    'Not active',
                    style: TextStyle(
                      fontSize: 11,
                      color: CreoColors.onAmber,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Action Pills Grid: Compare, Pause, Negotiate
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: isDark ? AppColors.line : AppColors.lightBorder),
                  backgroundColor: isDark ? AppColors.cardBg : AppColors.lightSurface,
                ),
                icon: const Icon(Icons.compare_arrows_rounded, size: 16, color: AppColors.amber),
                label: Text(
                  'Compare Plans',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? AppColors.ivory : AppColors.lightInk),
                ),
                onPressed: () {
                  ComparePlansModal.show(
                    context,
                    currentPlan: _currentPlan,
                    onNegotiate: () => PlanBargainModal.show(context),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: isDark ? AppColors.line : AppColors.lightBorder),
                  backgroundColor: isDark ? AppColors.cardBg : AppColors.lightSurface,
                ),
                icon: const Icon(Icons.pause_circle_outline_rounded, size: 16, color: Colors.amber),
                label: Text(
                  'Pause Plan',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? AppColors.ivory : AppColors.lightInk),
                ),
                onPressed: () {
                  PausePlanModal.show(
                    context,
                    planName: _currentPlan,
                    renewalDate: _renewalDate,
                    onSuccess: () {
                      setState(() => _isAutoPayActive = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pause request received. Admin notified.'),
                          backgroundColor: AppColors.amber,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: isDark ? AppColors.line : AppColors.lightBorder),
                  backgroundColor: isDark ? AppColors.cardBg : AppColors.lightSurface,
                ),
                icon: const Icon(Icons.phone_in_talk_rounded, size: 16, color: AppColors.amber),
                label: Text(
                  'Custom Quote',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? AppColors.ivory : AppColors.lightInk),
                ),
                onPressed: () => PlanBargainModal.show(context),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Payment Method & AutoPay Settings
        CreoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Payment method',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: widget.onTriggerRazorpayCheckout,
                    child: const Text('Update', style: TextStyle(color: AppColors.amber, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surface : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_rounded, size: 20, color: AppColors.amber),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('No payment method on file', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        Text('Add one when you choose a plan', style: TextStyle(fontSize: 11, color: isDark ? AppColors.mist : AppColors.lightMist)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tab 2: Add-on Packs ──
  Widget _buildAddonsView(BuildContext context) {
    return Column(
      children: [
        _buildAddonCard(
          title: 'Extra Reel (9:16)',
          desc: 'Delivered within this batch with sound sync and captions',
          price: '₹4,500',
        ),
        const SizedBox(height: 12),
        _buildAddonCard(
          title: 'Rush Delivery',
          desc: '24-hour turnaround on any asset in your backlog',
          price: '₹6,000',
        ),
        const SizedBox(height: 12),
        _buildAddonCard(
          title: 'Extra Revision Round',
          desc: 'Add an extra revision iteration beyond your plan allowance',
          price: '₹1,500',
        ),
        const SizedBox(height: 12),
        _buildAddonCard(
          title: 'Half-Day Shoot Day',
          desc: 'Product + process footage in Chennai with cinematic lighting',
          price: '₹18,000',
        ),
      ],
    );
  }

  Widget _buildAddonCard({
    required String title,
    required String desc,
    required String price,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CreoCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? CreoColors.mist : CreoColors.lightMist,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: CreoColors.amber,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          CreoPillButton(
            label: 'Buy',
            onPressed: widget.onTriggerRazorpayCheckout,
          ),
        ],
      ),
    );
  }

  // ── Tab 3: Invoices View ──
  Widget _buildInvoicesView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CreoCard(
      child: Text(
        'No invoices yet',
        style: TextStyle(fontSize: 13, color: isDark ? CreoColors.mist : CreoColors.lightMist),
      ),
    );
  }

}
