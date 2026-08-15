import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../models/order_model.dart';

class ActiveOrderHeader extends StatelessWidget {
  final OrderModel order;
  final Color color;
  // Đơn đã hoàn thành (xem lại từ lịch sử) → hiện badge "Hoàn thành" xanh
  // thay vì "Bước X/Y" cam, và back quay lại đúng màn trước đó (pop) thay vì
  // luôn về thẳng /home như luồng đơn đang active.
  final bool completed;
  final VoidCallback? onBack;

  const ActiveOrderHeader({
    super.key,
    required this.order,
    required this.color,
    this.completed = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final stepLabel = order.status == 'assigned' ? 'Bước 1/2' : 'Bước 2/2';

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Back button
        GestureDetector(
          onTap: onBack ?? () => context.go('/home'),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary,
              size: 16,
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Service name + code
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(
                  order.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (order.isShopOrder) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    order.isBatch ? 'SHOP•${order.stopsCount}đ' : 'SHOP',
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 3),
            Text(
              '#${order.code}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
          ]),
        ),

        const SizedBox(width: 8),

        // Step badge / trạng thái hoàn thành
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: completed ? AppColors.successSoft : AppColors.primarySoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            completed ? 'Hoàn thành' : stepLabel,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: completed ? AppColors.success : AppColors.primary),
          ),
        ),
      ]),
    );
  }
}
