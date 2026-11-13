import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class CreativePodDetailScreen extends StatefulWidget {
  final VoidCallback? onOpenWorkspaceChat;

  const CreativePodDetailScreen({super.key, this.onOpenWorkspaceChat});

  static Future<void> show(BuildContext context, {VoidCallback? onOpenChat}) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => CreativePodDetailScreen(onOpenWorkspaceChat: onOpenChat),
      ),
    );
  }

  @override
  State<CreativePodDetailScreen> createState() => _CreativePodDetailScreenState();
}

class _CreativePodDetailScreenState extends State<CreativePodDetailScreen> {
  // Filled from the client's pod assignment once the backend is connected.
  final List<_PodMember> members = [];

  final List<_CallSlot> slots = [];

  String? bookedSlotId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Your creative pod', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined, color: AppColors.amber),
            tooltip: 'Workspace Hub',
            onPressed: () {
              Navigator.pop(context);
              widget.onOpenWorkspaceChat?.call();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pod Overview Hero Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [AppColors.amber.withAlpha(40), AppColors.surface]
                      : [AppColors.amber.withAlpha(25), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.amber.withAlpha(90)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withAlpha(35),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.emerald.withAlpha(100)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, size: 8, color: AppColors.emerald),
                            SizedBox(width: 6),
                            Text(
                              'POD ONLINE · IST 10:00 - 19:00',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.emerald),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Your pod',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.amber),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your Dedicated Production Crew',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? AppColors.ivory : AppColors.lightInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Exclusive creative pod assigned to your brand for consistent aesthetic voice and rapid turnaround.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.mist : AppColors.lightMist,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Book a Strategy Call Section
            Text(
              '15-Minute Strategy Sync',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.ivory : AppColors.lightInk,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pick a slot with your Pod Lead for creative briefs, concept tweaks, or performance review.',
              style: TextStyle(fontSize: 11, color: isDark ? AppColors.mist : AppColors.lightMist),
            ),
            const SizedBox(height: 12),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: slots.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final slot = slots[i];
                final isBooked = bookedSlotId == slot.id;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardBg : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isBooked ? AppColors.emerald : (isDark ? AppColors.line : AppColors.lightBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surface : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          slot.dateLabel,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? AppColors.ivory : AppColors.lightInk),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          slot.timeLabel,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.ivory : AppColors.lightInk),
                        ),
                      ),
                      if (isBooked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.emerald.withAlpha(80)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_rounded, size: 12, color: AppColors.emerald),
                              SizedBox(width: 4),
                              Text('Booked', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.emerald)),
                            ],
                          ),
                        )
                      else
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            setState(() => bookedSlotId = slot.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Booked 15-min call: ${slot.dateLabel} at ${slot.timeLabel} with your pod lead!'),
                                backgroundColor: AppColors.amber,
                              ),
                            );
                          },
                          child: const Text('Book Call', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Pod Roster Section
            Text(
              members.isEmpty ? 'Roster · not assigned yet' : 'Roster (${members.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.ivory : AppColors.lightInk,
              ),
            ),
            const SizedBox(height: 12),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: members.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final m = members[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardBg : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isDark ? AppColors.line : AppColors.lightBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: m.isPrimary ? AppColors.amber : (isDark ? AppColors.surface : Colors.grey.shade200),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            m.initials,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: m.isPrimary ? Colors.black : (isDark ? AppColors.ivory : AppColors.lightInk),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  m.name,
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.ivory : AppColors.lightInk),
                                ),
                                if (m.isPrimary) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.amber.withAlpha(35),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('LEAD', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.amber)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              m.role,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.amber),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              m.desc,
                              style: TextStyle(fontSize: 11, color: isDark ? AppColors.mist : AppColors.lightMist, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _PodMember {
  final String name;
  final String role;
  final String initials;
  final bool isPrimary;
  final String desc;
  final String email;

  const _PodMember({
    required this.name,
    required this.role,
    required this.initials,
    required this.isPrimary,
    required this.desc,
    required this.email,
  });
}

class _CallSlot {
  final String id;
  final String dateLabel;
  final String timeLabel;
  final bool isBooked;

  _CallSlot({
    required this.id,
    required this.dateLabel,
    required this.timeLabel,
    required this.isBooked,
  });
}
