import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../models/order_model.dart';

class HistoryDateLabel extends StatelessWidget {
  final String label;
  const HistoryDateLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs, AppSpacing.lg, AppSpacing.xs, AppSpacing.sm),
        child: Text(label,
            style: AppTextStyles.bodyStrong
                .copyWith(color: AppColors.textSecondary)),
      );
}

class HistoryCompletedCard extends StatelessWidget {
  final OrderModel order;
  const HistoryCompletedCard({super.key, required this.order});

  String get _pickup => order.storeName?.isNotEmpty == true
      ? order.storeName!
      : order.pickupPlaceName?.isNotEmpty == true
          ? order.pickupPlaceName!
          : order.pickupAddress;
  String get _delivery => order.deliveryPlaceName?.isNotEmpty == true
      ? order.deliveryPlaceName!
      : order.customerName?.isNotEmpty == true
          ? order.customerName!
          : order.deliveryAddress;

  @override
  Widget build(BuildContext context) {
    final color = Fmt.serviceColor(order.serviceType);
    final local = (order.completedAt ?? order.createdAt).toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return AppSurfaceCard(
      onTap: () => context.push('/order/completed', extra: order),
      child: Column(children: [
        Row(children: [
          AppIconBadge(icon: Fmt.serviceIcon(order.serviceType), color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong
                        .copyWith(color: AppColors.textPrimary)),
                const SizedBox(height: AppSpacing.xxs),
                Text('$time · #${order.code}',
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.textTertiary)),
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(Fmt.currency(order.driverEarning),
                style: AppTextStyles.sectionTitle
                    .copyWith(color: AppColors.success)),
            const SizedBox(height: AppSpacing.xxs),
            Text('Hoàn thành',
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.success)),
          ]),
        ]),
        const SizedBox(height: AppSpacing.md),
        const Divider(height: 1),
        const SizedBox(height: AppSpacing.md),
        _HistoryRoute(
            icon: Icons.radio_button_checked_rounded,
            text: _pickup,
            color: AppColors.primary),
        const Padding(
          padding: EdgeInsets.only(left: 9),
          child: SizedBox(
              height: 14,
              child: VerticalDivider(
                  width: 2, thickness: 2, color: AppColors.divider)),
        ),
        _HistoryRoute(
            icon: Icons.location_on_rounded,
            text: _delivery,
            color: AppColors.secondary),
      ]),
    );
  }
}

class _HistoryRoute extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _HistoryRoute(
      {required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label
                    .copyWith(color: AppColors.textSecondary))),
        const Icon(Icons.chevron_right_rounded,
            size: AppSize.iconMd, color: AppColors.textTertiary),
      ]);
}
