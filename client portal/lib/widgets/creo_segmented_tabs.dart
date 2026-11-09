import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import 'creo_animations.dart';

class CreoSegmentedTabs extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const CreoSegmentedTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = index == selectedIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CreoPressScale(
              onTap: () {
                HapticFeedback.selectionClick();
                onTabSelected(index);
              },
              pressedScale: 0.95,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.ivory : AppColors.lightInk)
                      : (isDark ? AppColors.bentoCard : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : (isDark ? AppColors.lineSoft : Colors.grey.shade300),
                    width: 1,
                  ),
                ),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? (isDark ? AppColors.obsidian : Colors.white)
                        : (isDark ? AppColors.mist : AppColors.lightMist),
                  ),
                  child: Text(tabs[index]),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class CreoFilterChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;

  const CreoFilterChip({
    super.key,
    required this.label,
    this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CreoPressScale(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      pressedScale: 0.95,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.ivory : AppColors.lightInk)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? AppColors.line : AppColors.lightBorder),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? AppColors.obsidian : Colors.white)
                    : (isDark ? AppColors.mist : AppColors.lightMist),
              ),
              child: Text(label),
            ),
            if (count != null) ...[
              const SizedBox(width: 5),
              AnimatedScale(
                scale: isSelected ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 180),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? (isDark ? AppColors.obsidian : Colors.white)
                        : AppColors.amber,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CreoSearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;

  const CreoSearchBar({
    super.key,
    this.hintText = 'Search title, client or format',
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? AppColors.bentoCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.lineSoft : AppColors.lightBorder,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(
            Icons.search,
            size: 18,
            color: isDark ? AppColors.mist : AppColors.lightMist,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: isDark ? AppColors.ivory : AppColors.lightInk,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: isDark ? AppColors.mist.withValues(alpha: 0.6) : AppColors.lightMist.withValues(alpha: 0.7),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
