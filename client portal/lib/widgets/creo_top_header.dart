import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class CreoTopHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String roleSubtitle;
  final String userInitials;
  final int notificationCount;
  final VoidCallback? onMenuTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onThemeToggle;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onProfileTap;

  const CreoTopHeader({
    super.key,
    this.title = 'creo.',
    this.roleSubtitle = 'Client',
    this.userInitials = 'AN',
    this.notificationCount = 3,
    this.onMenuTap,
    this.onNotificationTap,
    this.onThemeToggle,
    this.onSettingsTap,
    this.onProfileTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Menu Icon + Wordmark & Role Label
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (onMenuTap != null) ...[
                  IconButton(
                    icon: Icon(Icons.menu_rounded, size: 22, color: isDark ? CreoColors.ivory : CreoColors.lightEspresso),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: onMenuTap,
                  ),
                  const SizedBox(width: 6),
                ],
                RichText(
                  text: TextSpan(
                    text: 'creo',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: isDark ? CreoColors.ivory : CreoColors.lightEspresso,
                    ),
                    children: const [
                      TextSpan(
                        text: '.',
                        style: TextStyle(
                          color: CreoColors.amber,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  roleSubtitle,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? CreoColors.mist : CreoColors.lightMist,
                  ),
                ),
              ],
            ),

            // Right: Actions Row matching the PDF
            Row(
              children: [
                // Notification Bell with Badge
                IconButton(
                  onPressed: onNotificationTap,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        size: 20,
                        color: isDark ? CreoColors.ivory : CreoColors.lightEspresso,
                      ),
                      if (notificationCount > 0)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: CreoColors.badgeRed,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                            child: Center(
                              child: Text(
                                '$notificationCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),

                // Theme Toggle
                IconButton(
                  onPressed: onThemeToggle,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(
                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    size: 20,
                    color: isDark ? CreoColors.ivory : CreoColors.lightEspresso,
                  ),
                ),
                const SizedBox(width: 4),

                // Settings Cog
                IconButton(
                  onPressed: onSettingsTap,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(
                    Icons.settings_outlined,
                    size: 20,
                    color: isDark ? CreoColors.ivory : CreoColors.lightEspresso,
                  ),
                ),
                const SizedBox(width: 8),

                // User Avatar Circle
                GestureDetector(
                  onTap: onProfileTap,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: CreoColors.amber.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        userInitials,
                        style: const TextStyle(
                          color: CreoColors.onAmber,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

