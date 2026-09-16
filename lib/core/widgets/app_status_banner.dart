import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_icon.dart';

class AppStatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onTap;

  const AppStatusBanner({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$title. $message. $actionLabel',
        child: Material(
          color: color.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: color.withValues(alpha: 0.2)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(children: [
                AppIconBadge(
                  icon: icon,
                  color: color,
                  backgroundColor: AppColors.surface,
                  size: 40,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: AppTextStyles.bodyStrong
                              .copyWith(color: AppColors.textPrimary)),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(message,
                          style: AppTextStyles.label
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(actionLabel,
                        style: AppTextStyles.label.copyWith(
                            color: color, fontWeight: FontWeight.w800)),
                    const SizedBox(height: AppSpacing.xxs),
                    Icon(Icons.arrow_forward_rounded,
                        size: AppSize.iconSm, color: color),
                  ],
                ),
              ]),
            ),
          ),
        ),
      );
}
