import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/order_model.dart';
import 'order_card_shell.dart';

class EarningCard extends StatelessWidget {
  final OrderModel order;
  final Color color;
  const EarningCard({super.key, required this.order, required this.color});

  @override
  Widget build(BuildContext context) {
    return orderCardShell(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.payments_rounded,
              size: 19,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tiền đơn hàng', style: AppTextStyles.sectionTitle),
                const SizedBox(height: 2),
                Text(
                  'Tài xế nhận',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            Fmt.currency(order.driverEarning),
            style: AppTextStyles.metricLarge.copyWith(
              color: AppColors.success,
            ),
          ),
        ]),

        if (order.hasDiscount && order.discountAmount > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              order.driverEarning == 0
                  ? 'Cộng vào ví sau khi hoàn thành'
                  : '+ ${Fmt.currency(order.discountAmount)} cộng vào ví',
              style: AppTextStyles.caption.copyWith(color: AppColors.success),
            ),
          ),
        ],

        if (order.isCod) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Cần thu khách',
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                Fmt.currency(order.customerCollectionAmount),
                style: AppTextStyles.metric.copyWith(color: AppColors.primary),
              ),
            ]),
          ),
          if (order.nightSurcharge > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Đã gồm ${Fmt.currency(order.nightSurcharge)} phụ phí đêm',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],

        const SizedBox(height: AppSpacing.md),
        const Divider(height: 1, color: AppColors.surfaceAlt),
        const SizedBox(height: AppSpacing.sm),

        FeeRow(
          label: 'Phí giao hàng',
          value: Fmt.currency(order.shippingFee + order.discountAmount),
        ),
        // Phụ phí đêm khuya đã được cộng sẵn vào "Phí giao hàng" ở trên (backend
        // tính fee = base + surcharge) — hiện tách dòng để tài xế biết vì sao
        // phí cao hơn bình thường, không phải cộng thêm vào tổng.
        if (order.nightSurcharge > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          FeeRow(
            label: 'Gồm phụ phí đêm',
            value: Fmt.currency(order.nightSurcharge),
            valueColor: AppColors.textSecondary,
          ),
        ],
        if (order.hasDiscount) ...[
          const SizedBox(height: AppSpacing.xs),
          FeeRow(
            label: order.voucherCode != null
                ? 'Giảm giá (${order.voucherCode})'
                : 'Giảm giá',
            value: '- ${Fmt.currency(order.discountAmount)}',
            valueColor: AppColors.danger,
          ),
        ],
        if (order.bonusFee > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          FeeRow(
            label: 'Thưởng thêm',
            value: '+ ${Fmt.currency(order.bonusFee)}',
            valueColor: AppColors.success,
          ),
        ],
        if (order.rainBonusEligible && order.rainBonusConfirmedAmount > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          FeeRow(
            label: 'Thưởng trời mưa',
            value: '+ ${Fmt.currency(order.rainBonusConfirmedAmount)}',
            valueColor: AppColors.success,
          ),
        ],

        if (order.serviceType == 'shopping' && (order.codAmount ?? 0) > 0) ...[
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.surfaceAlt),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(children: [
              const Icon(
                Icons.shopping_cart_checkout_rounded,
                size: 18,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Tiền ứng mua hàng',
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                Fmt.currency(order.codAmount!),
                style: AppTextStyles.metric.copyWith(color: AppColors.warning),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class FeeRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const FeeRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(label,
              style:
                  AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
        ),
        Text(value,
            style: AppTextStyles.label.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
            )),
      ]);
}
