import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/order_model.dart';

class OfferHeader extends StatelessWidget {
  final OrderModel order;
  final int remaining;
  final double progress;
  final bool isUrgent;
  final Animation<double> pulse;
  final double topInset;

  const OfferHeader({
    super.key,
    required this.order,
    required this.remaining,
    required this.progress,
    required this.isUrgent,
    required this.pulse,
    required this.topInset,
  });

  @override
  Widget build(BuildContext context) {
    final timerColor = isUrgent ? AppColors.danger : AppColors.primary;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        topInset + AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Color(0x0F1B1411),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Đơn mới', style: AppTextStyles.screenTitle),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  order.code,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: pulse,
            builder: (context, child) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: timerColor.withValues(
                  alpha: isUrgent ? .10 + pulse.value * .08 : .10,
                ),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.timer_outlined, size: 17, color: timerColor),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '$remaining giây',
                  style: AppTextStyles.bodyStrong.copyWith(color: timerColor),
                ),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: AppColors.surfaceAlt,
            color: timerColor,
          ),
        ),
      ]),
    );
  }
}
