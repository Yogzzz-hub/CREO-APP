import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/creo_card.dart';
import '../../widgets/creo_segmented_tabs.dart';
import '../../widgets/creo_animations.dart';
import '../inbox/ticket_detail_thread_screen.dart';
import '../billing/plan_bargain_modal.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  int _selectedSubTab = 0; // 0: Tickets & SLA, 1: Common Questions (FAQs)
  String _selectedCategory = 'Content';
  String _selectedUrgency = 'Medium';
  final TextEditingController _subjectCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  int? _expandedFaqIndex;

  final List<String> _categories = [
    'Content',
    'Billing',
    'Technical',
    'Brand',
    'Other'
  ];

  final List<String> _urgencies = ['Low', 'Medium', 'High', 'Urgent'];

  // Tickets load from the support API; none until it is connected.
  final List<Map<String, dynamic>> _tickets = [];

  final List<Map<String, String>> _faqs = [
    {
      'q': 'How do I request changes on a deliverable?',
      'a':
          'In the Review section, select "Request change" and describe your feedback or record a voice note. Your dedicated creative pod will deliver an updated version within your plan\'s turnaround SLA.',
    },
    {
      'q': 'What happens if I miss a review deadline?',
      'a':
          'Deliverables undergo standard 5-business-day auto-approval to keep production on cadence. You will receive notifications before auto-approval occurs.',
    },
    {
      'q': 'Can I add more reels or posts mid-cycle?',
      'a':
          'Yes! You can purchase Add-on top-up packs directly from the Plan & billing page. They apply immediately to your current cycle.',
    },
    {
      'q': 'How do revision rounds work per plan?',
      'a':
          'Revision rounds per deliverable depend on your plan: 1 round for Starter, 2 rounds for Growth, and 3 rounds for Scale. Leaving clear feedback ensures your pod gets it right on the next iteration.',
    },
    {
      'q': 'What are the SLA turnaround promises per plan?',
      'a':
          'Starter features 3 business days turnaround per deliverable batch, Growth offers 2 business days, and Scale offers 24-hour priority turnaround.',
    },
  ];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _submitNewTicket() {
    if (_subjectCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a ticket subject')),
      );
      return;
    }

    setState(() {
      _tickets.insert(0, {
        'rawId': 'tkt-${DateTime.now().millisecondsSinceEpoch}',
        'id': '#TKT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        'category': _selectedCategory,
        'title': _subjectCtrl.text.trim(),
        'priority': _selectedUrgency,
        'status': 'in_progress',
        'timeAgo': 'Just now',
        'specialist': 'Your pod',
      });
      _subjectCtrl.clear();
      _descCtrl.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ticket submitted! Your pod will respond within 4 hours.'),
        backgroundColor: AppColors.emerald,
      ),
    );
  }

  void _openCreateTicketModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.bentoCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NEW SUPPORT REQUEST',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: isDark ? AppColors.mist : AppColors.lightMist,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Raise a Ticket',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.ivory : AppColors.lightInk,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category selector
              Text(
                'Category',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.mist : AppColors.lightMist,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () {
                      setModalState(() => _selectedCategory = cat);
                      setState(() => _selectedCategory = cat);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.amber
                            : (isDark ? AppColors.surface : Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? AppColors.onAmber : (isDark ? AppColors.ivory : AppColors.lightInk),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Urgency selector
              Text(
                'Urgency Level',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.mist : AppColors.lightMist,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: _urgencies.map((urg) {
                  final isSelected = _selectedUrgency == urg;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setModalState(() => _selectedUrgency = urg);
                        setState(() => _selectedUrgency = urg);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (urg == 'Urgent'
                                  ? AppColors.terracotta
                                  : AppColors.amber)
                              : (isDark ? AppColors.surface : Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            urg,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? Colors.white : (isDark ? AppColors.ivory : AppColors.lightInk),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Subject input
              TextField(
                controller: _subjectCtrl,
                decoration: InputDecoration(
                  labelText: 'Subject',
                  hintText: 'e.g. Logo swap in Deliverable #3',
                  filled: true,
                  fillColor: isDark ? AppColors.surface : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Description input
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Add specific details, timestamp references, or instructions...',
                  filled: true,
                  fillColor: isDark ? AppColors.surface : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              CreoPillButton(
                label: 'Submit Ticket',
                width: double.infinity,
                isPrimary: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  _submitNewTicket();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

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
          Text(
            'HELP & SUPPORT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: isDark ? AppColors.mist : AppColors.lightMist,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Support Desk',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Direct line to your pod lead and creative operations.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.mist : AppColors.lightMist,
            ),
          ),
          const SizedBox(height: 16),

          // ── 4-Hour Priority SLA Guarantee Banner ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E281E), const Color(0xFF141A14)]
                    : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.emerald.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.flash_on_rounded, color: AppColors.emerald, size: 20),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          CreoPulseDot(color: AppColors.emerald, size: 7),
                          SizedBox(width: 8),
                          Text(
                            'Guaranteed 4-Hour SLA',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.emerald,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your dedicated Creative Pod Lead responds to all client requests within 4 hours during IST hours (Mon-Fri 10am - 7pm).',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: isDark ? AppColors.ivory : AppColors.lightInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Raise Ticket Action Button ──
          Row(
            children: [
              Expanded(
                child: CreoPillButton(
                  label: '+ Raise a Support Ticket',
                  isPrimary: true,
                  onPressed: () => _openCreateTicketModal(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Sub-tabs ──
          CreoSegmentedTabs(
            tabs: ['Active Tickets (${_tickets.length})', 'Common Questions (${_faqs.length})'],
            selectedIndex: _selectedSubTab,
            onTabSelected: (idx) => setState(() => _selectedSubTab = idx),
          ),
          const SizedBox(height: 20),

          if (_selectedSubTab == 0) _buildTicketsList(context),
          if (_selectedSubTab == 1) _buildFaqList(context),

          const SizedBox(height: 24),

          // ── Custom Pricing & Bargain Call Banner ──
          _buildBargainCallBanner(context),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildTicketsList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: _tickets.asMap().entries.map((entry) {
        final index = entry.key;
        final t = entry.value;
        final isResolved = t['status'] == 'resolved';
        final isUrgent = t['priority'] == 'Urgent';

        return CreoFadeSlide(
          delay: Duration(milliseconds: 65 * index),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TicketDetailThreadScreen(
                      ticketId: t['id'],
                      title: t['title'],
                      status: t['status'],
                      category: t['category'],
                      priority: t['priority'],
                    ),
                  ),
                );
              },
              child: CreoCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              t['id'],
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.amber,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '· ${t['category']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.mist : AppColors.lightMist,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isResolved
                                ? AppColors.emerald.withValues(alpha: 0.15)
                                : isUrgent
                                    ? AppColors.terracotta.withValues(alpha: 0.15)
                                    : AppColors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isResolved
                                ? '✓ Resolved'
                                : isUrgent
                                    ? 'Urgent'
                                    : 'In Progress',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isResolved
                                  ? AppColors.emerald
                                  : isUrgent
                                      ? AppColors.terracotta
                                      : AppColors.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t['title'],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: isDark ? AppColors.ivory : AppColors.lightInk,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded,
                                size: 14, color: isDark ? AppColors.mist : AppColors.lightMist),
                            const SizedBox(width: 5),
                            Text(
                              t['specialist'],
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.mist : AppColors.lightMist,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              'Open Thread',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.ivory : AppColors.lightInk,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.amber),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFaqList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: _faqs.asMap().entries.map((entry) {
        final index = entry.key;
        final faq = entry.value;
        final isExpanded = _expandedFaqIndex == index;

        return CreoFadeSlide(
          delay: Duration(milliseconds: 50 * index),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.bentoCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.line : AppColors.lightBorder,
                width: 1,
              ),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: isExpanded,
                onExpansionChanged: (exp) {
                  setState(() => _expandedFaqIndex = exp ? index : null);
                },
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Text(
                  faq['q']!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.ivory : AppColors.lightInk,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      faq['a']!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: isDark ? AppColors.mist : AppColors.lightMist,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBargainCallBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bentoCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.amber.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_in_talk_rounded, color: AppColors.amber, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Have a unique requirement?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.ivory : AppColors.lightInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Request custom pricing or schedule a live consultation call.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.mist : AppColors.lightMist,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CreoPillButton(
            label: 'Schedule a Call / Propose Offer',
            isPrimary: false,
            width: double.infinity,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: isDark ? AppColors.bentoCard : AppColors.lightCard,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                builder: (_) => const PlanBargainModal(),
              );
            },
          ),
        ],
      ),
    );
  }
}
