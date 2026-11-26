import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool showBorder;
  final bool showShadow;

  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.color,
    this.showBorder = true,
    this.showShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      boxShadow: showShadow ? AppShadows.soft : null,
    );

    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: decoration,
      foregroundDecoration: showBorder
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.divider, width: 1.25),
            )
          : null,
      child: child,
    );

    if (onTap == null) return content;

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: content,
      ),
    );
  }
}
