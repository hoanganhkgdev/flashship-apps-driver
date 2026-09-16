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

    final completedDate = order.completedAt?.toLocal();
    final detail = completed
        ? '${order.displayTitle} · ${order.code.startsWith('#') ? order.code : '#${order.code}'}'
        : order.code.startsWith('#')
            ? order.code
            : '#${order.code}';
    final date = completedDate == null
        ? ''
        : '${completedDate.day.toString().padLeft(2, '0')}/${completedDate.month.toString().padLeft(2, '0')}/${completedDate.year}';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, top + AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Back button
        AppBackButton(onTap: onBack ?? () => context.go('/home')),

        const SizedBox(width: AppSpacing.md),

        // Service name + code
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(
                  completed ? 'Chi tiết đơn' : order.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.screenTitle
                      .copyWith(color: AppColors.textPrimary),
                ),
              ),
              if (order.isShopOrder) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: AppSpacing.xxs),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    order.isBatch ? 'SHOP•${order.stopsCount} điểm' : 'SHOP',
                    style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 3),
            Text(
              '$detail${date.isEmpty ? '' : ' · $date'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  AppTextStyles.label.copyWith(color: AppColors.textTertiary),
            ),
          ]),
        ),

        const SizedBox(width: AppSpacing.sm),

        // Step badge / trạng thái hoàn thành
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: completed ? AppColors.successSoft : AppColors.primarySoft,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(
            completed ? 'Hoàn thành' : stepLabel,
            style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w800,
                color: completed ? AppColors.success : AppColors.primary),
          ),
        ),
      ]),
    );
  }
}
