import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/creo_card.dart';
import '../../widgets/creo_animations.dart';
import 'hook_selection_modal.dart';
import '../../widgets/creo_segmented_tabs.dart';

class ContentCalendarScreen extends StatefulWidget {
  final VoidCallback onApprove30DayCampaign;

  const ContentCalendarScreen({
    super.key,
    required this.onApprove30DayCampaign,
  });

  @override
  State<ContentCalendarScreen> createState() => _ContentCalendarScreenState();
}

class _ContentCalendarScreenState extends State<ContentCalendarScreen> {
  int _viewIndex = 0; // 0: Month, 1: Agenda
  int _selectedDay = 7;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main Page Title ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              'Content',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          const SizedBox(height: 14),

          // ── Sub-tab Pills (Review, Calendar, Tasks, Publish) ──
          CreoSegmentedTabs(
            tabs: const ['Review', 'Calendar', 'Library'],
            selectedIndex: 1,
            onTabSelected: (_) {},
          ),
          const SizedBox(height: 16),

          // ── Quota Distribution Bar (Reels 4, Posts 8, Stories 10) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                _buildFormatStat('Reels', 4),
                const SizedBox(width: 10),
                _buildFormatStat('Posts', 8),
                const SizedBox(width: 10),
                _buildFormatStat('Stories', 10),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Month / Agenda Toggle ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                _buildPillToggle('Month', _viewIndex == 0, () {
                  setState(() => _viewIndex = 0);
                }),
                const SizedBox(width: 8),
                _buildPillToggle('Agenda', _viewIndex == 1, () {
                  setState(() => _viewIndex = 1);
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 30-Day Campaign Plan Approval Banner ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: CreoCard(
              backgroundColor: CreoColors.amber.withOpacity(0.12),
              borderColor: CreoColors.amber.withOpacity(0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: CreoColors.amber, size: 18),
                      SizedBox(width: 8),
                      Text(
                        '30-DAY NOVEMBER CAMPAIGN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: CreoColors.amber,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your dedicated pod has drafted 22 social slots across Reels, Carousels and Stories.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? CreoColors.ivory : CreoColors.lightEspresso,
                    ),
                  ),
                  const SizedBox(height: 14),
                  CreoPillButton(
                    label: 'Approve 30-Day Plan',
                    onPressed: widget.onApprove30DayCampaign,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Calendar Month Picker ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.chevron_left, size: 20),
                Text(
                  'November 2026',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? CreoColors.ivory : CreoColors.lightEspresso,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Days Grid ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _buildDaysGrid(context),
          ),
          const SizedBox(height: 24),

          // ── Selected Date Schedule Detail ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              'Saturday $_selectedDay Nov · 1 item scheduled',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? CreoColors.mist : CreoColors.lightMist,
              ),
            ),
          ),
          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: GestureDetector(
              onTap: () {
                HookSelectionModal.show(
                  context,
                  dateStr: 'Saturday $_selectedDay Mar 2026',
                  format: 'Reel',
                  title: 'Monsoon menu teaser',
                );
              },
              child: CreoCard(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: CreoColors.reelPurple.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          '9:16',
                          style: TextStyle(
                            color: CreoColors.reelPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Monsoon menu teaser',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Reel · 6:30 PM dispatch · Hook: Direct curiosity',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? CreoColors.mist : CreoColors.lightMist,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildFormatStat(String label, int count) {
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
              '$count',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillToggle(String label, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? CreoColors.ivory : CreoColors.lightEspresso)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? CreoColors.line : CreoColors.lightLine),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? CreoColors.obsidian : CreoColors.ivory)
                : (isDark ? CreoColors.mist : CreoColors.lightMist),
          ),
        ),
      ),
    );
  }

  Widget _buildDaysGrid(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekdays
              .map((d) => SizedBox(
                    width: 32,
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? CreoColors.mist : CreoColors.lightMist,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.0,
          ),
          itemCount: 30,
          itemBuilder: (context, index) {
            final day = index + 1;
            final isSelected = day == _selectedDay;
            final hasContent = [4, 7, 8, 9, 12, 15, 18, 22, 25, 28].contains(day);

            return CreoPressScale(
              onTap: () => setState(() => _selectedDay = day),
              pressedScale: 0.88,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isSelected
                      ? CreoColors.amber
                      : (isDark ? CreoColors.bentoCard : CreoColors.lightCard),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? CreoColors.amber
                        : (isDark ? CreoColors.lineSoft : CreoColors.lightLine),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: isSelected
                            ? CreoColors.onAmber
                            : (isDark ? CreoColors.ivory : CreoColors.lightEspresso),
                      ),
                    ),
                    if (hasContent && !isSelected)
                      Positioned(
                        bottom: 4,
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: CreoColors.amber,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

