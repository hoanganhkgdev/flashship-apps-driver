import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? backgroundColor;
  final double size;

  const AppIconBadge({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
    this.backgroundColor,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor ?? color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, color: color, size: AppSize.iconLg),
      );
}

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) => filled
      ? IconButton.filledTonal(
          onPressed: onPressed,
          tooltip: tooltip,
          icon: Icon(icon),
        )
      : IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          icon: Icon(icon),
        );
}
