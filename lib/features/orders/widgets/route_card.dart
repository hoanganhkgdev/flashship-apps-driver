import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_section_header.dart';
import '../models/order_model.dart';
import 'order_card_shell.dart';

class RouteCard extends StatelessWidget {
  final OrderModel order;
  final bool isPickup;
  final bool isRide;
  final VoidCallback? onCallPickup;
  final VoidCallback onNavPickup;
  final VoidCallback? onCallDelivery;
  final VoidCallback onNavDelivery;

  const RouteCard({
    super.key,
    required this.order,
    required this.isPickup,
    required this.isRide,
    required this.onCallPickup,
    required this.onNavPickup,
    required this.onCallDelivery,
    required this.onNavDelivery,
  });

  String get _pickupLabel => switch (order.serviceType) {
        'shopping' => 'Điểm mua hàng',
        'bike' => 'Điểm đón khách',
        'motor' => 'Vị trí xe máy',
        'car' => 'Vị trí ô tô',
        _ => 'Điểm lấy hàng',
      };

  String get _deliveryLabel => isRide ? 'Điểm đến' : 'Điểm giao hàng';

  @override
  Widget build(BuildContext context) {
    final pickupPhone = isRide
        ? (order.deliveryPhone.isNotEmpty ? order.deliveryPhone : null)
        : order.pickupPhone;
    final deliveryPhone = isRide
        ? null
        : (order.deliveryPhone.isNotEmpty ? order.deliveryPhone : null);

    final pickupPlace = order.isShopOrder
        ? (order.storeName?.isNotEmpty == true
            ? order.storeName
            : order.pickupPlaceName)
        : order.pickupPlaceName;
    final deliveryPlace = order.deliveryPlaceName?.isNotEmpty == true
        ? order.deliveryPlaceName
        : order.customerName;

    return orderCardShell(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppSectionHeader(
          title: isPickup ? 'Đi đến điểm lấy' : 'Đi đến điểm giao',
          subtitle: isPickup
              ? 'Lấy hàng trước khi bắt đầu giao'
              : 'Hàng đã lấy, tiếp tục giao cho khách',
          icon: isPickup ? Icons.storefront_rounded : Icons.route_rounded,
          color: isPickup ? AppColors.primary : AppColors.secondary,
          trailing: const SizedBox.shrink(),
        ),
        const SizedBox(height: AppSpacing.xl),
        // ── Pickup stop ────────────────────────────────────────────
        RouteStop(
          isOrigin: true,
          isActive: isPickup,
          isDone: !isPickup,
          label: _pickupLabel,
          placeName: pickupPlace,
          address: order.pickupAddress,
          phone: pickupPhone,
          onCall: onCallPickup,
          onNav: onNavPickup,
        ),

        // ── Connector ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: 29),
          child: Container(
            width: 2,
            height: 10,
            decoration: BoxDecoration(
              color: isPickup
                  ? AppColors.divider
                  : AppColors.success.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),

        // ── Delivery stop ──────────────────────────────────────────
        RouteStop(
          isOrigin: false,
          isActive: !isPickup,
          isDone: false,
          label: _deliveryLabel,
          placeName: deliveryPlace,
          address: order.deliveryAddress,
          phone: deliveryPhone,
          onCall: onCallDelivery,
          onNav: onNavDelivery,
        ),
      ]),
    );
  }
}

class RouteStop extends StatelessWidget {
  final bool isOrigin;
  final bool isActive;
  final bool isDone;
  final String label;
  final String? placeName;
  final String address;
  final String? phone;
  final VoidCallback? onCall;
  final VoidCallback onNav;

  const RouteStop({
    super.key,
    required this.isOrigin,
    required this.isActive,
    required this.isDone,
    required this.label,
    this.placeName,
    required this.address,
    required this.phone,
    required this.onCall,
    required this.onNav,
  });

  // Điểm đang xử lý tô cam (điểm nhấn thương hiệu), điểm đã xong xanh lá,
  // điểm chưa tới xám.
  Color get _color {
    if (isActive) return AppColors.primary;
    if (isDone) return AppColors.success;
    return AppColors.textTertiary;
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = phone != null && phone!.isNotEmpty && onCall != null;
    return Container(
      // Padding cố định để icon các điểm luôn thẳng hàng với đường nối.
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: isActive
          ? BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            )
          : null,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive || isDone ? _color : _color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          ),
          child: Icon(
            isDone
                ? Icons.check_rounded
                : isOrigin
                    ? Icons.storefront_rounded
                    : Icons.flag_rounded,
            size: 19,
            color: isActive || isDone ? Colors.white : _color,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(),
                style: AppTextStyles.caption.copyWith(
                    color: isActive ? AppColors.primaryDark : _color,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5)),
            const SizedBox(height: 3),
            if (placeName != null && placeName!.isNotEmpty)
              Text(placeName!,
                  style: AppTextStyles.sectionTitle
                      .copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary)),
            if (phone != null && phone!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(phone!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(color: AppColors.info)),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              _StopAction(
                  icon: Icons.navigation_rounded,
                  label: 'Dẫn đường',
                  color: AppColors.primary,
                  strong: isActive,
                  onTap: onNav),
              if (hasPhone) ...[
                const SizedBox(width: AppSpacing.sm),
                _StopAction(
                    icon: Icons.phone_rounded,
                    label: 'Gọi điện',
                    color: AppColors.success,
                    strong: isActive,
                    onTap: onCall!),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _StopAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  // Ở điểm đang xử lý: nút đặc màu (bấm nhiều nhất), điểm khác: pill nhạt.
  final bool strong;
  final VoidCallback onTap;

  const _StopAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.strong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = strong ? Colors.white : color;
    return Material(
      color: strong ? color : color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 5),
            Text(label,
                style: AppTextStyles.label
                    .copyWith(color: fg, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}
