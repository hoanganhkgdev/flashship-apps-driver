import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../models/order_model.dart';

class CompletedOrderFinanceCard extends StatelessWidget {
  final OrderModel order;
  const CompletedOrderFinanceCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AppSectionHeader(
            title: 'Thanh toán',
            subtitle: 'Chi tiết tiền của đơn hàng',
            icon: Icons.account_balance_wallet_rounded,
            color: AppColors.success,
            trailing: SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('TÀI XẾ NHẬN',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textTertiary, letterSpacing: .6)),
          const SizedBox(height: AppSpacing.sm),
          Text(Fmt.currency(order.driverEarning),
              style:
                  AppTextStyles.metricLarge.copyWith(color: AppColors.success)),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          _MoneyRow(
            label: 'Phí giao hàng',
            value: Fmt.currency(order.shippingFee + order.discountAmount),
          ),
          if (order.discountAmount > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            _MoneyRow(
              label: order.voucherCode != null
                  ? 'Giảm giá (${order.voucherCode})'
                  : 'Giảm giá',
              value: '- ${Fmt.currency(order.discountAmount)}',
              color: AppColors.danger,
            ),
          ],
          if (order.bonusFee > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            _MoneyRow(
              label: 'Thưởng thêm',
              value: '+ ${Fmt.currency(order.bonusFee)}',
              color: AppColors.success,
            ),
          ],
          if (order.rainBonusEligible &&
              order.rainBonusConfirmedAmount > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            _MoneyRow(
              label: 'Thưởng trời mưa',
              value: '+ ${Fmt.currency(order.rainBonusConfirmedAmount)}',
              color: AppColors.success,
            ),
          ],
          if (order.isCod) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),
            _MoneyRow(
              label: 'Đã thu từ khách',
              value: Fmt.currency(order.customerCollectionAmount),
              color: AppColors.primary,
              strong: true,
            ),
          ],
        ]),
      );
}

class _MoneyRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool strong;

  const _MoneyRow({
    required this.label,
    required this.value,
    this.color = AppColors.textPrimary,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(label,
              style: (strong ? AppTextStyles.bodyStrong : AppTextStyles.body)
                  .copyWith(color: AppColors.textSecondary)),
        ),
        Text(value,
            style: AppTextStyles.bodyStrong.copyWith(
                color: color,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700)),
      ]);
}
