import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Timeline điểm lấy/giao gọn (không có nút gọi/dẫn đường như RouteCard) —
/// dùng trong order_offer_screen.
class RouteBlock extends StatelessWidget {
  final String pickupLabel;
  final String pickupAddress;
  final String? pickupPlaceName;
  final String? pickupPhone;
  final bool showNoPickupPhone;
  final String deliveryLabel;
  final String deliveryAddress;
  final String? deliveryPlaceName;
  final String? deliveryPhone;
  final String? deliveryPhoneLabel;

  const RouteBlock({
    super.key,
    required this.pickupLabel,
    required this.pickupAddress,
    this.pickupPlaceName,
    this.pickupPhone,
    this.showNoPickupPhone = false,
    required this.deliveryLabel,
    required this.deliveryAddress,
    this.deliveryPlaceName,
    this.deliveryPhone,
    this.deliveryPhoneLabel,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFEFD),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5DDD9)),
        ),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              const SizedBox(height: 4),
              Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle)),
              Expanded(
                  child: Container(
                width: 1.5,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: AppColors.divider,
              )),
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(3))),
            ]),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // Pickup
                  Text(pickupLabel,
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  if (pickupPlaceName != null && pickupPlaceName!.isNotEmpty)
                    Text(pickupPlaceName!,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  Text(pickupAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textPrimary)),
                  if (pickupPhone != null && pickupPhone!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(children: [
                        const Icon(Icons.phone_outlined,
                            size: 11, color: AppColors.info),
                        const SizedBox(width: 3),
                        Text(pickupPhone!,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.info,
                                fontWeight: FontWeight.w600)),
                      ]),
                    )
                  else if (showNoPickupPhone)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('Không có số điện thoại',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic)),
                    ),

                  const SizedBox(height: 14),

                  // Delivery
                  Text(deliveryLabel,
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  if (deliveryPlaceName != null &&
                      deliveryPlaceName!.isNotEmpty)
                    Text(deliveryPlaceName!,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  Text(deliveryAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textPrimary)),
                  if (deliveryPhone != null && deliveryPhone!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(children: [
                        const Icon(Icons.phone_outlined,
                            size: 11, color: AppColors.info),
                        const SizedBox(width: 3),
                        Text(deliveryPhone!,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.info,
                                fontWeight: FontWeight.w600)),
                        if (deliveryPhoneLabel != null) ...[
                          const Text(' · ',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                          Text(deliveryPhoneLabel!,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ],
                      ]),
                    ),
                ])),
          ]),
        ),
      );
}
