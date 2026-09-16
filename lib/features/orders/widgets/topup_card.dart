import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_labeled_icon_action.dart';
import '../models/order_model.dart';
import 'order_card_shell.dart';

class TopupCard extends StatelessWidget {
  final OrderModel order;
  final Color color;
  final VoidCallback? onCall;
  final VoidCallback onNavigate;

  const TopupCard({
    super.key,
    required this.order,
    required this.color,
    required this.onCall,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return orderCardShell(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────────
        Text('Thông tin nạp tiền',
            style: AppTextStyles.sectionTitle
                .copyWith(color: AppColors.textPrimary)),

        // ── Amount hero ───────────────────────────────────────────
        if ((order.codAmount ?? 0) > 0) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phonelink_rounded,
                    size: 20, color: AppColors.warning),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Số tiền cần nạp',
                    style:
                        AppTextStyles.label.copyWith(color: AppColors.warning)),
                const SizedBox(height: 3),
                Text(Fmt.currency(order.codAmount!),
                    style: AppTextStyles.metricLarge
                        .copyWith(color: AppColors.warning)),
              ]),
            ]),
          ),
        ],

        const SizedBox(height: 14),
        const Divider(height: 1, color: AppColors.surfaceAlt),
        const SizedBox(height: 14),

        // ── Phone row ────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.smartphone_rounded,
                size: 16, color: AppColors.success),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('SĐT cần nạp',
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 3),
                Text(order.deliveryPhone,
                    style: AppTextStyles.metric
                        .copyWith(color: AppColors.textPrimary)),
              ])),
        ]),

        const SizedBox(height: AppSpacing.md),
        const Divider(height: 1, color: AppColors.surfaceAlt),
        const SizedBox(height: AppSpacing.md),

        // ── Location row ─────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(Icons.location_on_rounded, size: 16, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Điểm nạp tiền',
                    style: AppTextStyles.label.copyWith(color: color)),
                const SizedBox(height: 3),
                Text(order.pickupAddress,
                    style: AppTextStyles.bodyStrong
                        .copyWith(color: AppColors.textPrimary)),
              ])),
        ]),

        const SizedBox(height: AppSpacing.lg),

        // ── Action pills ─────────────────────────────────────────
        Row(children: [
          Expanded(
            child: AppLabeledIconAction(
              icon: Icons.near_me_rounded,
              label: 'Dẫn đường',
              color: AppColors.info,
              onPressed: onNavigate,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppLabeledIconAction(
              icon: Icons.call_rounded,
              label: 'Gọi điện',
              color: AppColors.success,
              onPressed: onCall,
            ),
          ),
        ]),
      ]),
    );
  }
}
