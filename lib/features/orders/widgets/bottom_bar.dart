import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/order_model.dart';
import 'swipe_button.dart';

class BottomBar extends StatelessWidget {
  final OrderModel order;
  final bool actionLoading;
  final VoidCallback? onAction;

  const BottomBar({
    super.key,
    required this.order,
    required this.actionLoading,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    if (onAction == null) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      // Điểm nhấn cam mạnh nhất và duy nhất trên màn hình — luôn cố định
      // AppColors.primary, không còn đổi theo màu dịch vụ/trạng thái nữa.
      child: SwipeButton(
        label: order.nextAction,
        color: AppColors.primary,
        loading: actionLoading,
        onConfirm: onAction,
      ),
    );
  }
}
