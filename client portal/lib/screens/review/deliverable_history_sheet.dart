import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/deliverable_model.dart';
import '../../widgets/creo_card.dart';

class DeliverableHistorySheet extends StatelessWidget {
  final DeliverableItem deliverable;

  const DeliverableHistorySheet({super.key, required this.deliverable});

  static Future<void> show(BuildContext context, DeliverableItem item) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DeliverableHistorySheet(deliverable: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Version history comes from the deliverable versions API; none until it is connected.
    final historyEvents = <_HistoryEvent>[];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? CreoColors.bentoCard : CreoColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Revision History',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    deliverable.title,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? CreoColors.mist : CreoColors.lightMist,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Timeline List
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: historyEvents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final ev = historyEvents[index];
                return CreoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? CreoColors.surface : CreoColors.lightLine,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  ev.version,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                ev.timestamp,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? CreoColors.mist : CreoColors.lightMist,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: ev.badgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              ev.actionBadge,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: ev.badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ev.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        ev.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? CreoColors.mist : CreoColors.lightMist,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ev.notes,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? CreoColors.ivory : CreoColors.lightEspresso,
                        ),
                      ),
                      if (ev.hasVoiceNote) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? CreoColors.surface : CreoColors.lightBase,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.play_circle_filled, color: CreoColors.amber, size: 22),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Voice Feedback Note',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                ev.voiceDuration ?? '0:15',
                                style: const TextStyle(fontSize: 11, color: CreoColors.mist),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEvent {
  final String version;
  final String title;
  final String subtitle;
  final String timestamp;
  final String notes;
  final String actionBadge;
  final Color badgeColor;
  final bool hasVoiceNote;
  final String? voiceDuration;

  _HistoryEvent({
    required this.version,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.notes,
    required this.actionBadge,
    required this.badgeColor,
    required this.hasVoiceNote,
    required this.voiceDuration,
  });
}
