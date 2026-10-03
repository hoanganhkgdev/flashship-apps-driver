import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_surface_card.dart';

/// Tóm tắt hôm nay: hai ô số liệu cạnh nhau (số đơn, thu nhập).
class HistoryOverviewHeader extends StatelessWidget {
  final int todayCount;
  final int todayEarnings;

  const HistoryOverviewHeader({
    super.key,
    required this.todayCount,
    required this.todayEarnings,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        child: Row(children: [
          Expanded(
            child: _OverviewTile(
              icon: Icons.inventory_2_rounded,
              color: AppColors.secondary,
              label: 'Đơn hôm nay',
              value: '$todayCount',
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _OverviewTile(
              icon: Icons.payments_rounded,
              color: AppColors.success,
              label: 'Thu nhập hôm nay',
              value: Fmt.currency(todayEarnings),
            ),
          ),
        ]),
      );
}

class _OverviewTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _OverviewTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
        color: Colors.white,
        showBorder: false,
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: AppTextStyles.metric
                          .copyWith(color: AppColors.textPrimary)),
                ),
                const SizedBox(height: 2),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ]),
      );
}
