import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import 'swipe_button.dart';

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

  // Cùng logic gọi API với BottomBar/_handleAction ở active_order_screen.dart
  // (status 'processing' → complete(), còn lại → updateOrderStatus()) — chỉ
  // thêm 1 lối gọi nữa từ card danh sách, không đổi API/luồng dispatch.
  Future<void> _handleAction() async {
    final order = widget.order;
    setState(() => _actionLoading = true);
    final notifier = ref.read(activeOrderProvider.notifier);
    final ok = order.status == 'processing'
        ? await notifier.complete(order.id)
        : await notifier.updateOrderStatus(order.nextStatus, orderId: order.id);
    if (mounted) {
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Không thể cập nhật đơn. Vui lòng thử lại.'),
          backgroundColor: AppColors.danger,
        ));
      }
      setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isPriority = widget.isPriority;
    final color = Fmt.serviceColor(order.serviceType);
    final earning = order.driverEarning;
    final distance = Fmt.distanceKm(
        order.pickupLat, order.pickupLng, order.deliveryLat, order.deliveryLng);
    final canAct = isPriority && order.nextAction.isNotEmpty;

    return GestureDetector(
      onTap: () => context.go(
        '/order/active',
        extra: {'orderId': order.id},
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPriority ? AppColors.primary : AppColors.divider,
            width: isPriority ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isPriority ? 0.08 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          // ── Header (nền cam nhạt nếu là đơn ưu tiên) ──────────────
          // Bo góc trên riêng cho đúng bán kính bo ngoài trừ đi bề dày viền —
          // nếu chỉ dựa vào clipBehavior của Container ngoài, phần nền cam
          // full-width này vẽ đè lên đúng chỗ viền bo góc, làm viền như biến
          // mất ở 2 góc trên.
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isPriority ? AppColors.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(isPriority ? 14.5 : 15),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:
                        isPriority ? AppColors.primary : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Đơn ${widget.orderIndex + 1}/${widget.totalCount}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color:
                          isPriority ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (isPriority) ...[
                  const SizedBox(width: 6),
                  const Text('Đang xử lý',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      )),
                ],
              ]),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Fmt.serviceIcon(order.serviceType),
                      color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(order.displayTitle,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              )),
                          if (order.isShopOrder) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                order.isBatch
                                    ? 'SHOP·${order.stopsCount}đ'
                                    : 'SHOP',
                                style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white),
                              ),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          Text(Fmt.orderStatus(order.status),
                              style: TextStyle(
                                fontSize: 11,
                                color: color,
                                fontWeight: FontWeight.w600,
                              )),
                        ]),
                      ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(Fmt.currency(earning),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.success,
                      )),
                  const Text('thu nhập',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.textTertiary)),
                ]),
              ]),
            ]),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Divider(height: 1, color: Color(0xFFF5F5F5)),
          ),

          // ── Route ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 1.5,
                  height: 34,
                  color: const Color(0xFFE0E0E0),
                  margin: const EdgeInsets.symmetric(vertical: 3),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ]),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pickup place
                      if ((order.isShopOrder
                              ? (order.storeName?.isNotEmpty == true
                                  ? order.storeName!
                                  : order.pickupPlaceName ?? '')
                              : (order.pickupPlaceName ?? ''))
                          case final String p when p.isNotEmpty) ...[
                        Text(p,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            )),
                        const SizedBox(height: 1),
                      ],
                      Text(order.pickupAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          )),
                      const SizedBox(height: 2),
                      const Text('Điểm lấy hàng',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textTertiary,
                          )),
                      const SizedBox(height: 14),
                      // Delivery place / customer name
                      if ((order.deliveryPlaceName?.isNotEmpty == true
                              ? order.deliveryPlaceName!
                              : (order.customerName ?? ''))
                          case final String d when d.isNotEmpty) ...[
                        Text(d,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            )),
                        const SizedBox(height: 1),
                      ],
                      Text(order.deliveryAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          )),
                      const SizedBox(height: 2),
                      Text(
                          distance != null
                              ? 'Điểm giao · cách $distance'
                              : 'Điểm giao',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textTertiary,
                          )),
                    ]),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary, size: 18),
            ]),
          ),

          // ── Hành động ──────────────────────────────────────────────
          if (canAct)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: SwipeButton(
                label: order.nextAction,
                color: AppColors.primary,
                loading: _actionLoading,
                onConfirm: _handleAction,
              ),
            )
          else if (!isPriority)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go(
                    '/order/active',
                    extra: {'orderId': order.id},
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.divider),
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Xem chi tiết',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// Banner giới hạn số đơn active — nằm cuối SliverList cùng các card, KHÔNG
// tách khối riêng cách xa như trước. Text đổi động theo số đơn đang nhận.
class MaxOrdersBanner extends StatelessWidget {
  final int activeCount;
  const MaxOrdersBanner({super.key, required this.activeCount});

  static const _max = 2;

  String get _text {
    if (activeCount <= 0) {
      return 'Chưa có đơn. Bạn có thể nhận tối đa $_max đơn cùng lúc.';
    }
    if (activeCount >= _max) {
      return 'Bạn đang nhận tối đa $activeCount/$_max đơn cho phép.';
    }
    return 'Bạn đang nhận $activeCount/$_max đơn cho phép.';
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1CC),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: Color(0xFF17110F)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_text,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFFB77300), height: 1.4)),
          ),
        ]),
      );
}

class DateLabel extends StatelessWidget {
  final String label;
  const DateLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
        child: Text(label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            )),
      );
}

class CompletedOrderCard extends StatelessWidget {
  final OrderModel order;
  const CompletedOrderCard({super.key, required this.order});

  String get _pickupName => order.isShopOrder
      ? (order.storeName?.isNotEmpty == true
          ? order.storeName!
          : order.pickupPlaceName ?? '')
      : (order.pickupPlaceName ?? '');

  String get _deliveryName => order.deliveryPlaceName?.isNotEmpty == true
      ? order.deliveryPlaceName!
      : (order.customerName ?? '');

  @override
  Widget build(BuildContext context) {
    final color = Fmt.serviceColor(order.serviceType);
    final earning = order.driverEarning;
    final local = (order.completedAt ?? order.createdAt).toLocal();
    final timeStr =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () => context.push('/order/completed', extra: order),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Service icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Fmt.serviceIcon(order.serviceType),
                    color: color, size: 20),
              ),

              const SizedBox(width: 12),

              // Title + time
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.displayTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          )),
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.access_time_rounded,
                            size: 11, color: AppColors.textTertiary),
                        const SizedBox(width: 3),
                        Text(timeStr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            )),
                        const SizedBox(width: 6),
                        Text('• #${order.code}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            )),
                      ]),
                    ]),
              ),

              // Earning + status
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  Fmt.currency(earning),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: earning > 0
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (order.isCompleted
                            ? AppColors.success
                            : AppColors.danger)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.isCompleted ? 'Hoàn thành' : 'Đã hủy',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: order.isCompleted
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                  ),
                ),
              ]),
            ]),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Divider(height: 20, color: Color(0xFFF5F5F5)),
          ),

          // Route
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 1.5,
                  height: 14,
                  color: const Color(0xFFE0E0E0),
                  margin: const EdgeInsets.symmetric(vertical: 3),
                ),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ]),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pickup
                      if (_pickupName case final String p
                          when p.isNotEmpty) ...[
                        Text(p,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            )),
                        const SizedBox(height: 1),
                      ],
                      Text(order.pickupAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: _pickupName.isNotEmpty
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          )),
                      const SizedBox(height: 12),
                      // Delivery
                      if (_deliveryName case final String d
                          when d.isNotEmpty) ...[
                        Text(d,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            )),
                        const SizedBox(height: 1),
                      ],
                      Text(order.deliveryAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: _deliveryName.isNotEmpty
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          )),
                    ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
