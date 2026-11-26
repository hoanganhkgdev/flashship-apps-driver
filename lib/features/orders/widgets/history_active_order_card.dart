import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import 'running_order_card.dart';

/// Thẻ đơn đã nhận: giữ trạng thái và thao tác (vuốt đổi bước, xác nhận hoàn
/// thành, đơn gộp); giao diện ở [RunningOrderView].
class ActiveOrderCard extends ConsumerStatefulWidget {
  final OrderModel order;
  final int orderIndex;
  final int totalCount;
  final bool isPriority;

  const ActiveOrderCard({
    super.key,
    required this.order,
    required this.orderIndex,
    required this.totalCount,
    required this.isPriority,
  });

  @override
  ConsumerState<ActiveOrderCard> createState() => _ActiveOrderCardState();
}

class _ActiveOrderCardState extends ConsumerState<ActiveOrderCard> {
  bool _actionLoading = false;

  OrderModel get order => widget.order;
  int get orderIndex => widget.orderIndex;
  int get totalCount => widget.totalCount;
  bool get isPriority => widget.isPriority;

  Future<void> _handleAction() async {
    if (_actionLoading || order.nextAction.isEmpty) return;
    final wasCompleting = order.status == 'processing';
    final orderId = order.id;
    final orderCode = order.code;
    final nextStatus = order.nextStatus;
    if (wasCompleting) {
      final noun = Fmt.claimNoun(order.serviceType);
      final completionMessage = switch (order.serviceType) {
        'topup' => 'Xác nhận đã nạp tiền xong cho đơn #$orderCode.',
        'bike' => 'Xác nhận đã chở khách đến nơi cho cuốc #$orderCode.',
        'motor' ||
        'car' =>
          'Xác nhận đã lái khách và xe đến nơi cho cuốc #$orderCode.',
        _ => 'Xác nhận đã giao xong đơn #$orderCode.',
      };
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text('Hoàn thành $noun?'),
              content: Text(completionMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Chưa'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Hoàn thành'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed || !mounted) return;
    }

    setState(() => _actionLoading = true);
    String? error;
    if (wasCompleting) {
      error = await ref.read(activeOrderProvider.notifier).complete(orderId);
    } else {
      error = await ref
          .read(activeOrderProvider.notifier)
          .updateOrderStatus(nextStatus, orderId: orderId);
    }
    if (!mounted) return;
    setState(() => _actionLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              (wasCompleting
                  ? 'Hoàn thành đơn hàng!'
                  : 'Đã cập nhật trạng thái đơn.'),
        ),
        backgroundColor: error == null ? AppColors.success : AppColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => RunningOrderView(
        order: order,
        positionLabel:
            totalCount > 1 ? 'ĐƠN ${orderIndex + 1}/$totalCount' : null,
        actionLoading: _actionLoading,
        onAction: _handleAction,
        onBatchCompleted: _onBatchCompleted,
      );

  Future<void> _onBatchCompleted() async {
    await ref.read(activeOrderProvider.notifier).fetch();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hoàn thành tất cả điểm giao!'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}
