import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_metric_tile.dart';
import '../../../core/widgets/app_surface_card.dart';

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
          AppSpacing.sm,
        ),
        child: AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hoạt động hôm nay',
                style: AppTextStyles.sectionTitle,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(children: [
                Expanded(
                  child: AppMetricTile(
                    label: 'Đơn hôm nay',
                    value: '$todayCount',
                    icon: Icons.inventory_2_rounded,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(
                  height: 42,
                  child: VerticalDivider(
                      width: AppSpacing.xl2, color: AppColors.divider),
                ),
                Expanded(
                  child: AppMetricTile(
                    label: 'Thu nhập hôm nay',
                    value: Fmt.currency(todayEarnings),
                    icon: Icons.payments_rounded,
                    color: AppColors.success,
                  ),
                ),
              ]),
            ],
          ),
        ),
      );
}
