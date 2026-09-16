import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_icon.dart';

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final Widget? trailing;

  const AppSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.color = AppColors.primary,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          AppIconBadge(icon: icon, color: color, size: 40),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.sectionTitle
                        .copyWith(color: AppColors.textPrimary)),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(subtitle!,
                      style: AppTextStyles.label
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          trailing ??
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary),
        ],
      );
}
