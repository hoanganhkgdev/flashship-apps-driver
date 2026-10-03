import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_back_button.dart';
import '../models/order_model.dart';

class ActiveOrderHeader extends StatelessWidget {
  final OrderModel order;
  final Color color;
  // Đơn đã hoàn thành → hiện badge "Hoàn thành" xanh thay cho tiến trình
  // 2 bước, và back quay lại đúng màn trước đó thay vì luôn về /home.
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
    final code = order.code.startsWith('#') ? order.code : '#${order.code}';
    final inPickup = order.status == 'assigned';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Color(0x181B1411), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, top + AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          AppBackButton(onTap: onBack ?? () => context.go('/home')),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(
                    completed ? 'Chi tiết đơn' : order.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.screenTitle.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                if (order.isShopOrder) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: AppSpacing.xxs),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      order.isBatch
                          ? 'SHOP • ${order.stopsCount} điểm'
                          : 'SHOP',
                      style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text(code,
                  style: AppTextStyles.label
                      .copyWith(color: AppColors.textTertiary)),
            ]),
          ),
          if (completed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text('Hoàn thành',
                  style: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.w800, color: AppColors.success)),
            ),
        ]),
        if (!completed) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(children: [
            Expanded(
              child: _StepBar(
                label: 'Lấy hàng',
                state: inPickup ? _StepState.active : _StepState.done,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StepBar(
                label: 'Giao hàng',
                state: inPickup ? _StepState.todo : _StepState.active,
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

enum _StepState { done, active, todo }

class _StepBar extends StatelessWidget {
  final String label;
  final _StepState state;
  const _StepBar({required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _StepState.done => AppColors.success,
      _StepState.active => AppColors.primary,
      _StepState.todo => AppColors.divider,
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        height: 6,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
      ),
      const SizedBox(height: 6),
      Row(children: [
        if (state == _StepState.done)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.check_circle_rounded,
                size: 14, color: AppColors.success),
          ),
        Text(label,
            style: AppTextStyles.label.copyWith(
                fontWeight: state == _StepState.active
                    ? FontWeight.w800
                    : FontWeight.w600,
                color: state == _StepState.todo
                    ? AppColors.textTertiary
                    : color == AppColors.primary
                        ? AppColors.primaryDark
                        : AppColors.success)),
      ]),
    ]);
  }
}
