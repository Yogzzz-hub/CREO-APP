import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'creo_animations.dart';

class CreoPortalDrawer extends StatelessWidget {
  final String activeItem;
  final int pendingReviewCount;
  final Function(String) onSelect;
  final VoidCallback onThemeToggle;
  final VoidCallback onSignOut;

  const CreoPortalDrawer({
    super.key,
    required this.activeItem,
    this.pendingReviewCount = 0,
    required this.onSelect,
    required this.onThemeToggle,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F0E0C) : Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer Top Brand Strip
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          text: 'creo',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                            color: isDark ? AppColors.ivory : AppColors.lightInk,
                          ),
                          children: const [
                            TextSpan(
                              text: '.',
                              style: TextStyle(
                                color: AppColors.amber,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'CLIENT PORTAL',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                          color: isDark ? const Color(0xFF8E877F) : AppColors.lightMist,
                        ),
                      ),
                    ],
                  ),
                  CreoPressScale(
                    onTap: onThemeToggle,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF282420) : Colors.grey.shade300,
                          width: 1,
                        ),
                        color: isDark ? const Color(0xFF171513) : Colors.grey.shade100,
                      ),
                      child: Icon(
                        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                        size: 20,
                        color: isDark ? const Color(0xFFEDE8E1) : AppColors.lightInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Navigation Items List
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // OVERVIEW Section
                  _sectionHeader('OVERVIEW', isDark),
                  const SizedBox(height: 4),
                  _navItem(Icons.grid_view_rounded, 'Dashboard', 'dashboard', isDark),
                  _navItem(
                    Icons.fact_check_outlined,
                    'Review',
                    'review',
                    isDark,
                    countBadge: pendingReviewCount > 0 ? pendingReviewCount : null,
                  ),
                  _navItem(Icons.calendar_today_outlined, 'Calendar', 'calendar', isDark),
                  _navItem(Icons.folder_open_outlined, 'Library', 'library', isDark),

                  const SizedBox(height: 22),

                  // YOUR BRAND Section
                  _sectionHeader('YOUR BRAND', isDark),
                  const SizedBox(height: 4),
                  _navItem(
                    Icons.chat_bubble_outline_rounded,
                    'Workspace Hub',
                    'chat',
                    isDark,
                    trailingTag: 'Chat',
                  ),
                  _navItem(Icons.alt_route_rounded, 'Brand DNA', 'brand', isDark),

                  const SizedBox(height: 22),

                  // ACCOUNT Section
                  _sectionHeader('ACCOUNT', isDark),
                  const SizedBox(height: 4),
                  _navItem(Icons.credit_card_outlined, 'Plan & billing', 'billing', isDark),
                  _navItem(Icons.help_outline_rounded, 'Help', 'help', isDark),
                  _navItem(Icons.settings_outlined, 'Settings', 'settings', isDark),
                  _navItem(
                    Icons.logout_rounded,
                    'Log out',
                    'logout',
                    isDark,
                    isLogout: true,
                    flipIcon: true,
                  ),
                ],
              ),
            ),

            // User Profile Footer Strip matching exact web screenshot
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF221F1B) : AppColors.lightBorder,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE4A66C), // Warm peach/tan matching web portal
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'AN',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF14120E),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Arvind N',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.ivory : AppColors.lightInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Growth plan · Pod pen...',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF8E877F) : AppColors.lightMist,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CreoPressScale(
                    onTap: onSignOut,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: Center(
                        child: Transform.flip(
                          flipX: true,
                          child: Icon(
                            Icons.logout_rounded,
                            size: 20,
                            color: isDark ? const Color(0xFF8E877F) : AppColors.lightMist,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.8,
          color: isDark ? const Color(0xFF7A736B) : AppColors.lightMist,
        ),
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label,
    String key,
    bool isDark, {
    String? trailingTag,
    int? countBadge,
    bool isLogout = false,
    bool flipIcon = false,
  }) {
    final isSelected = activeItem == key;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: CreoPressScale(
        onTap: () => onSelect(key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFFF4ECE1) : AppColors.lightInk)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
          ),
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            leading: flipIcon
                ? Transform.flip(
                    flipX: true,
                    child: Icon(
                      icon,
                      size: 20,
                      color: isSelected
                          ? (isDark ? const Color(0xFF0F0E0C) : Colors.white)
                          : (isDark ? const Color(0xFF9E968D) : AppColors.lightMist),
                    ),
                  )
                : Icon(
                    icon,
                    size: 20,
                    color: isSelected
                        ? (isDark ? const Color(0xFF0F0E0C) : Colors.white)
                        : (isDark ? const Color(0xFF9E968D) : AppColors.lightMist),
                  ),
            title: Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? const Color(0xFF0F0E0C) : Colors.white)
                    : (isDark ? const Color(0xFFE2DCD3) : AppColors.lightInk),
              ),
            ),
            trailing: trailingTag != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? (isDark ? Colors.black26 : Colors.white30)
                            : (isDark ? const Color(0xFF332E28) : Colors.grey.shade300),
                        width: 1,
                      ),
                      color: isSelected
                          ? Colors.transparent
                          : (isDark ? const Color(0xFF171513) : Colors.grey.shade100),
                    ),
                    child: Text(
                      trailingTag,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? (isDark ? const Color(0xFF0F0E0C) : Colors.white)
                            : (isDark ? const Color(0xFFC7C0B8) : AppColors.lightInk),
                      ),
                    ),
                  )
                : countBadge != null && countBadge > 0 && !isSelected
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.amber,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$countBadge',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onAmber,
                          ),
                        ),
                      )
                    : null,
          ),
        ),
      ),
    );
  }
}
