import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/creo_card.dart';
import '../../widgets/creo_segmented_tabs.dart';
import '../../widgets/creo_animations.dart';

class InboxShellScreen extends StatefulWidget {
  const InboxShellScreen({super.key});

  @override
  State<InboxShellScreen> createState() => _InboxShellScreenState();
}

class _InboxShellScreenState extends State<InboxShellScreen> {
  int _selectedSubTab = 0; // 0: Chat, 1: Support

  @override
  Widget build(BuildContext context) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Main Page Title ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'Inbox',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ),
        const SizedBox(height: 14),

        // ── Sub-tabs (Chat / Support 2) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Expanded(
                child: _buildSubTabButton('Chat', _selectedSubTab == 0, () {
                  setState(() => _selectedSubTab = 0);
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSubTabButton('Support', _selectedSubTab == 1, () {
                  setState(() => _selectedSubTab = 1);
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Active Tab Content with Smooth Fade-Slide Transition ──
        Expanded(
          child: AnimatedSwitcher(
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
                  ? _buildChatView(context)
                  : _buildSupportView(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubTabButton(String label, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CreoPressScale(
      onTap: onTap,
      pressedScale: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? CreoColors.ivory : CreoColors.lightEspresso)
              : (isDark ? CreoColors.unselectedPill : CreoColors.lightPillUnselected),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? (isDark ? CreoColors.obsidian : CreoColors.ivory)
                  : (isDark ? CreoColors.mist : CreoColors.lightMist),
            ),
          ),
        ),
      ),
    );
  }

  // ── 1. Pod Workspace Chat View (Matching Page 17 of PDF) ──
  Widget _buildChatView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      children: [
        // Search
        const CreoSearchBar(hintText: 'Search chats'),
        const SizedBox(height: 20),

        // Groups / Channels
        Text(
          'Channels & Pods',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? CreoColors.mist : CreoColors.lightMist,
          ),
        ),
        const SizedBox(height: 10),

        CreoCard(
          child: Text(
            'Your pod channel appears here once your team is assigned',
            style: TextStyle(fontSize: 13, color: isDark ? CreoColors.mist : CreoColors.lightMist),
          ),
        ),
        const SizedBox(height: 24),

        // Direct Messages with Pod Specialists
        Text(
          'Direct Messages',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? CreoColors.mist : CreoColors.lightMist,
          ),
        ),
        const SizedBox(height: 10),

        CreoCard(
          child: Text(
            'No messages yet',
            style: TextStyle(fontSize: 13, color: isDark ? CreoColors.mist : CreoColors.lightMist),
          ),
        ),
        const SizedBox(height: 24),

        CreoPillButton(
          label: 'Send message to pod',
          width: double.infinity,
          onPressed: () {},
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── 2. Specialist Support Desk View (Matching Page 18 of PDF) ──
  Widget _buildSupportView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      children: [
        // SLA & Metrics Row matching PDF
        Row(
          children: [
            _buildStatBox('Open', '0'),
            const SizedBox(width: 10),
            _buildStatBox('Solved', '0'),
            const SizedBox(width: 10),
            _buildStatBox('SLA Target', '4h'),
          ],
        ),
        const SizedBox(height: 16),

        // Search Bar
        const CreoSearchBar(hintText: 'Search ticket number, subject'),
        const SizedBox(height: 16),

        // Filter chips: Active 2, Closed 1
        Row(
          children: [
            CreoFilterChip(
              label: 'Active',
              count: 0,
              isSelected: true,
              onTap: () {},
            ),
            const SizedBox(width: 8),
            CreoFilterChip(
              label: 'Closed',
              count: 0,
              isSelected: false,
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Tickets List
        CreoCard(
          child: Text(
            'No support tickets yet',
            style: TextStyle(fontSize: 13, color: isDark ? CreoColors.mist : CreoColors.lightMist),
          ),
        ),
        const SizedBox(height: 24),

        CreoPillButton(
          label: 'Raise a new ticket',
          width: double.infinity,
          onPressed: () => _openNewTicketModal(context),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStatBox(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? CreoColors.bentoCard : CreoColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? CreoColors.lineSoft : CreoColors.lightLine,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? CreoColors.mist : CreoColors.lightMist,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _openNewTicketModal(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? CreoColors.bentoCard : CreoColors.lightCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Raise a Support Ticket',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your dedicated pod lead picks this up immediately within 4-hour SLA.',
              style: TextStyle(fontSize: 12, color: CreoColors.mist),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                hintText: 'Subject / Summary',
                filled: true,
                fillColor: isDark ? CreoColors.surface : CreoColors.lightBase,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe issue or deliverable reference...',
                filled: true,
                fillColor: isDark ? CreoColors.surface : CreoColors.lightBase,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            CreoPillButton(
              label: 'Submit Ticket',
              width: double.infinity,
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ticket created successfully!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

