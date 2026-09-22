import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launch_utils.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../models/order_model.dart';

class ActiveOrderCard extends StatelessWidget {
  final OrderModel order;
  final int orderIndex;
  final int totalCount;
  final bool isPriority;

  const ActiveOrderCard(
      {super.key,
      required this.order,
      required this.orderIndex,
      required this.totalCount,
      required this.isPriority});

  String get _pickupName => order.storeName?.isNotEmpty == true
      ? order.storeName!
      : order.pickupPlaceName?.isNotEmpty == true
          ? order.pickupPlaceName!
          : order.pickupAddress;
  String get _deliveryName => order.deliveryPlaceName?.isNotEmpty == true
      ? order.deliveryPlaceName!
      : order.customerName?.isNotEmpty == true
          ? order.customerName!
          : order.deliveryAddress;

  void _openOrder(BuildContext context) =>
      context.go('/order/active', extra: {'orderId': order.id});

  Future<void> _navigate() async {
    final pickup = order.status == 'assigned';
    final lat = pickup ? order.pickupLat : order.deliveryLat;
    final lng = pickup ? order.pickupLng : order.deliveryLng;
    if (lat == null || lng == null) return;
    await launchNavigation(lat: lat, lng: lng);
  }

  @override
  Widget build(BuildContext context) {
    final assigned = order.status == 'assigned';
    final statusColor = assigned ? AppColors.info : AppColors.primary;
    final phone = assigned
        ? (order.pickupPhone ?? '')
        : (order.customerPhone ?? order.deliveryPhone);
    return AppSurfaceCard(
      onTap: () => _openOrder(context),
      color: const Color(0xFFFFFBF8),
      showShadow: isPriority,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AppIconBadge(
            icon: order.isBatch
                ? Icons.call_split_rounded
                : Icons.local_shipping_rounded,
            color: statusColor,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                    child: Text(
                  totalCount > 1
                      ? 'Đơn đang chạy ${orderIndex + 1}/$totalCount'
                      : 'Đơn đang thực hiện',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sectionTitle,
                )),
                if (isPriority && totalCount > 1) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const _StatusPill(label: 'Ưu tiên', color: AppColors.primary),
                ],
              ]),
              const SizedBox(height: AppSpacing.xxs),
              Text('${Fmt.orderStatus(order.status)} · #${order.code}',
                  style: AppTextStyles.label.copyWith(
                      color: statusColor, fontWeight: FontWeight.w700)),
            ],
          )),
          if (order.isBatch)
            _StatusPill(
                label: '${order.stopsCount} điểm', color: AppColors.secondary),
        ]),
        const SizedBox(height: AppSpacing.lg),
        _RouteStep(
            label: 'LẤY HÀNG',
            title: _pickupName,
            address: order.pickupAddress,
            color: AppColors.primary,
            active: assigned),
        const _RouteConnector(),
        _RouteStep(
            label: 'GIAO HÀNG',
            title: _deliveryName,
            address: order.deliveryAddress,
            color: AppColors.secondary,
            active: !assigned),
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Thu nhập dự kiến',
                  style: AppTextStyles.label
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xxs),
              Text(Fmt.currency(order.driverEarning),
                  style:
                      AppTextStyles.metric.copyWith(color: AppColors.success)),
            ],
          )),
          AppIconButton(
              icon: Icons.phone_rounded,
              tooltip: assigned ? 'Gọi điểm lấy' : 'Gọi khách hàng',
              onPressed: phone.isEmpty ? null : () => launchPhoneCall(phone),
              filled: true),
          const SizedBox(width: AppSpacing.sm),
          AppIconButton(
              icon: Icons.navigation_rounded,
              tooltip: 'Chỉ đường',
              onPressed: _navigate,
              filled: true),
        ]),
        const SizedBox(height: AppSpacing.md),
        AppButton(
            label: assigned ? 'Đi đến điểm lấy' : 'Tiếp tục giao hàng',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => _openOrder(context),
            expand: true),
      ]),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.full)),
        child: Text(label,
            style: AppTextStyles.caption
                .copyWith(fontWeight: FontWeight.w800, color: color)),
      );
}

class _RouteStep extends StatelessWidget {
  final String label;
  final String title;
  final String address;
  final Color color;
  final bool active;
  const _RouteStep(
      {required this.label,
      required this.title,
      required this.address,
      required this.color,
      required this.active});
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.only(top: 3),
              decoration: BoxDecoration(
                  color: active ? color : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 3))),
          const SizedBox(width: AppSpacing.md),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                      color: color)),
              const SizedBox(height: AppSpacing.xs),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              if (address.isNotEmpty && address != title) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ],
          )),
        ],
      );
}

class _RouteConnector extends StatelessWidget {
  const _RouteConnector();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(left: 6),
        child: SizedBox(
            height: 22,
            child: VerticalDivider(
                width: 2, thickness: 2, color: AppColors.divider)),
      );
}
