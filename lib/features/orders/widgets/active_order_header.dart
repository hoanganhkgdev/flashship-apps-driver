import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_back_button.dart';
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
      color: const Color(0xFFFFFEFD),
      padding: EdgeInsets.fromLTRB(16, top + 16, 16, 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Back button
        AppBackButton(onTap: onBack ?? () => context.go('/home')),

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
                    fontSize: 18,
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
                    order.isBatch ? 'SHOP•${order.stopsCount} điểm' : 'SHOP',
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
              '${order.code.startsWith('#') ? order.code : '#${order.code}'}${completed ? ' · ${order.completedAt?.toLocal().day.toString().padLeft(2, '0')}/${order.completedAt?.toLocal().month.toString().padLeft(2, '0')}/${order.completedAt?.toLocal().year}' : ''}',
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: completed ? AppColors.successSoft : AppColors.primarySoft,
            borderRadius: BorderRadius.circular(22),
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
