import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/deliverable_model.dart';
import '../../widgets/creo_card.dart';
import '../../widgets/creo_segmented_tabs.dart';
import '../../widgets/creo_animations.dart';
import 'deliverable_history_sheet.dart';
import 'withdraw_deliverable_sheet.dart';

class DeliverablesReviewScreen extends StatefulWidget {
  final List<DeliverableItem> deliverables;
  final Function(DeliverableItem) onApprove;
  final Function(DeliverableItem, String) onRequestChanges;
  final Function(DeliverableItem) onOpenTheater;
  final VoidCallback onOpenVoiceRecorder;

  const DeliverablesReviewScreen({
    super.key,
    required this.deliverables,
    required this.onApprove,
    required this.onRequestChanges,
    required this.onOpenTheater,
    required this.onOpenVoiceRecorder,
  });

  @override
  State<DeliverablesReviewScreen> createState() => _DeliverablesReviewScreenState();
}

class _DeliverablesReviewScreenState extends State<DeliverablesReviewScreen> {
  int _selectedFilterIndex = 0; // 0: To review, 1: Changes asked, 2: Approved
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter items based on active chip & search
    final filteredItems = widget.deliverables.where((item) {
      if (_selectedFilterIndex == 0 && !item.needsApproval) return false;
      if (_selectedFilterIndex == 1 && !item.inRevision) return false;
      if (_selectedFilterIndex == 2 && !item.isApproved) return false;
      if (_searchQuery.isNotEmpty &&
          !item.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Column(
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

        // ── Sub-tab Pills (Review, Calendar, Library) ──
        CreoSegmentedTabs(
          tabs: const ['Review', 'Calendar', 'Library'],
          selectedIndex: 0,
          onTabSelected: (index) {
            // Can switch views or handle tabs
          },
        ),
        const SizedBox(height: 16),

        // ── Search Bar ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: CreoSearchBar(
            hintText: 'Search title, client or format',
            onChanged: (val) {
              setState(() => _searchQuery = val);
            },
          ),
        ),
        const SizedBox(height: 14),

        // ── Filter Chips Row ──
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              CreoFilterChip(
                label: 'To review',
                count: widget.deliverables.where((d) => d.needsApproval).length,
                isSelected: _selectedFilterIndex == 0,
                onTap: () => setState(() => _selectedFilterIndex = 0),
              ),
              const SizedBox(width: 8),
              CreoFilterChip(
                label: 'Changes asked',
                count: widget.deliverables.where((d) => d.inRevision).length,
                isSelected: _selectedFilterIndex == 1,
                onTap: () => setState(() => _selectedFilterIndex = 1),
              ),
              const SizedBox(width: 8),
              CreoFilterChip(
                label: 'Approved',
                count: widget.deliverables.where((d) => d.isApproved).length,
                isSelected: _selectedFilterIndex == 2,
                onTap: () => setState(() => _selectedFilterIndex = 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Deliverables List ──
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Text(
                    'No items in this category',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: isDark ? CreoColors.mist : CreoColors.lightMist,
                    ),
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  itemCount: filteredItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return CreoFadeSlide(
                      delay: Duration(milliseconds: 65 * index),
                      child: _buildDeliverableCard(context, item),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDeliverableCard(BuildContext context, DeliverableItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CreoCard(
      onTap: () => widget.onOpenTheater(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top: Aspect Ratio Tag + Title + Arrow
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Aspect Ratio Tag Container
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDark ? CreoColors.surface : CreoColors.lightLine,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    item.aspectRatioTag,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? CreoColors.mist : CreoColors.lightMist,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Title and Meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? CreoColors.ivory : CreoColors.lightEspresso,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.formatLabel} · v${item.version} · ${item.scheduledDate ?? "Not scheduled"}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: isDark ? CreoColors.mist : CreoColors.lightMist,
                      ),
                    ),
                  ],
                ),
              ),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.history_rounded, size: 20),
                    tooltip: 'Version History',
                    color: isDark ? AppColors.mist : AppColors.lightMist,
                    onPressed: () => DeliverableHistorySheet.show(context, item),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, size: 20, color: isDark ? AppColors.mist : AppColors.lightMist),
                    onSelected: (val) {
                      if (val == 'withdraw') {
                        WithdrawDeliverableSheet.show(context, deliverableTitle: item.title);
                      } else if (val == 'history') {
                        DeliverableHistorySheet.show(context, item);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'history',
                        child: Row(
                          children: [
                            Icon(Icons.history_rounded, size: 16),
                            SizedBox(width: 8),
                            Text('Audit Trail (v1/v2/v3)'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'withdraw',
                        child: Row(
                          children: [
                            Icon(Icons.archive_outlined, size: 16, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Withdraw Deliverable', style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bottom Action Row (Conditional on Approval)
          if (item.isApproved) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: isDark ? CreoColors.bentoCard : CreoColors.lightCard,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        builder: (_) => DeliverableHistorySheet(deliverable: item),
                      );
                    },
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: const Text('History'),
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _showPublishingPanelDialog(context, item),
                    icon: const Icon(Icons.send_rounded, size: 14),
                    label: const Text('Publish / Dispatch'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Bottom Action Row matching PDF: [ Note ] [ Ask for changes ] [ Approve ]
            Row(
              children: [
                // Voice note / Note button
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showVoiceNoteDialog(context, item),
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      side: BorderSide(
                        color: isDark ? CreoColors.line : CreoColors.lightLine,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mic_none,
                          size: 15,
                          color: isDark ? CreoColors.ivory : CreoColors.lightEspresso,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Note',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? CreoColors.ivory : CreoColors.lightEspresso,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Ask for changes
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRequestChangesDialog(context, item),
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      side: BorderSide(
                        color: isDark ? CreoColors.line : CreoColors.lightLine,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(
                      'Ask for changes',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? CreoColors.ivory : CreoColors.lightEspresso,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Approve button (Burnished amber)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => widget.onApprove(item),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CreoColors.amber,
                      foregroundColor: CreoColors.onAmber,
                      shape: const StadiumBorder(),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Approve',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showRequestChangesDialog(BuildContext context, DeliverableItem item) {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? CreoColors.bentoCard : CreoColors.lightCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
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
              Text(
                'Request changes on ${item.title}',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pick quick notes or describe what the pod should change in revision v${item.version + 1}.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? CreoColors.mist : CreoColors.lightMist,
                ),
              ),
              const SizedBox(height: 14),

              // Quick Note Tag Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  'Less text',
                  'Different music',
                  'Stronger hook',
                  'Colour off-brand',
                  'Wrong product',
                ].map((tag) {
                  return InkWell(
                    onTap: () {
                      final current = controller.text;
                      controller.text = current.isEmpty ? tag : '$current · $tag';
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? CreoColors.surface : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? CreoColors.line : CreoColors.lightLine,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '+ $tag',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? CreoColors.ivory : CreoColors.lightEspresso,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: controller,
                maxLines: 3,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'What should your pod change?...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? CreoColors.mist.withValues(alpha: 0.5) : CreoColors.lightMist.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: isDark ? CreoColors.surface : CreoColors.lightBase,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? CreoColors.line : CreoColors.lightLine,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.mic_none_rounded, size: 18),
                      label: const Text('Voice Note'),
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onOpenVoiceRecorder();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: CreoPillButton(
                      label: 'Send to pod',
                      isPrimary: true,
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (controller.text.trim().isNotEmpty) {
                          widget.onRequestChanges(item, controller.text.trim());
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPublishingPanelDialog(BuildContext context, DeliverableItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final captionCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.bentoCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Instagram Auto-Publish',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.ivory : AppColors.lightInk,
                          ),
                        ),
                        const Text(
                          'Your connected Instagram account',
                          style: TextStyle(fontSize: 11, color: AppColors.mist),
                        ),
                      ],
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

            Text(
              'Caption & Hashtags',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.mist : AppColors.lightMist,
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: captionCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? AppColors.surface : Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.schedule_rounded, color: AppColors.emerald, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your pod sets the publishing time after approval',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.emerald),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Scheduling from the app is not available yet')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Save Schedule'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        // Publishing is not wired to the backend yet: never claim it happened.
                        const SnackBar(content: Text('Publishing from the app is not available yet')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      foregroundColor: AppColors.onAmber,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Publish Now', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showVoiceNoteDialog(BuildContext context, DeliverableItem item) {
    widget.onOpenVoiceRecorder();
  }
}

