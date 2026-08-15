import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
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
                  ? const Color(0xFFE0E0E0)
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
    return const Color(0xFFE0E0E0);
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

      const SizedBox(width: 12),

      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Label + active badge
          Row(children: [
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.primary : AppColors.textTertiary,
                )),
            if (isActive) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Đang đến',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    )),
              ),
            ],
          ]),

          const SizedBox(height: 5),

          // Place name
          if (placeName != null && placeName!.isNotEmpty) ...[
            Text(placeName!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                )),
            const SizedBox(height: 2),
          ],

          // Address
          Text(address,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              )),

          // Phone — tappable
          if (phone != null && phone!.isNotEmpty) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: onCall,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_rounded,
                      size: 11, color: AppColors.info),
                ),
                const SizedBox(width: 6),
                Text(phone!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.info,
                    )),
              ]),
            ),
          ],

          const SizedBox(height: 12),

          // Action pill buttons — outline xám, chỉ icon có màu, không cạnh
          // tranh thị giác với nút hành động chính cam đặc ở cuối màn hình.
          Row(children: [
            PillBtn(
              icon: Icons.near_me_rounded,
              label: 'Dẫn đường',
              color: AppColors.primary,
              onTap: onNav,
            ),
            if (onCall != null) ...[
              const SizedBox(width: 8),
              PillBtn(
                icon: Icons.call_rounded,
                label: 'Gọi điện',
                color: AppColors.success,
                onTap: onCall,
              ),
            ],
          ]),

          const SizedBox(height: 4),
        ]),
      ),
    ]);
  }
}

// Nút phụ outline — nền trong suốt, viền xám, chỉ icon tô màu theo [color],
// chữ luôn xám đậm. Trước đây nền+viền+chữ đều tô theo [color] (cam/xanh
// mint đặc), nay chỉ icon giữ màu để nút hành động chính cam ở cuối màn hình
// vẫn là điểm nhấn mạnh nhất, duy nhất trên màn hình.
class PillBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const PillBtn(
      {super.key,
      required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                )),
          ]),
        ),
      );
}
