import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import 'creo_animations.dart';

class CreoBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int pendingReviewCount;
  final int inboxBadgeCount;

  const CreoBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.pendingReviewCount = 3,
    this.inboxBadgeCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = [
      _NavItem(icon: Icons.home_filled, label: 'Home'),
      _NavItem(
        icon: Icons.assignment_outlined,
        label: 'Review',
        badgeCount: pendingReviewCount,
      ),
      _NavItem(icon: Icons.calendar_today_outlined, label: 'Calendar'),
      _NavItem(
        icon: Icons.chat_bubble_outline,
        label: 'Inbox',
        badgeCount: inboxBadgeCount,
      ),
      _NavItem(icon: Icons.person_outline, label: 'Account'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0E0C) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF221F1B) : AppColors.lightBorder,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isSelected = index == currentIndex;

          return CreoPressScale(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap(index);
            },
            pressedScale: 0.90,
            child: SizedBox(
              width: 64,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated pill container around the icon for the active tab
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.amber.withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedScale(
                          scale: isSelected ? 1.12 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          child: Icon(
                            item.icon,
                            size: 21,
                            color: isSelected
                                ? AppColors.amber
                                : (isDark ? const Color(0xFF8E877F) : AppColors.lightMist),
                          ),
                        ),
                        if (item.badgeCount != null && item.badgeCount! > 0)
                          Positioned(
                            top: -4,
                            right: -8,
                            child: AnimatedScale(
                              scale: isSelected ? 1.1 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: const BoxDecoration(
                                  color: AppColors.terracotta,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                                child: Center(
                                  child: Text(
                                    '${item.badgeCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 10.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? (isDark ? AppColors.ivory : AppColors.lightInk)
                          : (isDark ? const Color(0xFF7A736B) : AppColors.lightMist),
                    ),
                    child: Text(item.label),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final int? badgeCount;

  _NavItem({required this.icon, required this.label, this.badgeCount});
}
