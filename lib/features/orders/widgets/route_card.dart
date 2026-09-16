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
          padding: const EdgeInsets.only(left: 13),
          child: Container(
            width: 2,
            height: 32,
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

  // Điểm đang xử lý luôn tô cam (điểm nhấn thương hiệu cố định) — không còn
  // đổi theo màu loại dịch vụ như trước, để đồng bộ với các màn đã redesign.
  Color get _dotColor {
    if (isActive) return AppColors.primary;
    if (isDone) return AppColors.success;
    return AppColors.divider;
  }

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Timeline dot
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _dotColor.withValues(alpha: isActive || isDone ? 1.0 : 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isOrigin ? Icons.location_on_rounded : Icons.flag_rounded,
          size: 14,
          color: isActive || isDone ? Colors.white : _dotColor,
        ),
      ),

      const SizedBox(width: AppSpacing.md),

      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Stop label + quick actions
          Row(children: [
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                color: isActive ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
            const Spacer(),
            _RouteTextAction(
              label: 'Dẫn đường',
              color: AppColors.primary,
              onTap: onNav,
            ),
            if (phone != null && phone!.isNotEmpty && onCall != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Text(
                  '•',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              _RouteTextAction(
                label: 'Gọi điện',
                color: AppColors.success,
                onTap: onCall!,
              ),
            ],
          ]),

          const SizedBox(height: 5),

          // Place name
          if (placeName != null && placeName!.isNotEmpty) ...[
            Text(placeName!,
                style: AppTextStyles.sectionTitle
                    .copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.xxs),
          ],

          Text(
            address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          if (phone != null && phone!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              phone!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(color: AppColors.info),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
        ]),
      ),
    ]);
  }
}

class _RouteTextAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _RouteTextAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
}
