import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'creo_animations.dart';

class CreoCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;

  const CreoCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ?? (isDark ? CreoColors.bentoCard : CreoColors.lightCard);
    final border = borderColor ?? (isDark ? CreoColors.lineSoft : CreoColors.lightLine);

    final cardWidget = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          splashColor: AppColors.amber.withValues(alpha: 0.1),
          highlightColor: AppColors.amber.withValues(alpha: 0.05),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return CreoPressScale(
        onTap: onTap,
        pressedScale: 0.985,
        child: cardWidget,
      );
    }

    return cardWidget;
  }
}

class CreoPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final IconData? icon;
  final double? width;
  final bool fullWidth;
  final bool dense;

  const CreoPillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isPrimary = true,
    this.icon,
    this.width,
    this.fullWidth = false,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final child = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? CreoColors.amber : Colors.transparent,
        foregroundColor: isPrimary
            ? CreoColors.onAmber
            : (isDark ? CreoColors.ivory : CreoColors.lightEspresso),
        elevation: 0,
        shape: const StadiumBorder(),
        side: isPrimary
            ? BorderSide.none
            : BorderSide(
                color: isDark ? CreoColors.line : CreoColors.lightLine,
                width: 1,
              ),
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 14 : 20,
          vertical: dense ? 8 : 12,
        ),
        textStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: dense ? 11 : 13,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 14 : 16),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
    );

    final interactiveChild = CreoPressScale(
      onTap: onPressed,
      pressedScale: 0.96,
      child: child,
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: interactiveChild);
    }
    if (width != null) {
      return SizedBox(width: width, child: interactiveChild);
    }
    return interactiveChild;
  }
}
