import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/auth_session.dart';

const Color _kEmeraldGreen = Color(0xFF10B981);

class AdminWorkspaceScreen extends StatefulWidget {
  const AdminWorkspaceScreen({
    super.key,
    required this.session,
  });

  final AuthSession session;

  @override
  State<AdminWorkspaceScreen> createState() => _AdminWorkspaceScreenState();
}

class _AdminWorkspaceScreenState extends State<AdminWorkspaceScreen> {
  int _currentTabIndex = 0;

  final List<Map<String, dynamic>> _mockPods = [
    {
      'name': 'Pod Alpha',
      'lead': 'Vikram Malhotra',
      'clients': 'Aura Wellness, Lumina, Zest Foods',
      'utilization': 88,
      'status': 'Optimal',
    },
    {
      'name': 'Pod Beta',
      'lead': 'Sarah Connor',
      'clients': 'Kinetics, Peak Wear, Nova Health',
      'utilization': 94,
      'status': 'Heavy Load',
    },
    {
      'name': 'Pod Gamma',
      'lead': 'Rohan Mehta',
      'clients': 'Velvet Thread, Pulse D2C',
      'utilization': 65,
      'status': 'Available Capacity',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final user = widget.session.current?.user;
    final adminName = user?.fullName.isNotEmpty == true ? user!.fullName : 'Super Admin';

    return Scaffold(
      backgroundColor: context.creo.appBase,
      appBar: AppBar(
        backgroundColor: context.creo.appSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Text.rich(
              TextSpan(
                text: 'creo',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: context.creo.appInk,
                ),
                children: [
                  TextSpan(
                    text: '.',
                    style: TextStyle(color: context.creo.accent),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'EXECUTIVE ADMIN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            color: context.creo.appMist,
            onPressed: () => widget.session.logout(notifyServer: true),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildCockpitTab(adminName),
          _buildPodsTab(),
          _buildApprovalsTab(),
          _buildSettingsTab(user),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (idx) => setState(() => _currentTabIndex = idx),
        backgroundColor: context.creo.appSurface,
        indicatorColor: context.creo.accent.withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: 'Pods',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_rtl_outlined),
            selectedIcon: Icon(Icons.checklist_rtl_rounded),
            label: 'Approvals',
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildCockpitTab(String adminName) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Agency Operations Cockpit',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.creo.appInk,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Logged in as $adminName (Super Admin Authority)',
          style: TextStyle(fontSize: 13, color: context.creo.appMist),
        ),
        const SizedBox(height: 20),

        // 4 KPI Cards
        Row(
          children: [
            Expanded(child: _buildKpiCard('Total MRR', '₹18,40,000', '+14% MoM', _kEmeraldGreen)),
            const SizedBox(width: 12),
            Expanded(child: _buildKpiCard('Active Clients', '14 Brands', '100% Retained', context.creo.accent)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildKpiCard('SLA Adherence', '98.8%', '33/34 on time', _kEmeraldGreen)),
            const SizedBox(width: 12),
            Expanded(child: _buildKpiCard('Deliverables in QA', '7 Batches', 'Needs Lead Signoff', Colors.amber)),
          ],
        ),
        const SizedBox(height: 24),

        // Urgent Action Items
        Text(
          'PENDING EXECUTIVE DECISIONS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: context.creo.appMist,
          ),
        ),
        const SizedBox(height: 12),
        _buildDecisionCard('Custom Plan Negotiation', 'Zest Foods requested 12 Reels + ₹1,40,000 budget', 'Approve Quote'),
        const SizedBox(height: 10),
        _buildDecisionCard('Specialist Leave Approval', 'Karthik Raja (Editor - Pod Alpha) requested Nov 18-19', 'Review Leave'),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, String sub, Color tagColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.creo.appSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.creo.appLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.creo.appMist)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.creo.appInk)),
          const SizedBox(height: 6),
          Text(sub, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tagColor)),
        ],
      ),
    );
  }

  Widget _buildDecisionCard(String title, String desc, String action) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.creo.appSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.creo.appLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.creo.appInk)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(fontSize: 12, color: context.creo.appMist)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action executed: $action')));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.creo.accent,
              foregroundColor: context.creo.onAccent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(action, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildPodsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Creative Pods Utilization', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.creo.appInk)),
        const SizedBox(height: 6),
        Text('Operational capacity across all 4 production pods.', style: TextStyle(fontSize: 13, color: context.creo.appMist)),
        const SizedBox(height: 20),
        ..._mockPods.map(
          (p) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.creo.appSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.creo.appLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(p['name'] as String, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.creo.appInk)),
                    Text('${p['utilization']}% utilized', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.creo.accent)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Lead: ${p['lead']}', style: TextStyle(fontSize: 12, color: context.creo.appMist)),
                Text('Brands: ${p['clients']}', style: TextStyle(fontSize: 12, color: context.creo.appMist)),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (p['utilization'] as int) / 100,
                  backgroundColor: context.creo.appLine,
                  color: (p['utilization'] as int) > 90 ? Colors.redAccent : context.creo.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Approvals Queue', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.creo.appInk)),
        const SizedBox(height: 6),
        Text('Sign-offs awaiting executive admin decision.', style: TextStyle(fontSize: 13, color: context.creo.appMist)),
        const SizedBox(height: 20),
        _buildDecisionCard('Invoice Release #INV-492', 'Lumina Botanicals Monthly Growth Tier', 'Release Invoice'),
        const SizedBox(height: 12),
        _buildDecisionCard('Instagram Token Re-auth', 'Peak Wear API token expiring in 48 hours', 'Send Auth Link'),
      ],
    );
  }

  Widget _buildSettingsTab(dynamic user) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.red.withValues(alpha: 0.2),
                child: const Icon(Icons.security_rounded, size: 36, color: Colors.redAccent),
              ),
              const SizedBox(height: 12),
              Text(
                user?.fullName ?? 'Creo Super Admin',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.creo.appInk),
              ),
              const SizedBox(height: 4),
              Text(user?.email ?? 'admin@creo.agency', style: TextStyle(fontSize: 13, color: context.creo.appMist)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () => widget.session.logout(notifyServer: true),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign Out of Admin Console'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.withValues(alpha: 0.15),
            foregroundColor: Colors.redAccent,
            elevation: 0,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

