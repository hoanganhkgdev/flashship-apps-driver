import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppValueRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const AppValueRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(children: [
            Icon(icon, size: AppSize.iconMd, color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(label,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary)),
            ),
            Text(value, style: AppTextStyles.bodyStrong.copyWith(color: color)),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right_rounded,
                  size: AppSize.iconMd, color: AppColors.textTertiary),
            ],
          ]),
        ),
      );
}
