import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppButtonVariant { primary, tonal, outline, danger }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool expand;
  final bool compact;
  final Color? color;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.expand = false,
    this.compact = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final size = Size(expand ? double.infinity : 64, compact ? 44 : 50);
    final padding = EdgeInsets.symmetric(
      horizontal: compact ? AppSpacing.md : AppSpacing.lg,
    );
    final style = switch (variant) {
      AppButtonVariant.primary =>
        FilledButton.styleFrom(minimumSize: size, padding: padding),
      AppButtonVariant.tonal => FilledButton.styleFrom(
          minimumSize: size,
          padding: padding,
          backgroundColor: (color ?? AppColors.primary).withValues(alpha: 0.14),
          foregroundColor: color ?? AppColors.primaryDark,
        ),
      AppButtonVariant.danger => FilledButton.styleFrom(
          minimumSize: size,
          padding: padding,
          backgroundColor: color ?? AppColors.danger,
          foregroundColor: Colors.white,
        ),
      AppButtonVariant.outline => OutlinedButton.styleFrom(
          minimumSize: size,
          padding: padding,
          foregroundColor: color ?? AppColors.textPrimary,
          side: BorderSide(
              color: (color ?? AppColors.divider)
                  .withValues(alpha: color == null ? 1 : .35)),
        ),
    };

    final child = Text(label);
    if (variant == AppButtonVariant.outline) {
      return icon == null
          ? OutlinedButton(onPressed: onPressed, style: style, child: child)
          : OutlinedButton.icon(
              onPressed: onPressed,
              style: style,
              icon: Icon(icon),
              label: child,
            );
    }
    return icon == null
        ? FilledButton(onPressed: onPressed, style: style, child: child)
        : FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon),
            label: child,
          );
  }
}
