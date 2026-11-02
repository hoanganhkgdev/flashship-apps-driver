import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launch_utils.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import 'batch_stops_card.dart';
import 'call_center_pickup_details.dart';
import 'formatted_note.dart';
import 'info_row.dart' show CargoBadge;
import 'shopping_order_note.dart';
import 'swipe_button.dart';

/// Thẻ đơn đã nhận, ưu tiên trạng thái, điểm đến và thao tác tiếp theo.
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

  String get _pickupName => order.storeName?.isNotEmpty == true
      ? order.storeName!
      : order.pickupPlaceName?.isNotEmpty == true
          ? order.pickupPlaceName!
          : order.pickupAddress;

  String get _deliveryName => order.deliveryPlaceName?.isNotEmpty == true
      ? order.deliveryPlaceName!
      : order.customerName?.isNotEmpty == true
          ? order.customerName!
          : order.deliveryAddress;

  Future<void> _navigateTo({required bool pickup}) => launchNavigation(
        lat: pickup ? order.pickupLat : order.deliveryLat,
        lng: pickup ? order.pickupLng : order.deliveryLng,
        address: pickup ? order.pickupAddress : order.deliveryAddress,
      );

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
      final ok = await ref
          .read(activeOrderProvider.notifier)
          .updateOrderStatus(nextStatus, orderId: orderId);
      if (!ok) error = 'Không thể cập nhật trạng thái đơn.';
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
  Widget build(BuildContext context) {
    final assigned = order.status == 'assigned';
    final statusColor = assigned ? AppColors.info : AppColors.primary;
    final serviceColor = Fmt.serviceColor(order.serviceType);
    if (order.isCallCenter) {
      return _CallCenterRunningCard(
        order: order,
        statusColor: statusColor,
        positionLabel:
            totalCount > 1 ? 'ĐƠN ${orderIndex + 1}/$totalCount' : null,
        actionLoading: _actionLoading,
        onNavigatePickup: () => _navigateTo(pickup: true),
        onAction: _handleAction,
      );
    }
    if (order.isCustomerApp) {
      return _CustomerAppRunningCard(
        order: order,
        pickupName: _pickupName,
        deliveryName: _deliveryName,
        statusColor: statusColor,
        serviceColor: serviceColor,
        positionLabel:
            totalCount > 1 ? 'ĐƠN ${orderIndex + 1}/$totalCount' : null,
        actionLoading: _actionLoading,
        onNavigatePickup: () => _navigateTo(pickup: true),
        onNavigateDelivery: () => _navigateTo(pickup: false),
        onAction: _handleAction,
      );
    }
    if (order.isShopOrder) {
      return _ShopRunningCard(
        order: order,
        pickupName: _pickupName,
        deliveryName: _deliveryName,
        statusColor: statusColor,
        isPriority: isPriority,
        positionLabel:
            totalCount > 1 ? 'ĐƠN ${orderIndex + 1}/$totalCount' : null,
        actionLoading: _actionLoading,
        onNavigatePickup: () => _navigateTo(pickup: true),
        onNavigateDelivery: () => _navigateTo(pickup: false),
        onAction: _handleAction,
        onBatchCompleted: _onBatchCompleted,
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: statusColor.withValues(alpha: .16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            order: order,
            serviceColor: serviceColor,
            statusColor: statusColor,
            positionLabel:
                totalCount > 1 ? 'ĐƠN ${orderIndex + 1}/$totalCount' : null,
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CurrentTask(
                  assigned: assigned,
                  color: statusColor,
                  isPriority: isPriority,
                ),
                const SizedBox(height: AppSpacing.md),
                _Route(
                  pickupName: _pickupName,
                  pickupAddress: order.pickupAddress,
                  pickupPhone: order.pickupPhone,
                  deliveryName: _deliveryName,
                  deliveryAddress: order.deliveryAddress,
                  deliveryPhone: order.deliveryPhone,
                  onNavigatePickup: () => _navigateTo(pickup: true),
                  onNavigateDelivery: () => _navigateTo(pickup: false),
                  assigned: assigned,
                  color: serviceColor,
                ),
                if (order.orderNote?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: AppSpacing.md),
                  _OrderNote(note: order.orderNote!.trim()),
                ],
                if (_hasDetails) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if (order.distance != null && order.distance! > 0)
                        _DetailChip(
                          icon: Icons.route_rounded,
                          label:
                              'Quãng đường ${order.distance!.toStringAsFixed(1)} km',
                          color: AppColors.info,
                        ),
                      if (order.codAmount != null && order.codAmount! > 0)
                        _DetailChip(
                          icon: Icons.payments_rounded,
                          label: 'Thu hộ ${Fmt.currency(order.codAmount!)}',
                          color: AppColors.warning,
                        ),
                      if (order.voucherCode?.trim().isNotEmpty == true)
                        _DetailChip(
                          icon: Icons.confirmation_number_rounded,
                          label: order.discountAmount > 0
                              ? 'Voucher ${order.voucherCode} · giảm ${Fmt.currency(order.discountAmount)}'
                              : 'Voucher ${order.voucherCode}',
                          color: AppColors.secondary,
                        ),
                      if (order.bonusFee > 0)
                        _DetailChip(
                          icon: Icons.add_circle_rounded,
                          label: 'Thưởng thêm +${Fmt.currency(order.bonusFee)}',
                          color: AppColors.success,
                        ),
                      if (order.nightSurcharge > 0)
                        _DetailChip(
                          icon: Icons.nightlight_round,
                          label:
                              'Phụ phí đêm ${Fmt.currency(order.nightSurcharge)}',
                          color: const Color(0xFF6655B5),
                        ),
                      if (order.rainBonusEligible &&
                          order.rainBonusConfirmedAmount > 0)
                        _DetailChip(
                          icon: Icons.water_drop_rounded,
                          label:
                              'Thưởng mưa +${Fmt.currency(order.rainBonusConfirmedAmount)}',
                          color: AppColors.info,
                        ),
                      if (order.isBatch)
                        _DetailChip(
                          icon: Icons.call_split_rounded,
                          label: '${order.stopsCount} điểm giao',
                          color: AppColors.secondary,
                        ),
                    ],
                  ),
                ],
                if (order.isBatch &&
                    order.status == 'processing' &&
                    order.stops.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  BatchStopsCard(
                    order: order,
                    onCompleted: _onBatchCompleted,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                _ActiveActionButton(
                  label: order.nextAction,
                  loading: _actionLoading,
                  onPressed: _handleAction,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  bool get _hasDetails =>
      (order.distance != null && order.distance! > 0) ||
      (order.codAmount != null && order.codAmount! > 0) ||
      order.voucherCode?.trim().isNotEmpty == true ||
      order.bonusFee > 0 ||
      order.nightSurcharge > 0 ||
      (order.rainBonusEligible && order.rainBonusConfirmedAmount > 0) ||
      order.isBatch;
}

class _CustomerAppRunningCard extends StatelessWidget {
  final OrderModel order;
  final String pickupName;
  final String deliveryName;
  final Color statusColor;
  final Color serviceColor;
  final String? positionLabel;
  final bool actionLoading;
  final VoidCallback onNavigatePickup;
  final VoidCallback onNavigateDelivery;
  final VoidCallback onAction;

  const _CustomerAppRunningCard({
    required this.order,
    required this.pickupName,
    required this.deliveryName,
    required this.statusColor,
    required this.serviceColor,
    required this.positionLabel,
    required this.actionLoading,
    required this.onNavigatePickup,
    required this.onNavigateDelivery,
    required this.onAction,
  });

  bool get _hasCompanyPayment =>
      order.discountAmount > 0 ||
      order.bonusFee > 0 ||
      (order.rainBonusEligible && order.rainBonusConfirmedAmount > 0);

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: serviceColor.withValues(alpha: .22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CustomerAppRunningHeader(
              order: order,
              statusColor: statusColor,
              serviceColor: serviceColor,
              positionLabel: positionLabel,
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_hasCompanyPayment) ...[
                    _CustomerAppActivePayments(order: order),
                  ],
                  if (((order.distance ?? 0) > 0 &&
                          !order.hasMultipleShoppingStops) ||
                      order.shopPaymentAmount > 0 ||
                      order.topupAmount > 0) ...[
                    const SizedBox(height: AppSpacing.md),
                    _CustomerAppActiveMetrics(order: order),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _Route(
                    pickupName: pickupName,
                    pickupAddress: order.pickupAddress,
                    pickupPhone: order.serviceType == 'topup'
                        ? order.deliveryPhone
                        : order.pickupPhone,
                    deliveryName: deliveryName,
                    deliveryAddress: order.deliveryAddress,
                    deliveryPhone: order.deliveryPhone,
                    onNavigatePickup: onNavigatePickup,
                    onNavigateDelivery: onNavigateDelivery,
                    assigned: order.status == 'assigned',
                    color: serviceColor,
                    pickupLabel: Fmt.pickupLabel(order.serviceType),
                    deliveryLabel: Fmt.deliveryLabel(order.serviceType),
                    showDelivery: Fmt.showsDeliveryPoint(order.serviceType),
                  ),
                  if (order.orderNote?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.md),
                    if (order.serviceType == 'shopping')
                      ShoppingOrderNote(note: order.orderNote!.trim())
                    else
                      _OrderNote(note: order.orderNote!.trim()),
                  ],
                  if (order.nightSurcharge > 0) ...[
                    const SizedBox(height: AppSpacing.md),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _DetailChip(
                        icon: Icons.nightlight_round,
                        label:
                            'Đã gồm phụ phí đêm ${Fmt.currency(order.nightSurcharge)}',
                        color: const Color(0xFF6655B5),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _ActiveActionButton(
                    label: order.nextAction,
                    loading: actionLoading,
                    onPressed: onAction,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CustomerAppRunningHeader extends StatelessWidget {
  final OrderModel order;
  final Color statusColor;
  final Color serviceColor;
  final String? positionLabel;

  const _CustomerAppRunningHeader({
    required this.order,
    required this.statusColor,
    required this.serviceColor,
    required this.positionLabel,
  });

  Widget get _identity => Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: serviceColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            Fmt.serviceIcon(order.serviceType),
            color: Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(
                    Fmt.serviceLabel(order.serviceType),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                      color: serviceColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  '#${order.code}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Text(
                  order.statusLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 7),
                const Icon(Icons.circle,
                    size: 4, color: AppColors.textTertiary),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'Khách đặt app',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: serviceColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (positionLabel != null) ...[
                  const SizedBox(width: 7),
                  _SmallLabel(label: positionLabel!),
                ],
              ]),
            ],
          ),
        ),
      ]);

  Widget get _fee => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              Fmt.currency(order.shippingFee),
              style: AppTextStyles.metric.copyWith(
                color: AppColors.primaryDark,
                fontSize: AppFontSize.xl2,
              ),
            ),
          ),
          Text(
            Fmt.customerFeeLabel(order.serviceType),
            maxLines: 2,
            textAlign: TextAlign.right,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primaryDark,
              fontSize: 8,
              letterSpacing: .25,
              height: 1.2,
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
        decoration: BoxDecoration(
          color: serviceColor.withValues(alpha: .075),
          border: Border(
            bottom: BorderSide(color: serviceColor.withValues(alpha: .12)),
          ),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < 310) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _identity,
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  Text(
                    'Khách cần trả',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(width: 112, child: _fee),
                ]),
              ],
            );
          }
          return Row(children: [
            Expanded(child: _identity),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(width: 100, child: _fee),
          ]);
        }),
      );
}

class _CustomerAppActivePayments extends StatelessWidget {
  final OrderModel order;
  const _CustomerAppActivePayments({required this.order});

  @override
  Widget build(BuildContext context) {
    final payments = <({IconData icon, String label, int amount, Color color})>[
      if (order.discountAmount > 0)
        (
          icon: Icons.confirmation_number_rounded,
          label: 'CÔNG TY BÙ VOUCHER',
          amount: order.discountAmount,
          color: AppColors.success,
        ),
      if (order.bonusFee > 0)
        (
          icon: Icons.card_giftcard_rounded,
          label: 'BONUS',
          amount: order.bonusFee,
          color: AppColors.success,
        ),
      if (order.rainBonusEligible && order.rainBonusConfirmedAmount > 0)
        (
          icon: Icons.water_drop_rounded,
          label: 'THƯỞNG MƯA',
          amount: order.rainBonusConfirmedAmount,
          color: AppColors.info,
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.success.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CÔNG TY THANH TOÁN RIÊNG · KHÔNG THU KHÁCH',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.success,
              fontSize: 9,
              letterSpacing: .35,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(builder: (context, constraints) {
            final itemWidth = payments.length == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - AppSpacing.sm) / 2;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final payment in payments)
                  SizedBox(
                    width: itemWidth,
                    child: _ActiveRewardItem(reward: payment),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _CustomerAppActiveMetrics extends StatelessWidget {
  final OrderModel order;
  const _CustomerAppActiveMetrics({required this.order});

  @override
  Widget build(BuildContext context) {
    final metrics =
        <({IconData icon, String label, String value, Color color})>[
      if ((order.distance ?? 0) > 0 &&
          !order.hasMultipleShoppingStops &&
          Fmt.showsRouteDistance(order.serviceType))
        (
          icon: Icons.route_rounded,
          label: 'QUÃNG ĐƯỜNG',
          value: '${order.distance!.toStringAsFixed(1)} km',
          color: AppColors.info,
        ),
      if (order.shopPaymentAmount > 0)
        (
          icon: Icons.account_balance_wallet_rounded,
          label: 'TIỀN TRẢ SHOP',
          value: Fmt.currency(order.shopPaymentAmount),
          color: AppColors.warningStrong,
        ),
      if (order.topupAmount > 0)
        (
          icon: Icons.payments_rounded,
          label: 'SỐ TIỀN CẦN NẠP',
          value: Fmt.currency(order.topupAmount),
          color: AppColors.success,
        ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(children: [
        for (var i = 0; i < metrics.length; i++) ...[
          if (i > 0)
            const SizedBox(
              height: 38,
              child: VerticalDivider(width: 20, color: AppColors.divider),
            ),
          Expanded(
            child: Row(children: [
              Icon(metrics[i].icon, size: 16, color: metrics[i].color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metrics[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      metrics[i].value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// Đơn app shop đang chạy: tiền cần thu người nhận (thu hộ + phí ship) luôn
/// nằm ở đầu thẻ vì đây là việc tài xế phải nhớ lúc giao.
class _ShopRunningCard extends StatelessWidget {
  final OrderModel order;
  final String pickupName;
  final String deliveryName;
  final Color statusColor;
  final bool isPriority;
  final String? positionLabel;
  final bool actionLoading;
  final VoidCallback onNavigatePickup;
  final VoidCallback onNavigateDelivery;
  final VoidCallback onAction;
  final Future<void> Function() onBatchCompleted;

  const _ShopRunningCard({
    required this.order,
    required this.pickupName,
    required this.deliveryName,
    required this.statusColor,
    required this.isPriority,
    required this.positionLabel,
    required this.actionLoading,
    required this.onNavigatePickup,
    required this.onNavigateDelivery,
    required this.onAction,
    required this.onBatchCompleted,
  });

  static const _color = AppColors.secondary;

  String get _shopName => order.storeName?.trim().isNotEmpty == true
      ? order.storeName!.trim()
      : order.pickupPlaceName?.trim().isNotEmpty == true
          ? order.pickupPlaceName!.trim()
          : 'Cửa hàng';

  bool get _hasChips =>
      (order.distance ?? 0) > 0 ||
      order.voucherCode?.trim().isNotEmpty == true ||
      order.bonusFee > 0 ||
      order.nightSurcharge > 0 ||
      (order.rainBonusEligible && order.rainBonusConfirmedAmount > 0);

  @override
  Widget build(BuildContext context) {
    final assigned = order.status == 'assigned';
    final pickupOnly = order.shopServiceType == 'shop_pickup';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: _color.withValues(alpha: .24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ShopRunningHeader(
            order: order,
            statusColor: statusColor,
            positionLabel: positionLabel,
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CurrentTask(
                  assigned: assigned,
                  color: statusColor,
                  isPriority: isPriority,
                ),
                const SizedBox(height: AppSpacing.md),
                _ShopStoreRow(name: _shopName),
                if ((order.codAmount ?? 0) > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ShopActiveCollection(order: order),
                ],
                const SizedBox(height: AppSpacing.md),
                _Route(
                  pickupName: pickupName,
                  pickupAddress: order.pickupAddress,
                  pickupPhone: order.pickupPhone,
                  deliveryName: deliveryName,
                  deliveryAddress: order.deliveryAddress,
                  deliveryPhone: order.deliveryPhone,
                  onNavigatePickup: onNavigatePickup,
                  onNavigateDelivery: onNavigateDelivery,
                  assigned: assigned,
                  color: _color,
                  pickupLabel: pickupOnly ? 'ĐIỂM LẤY HỘ' : 'LẤY TẠI SHOP',
                  deliveryLabel: pickupOnly ? 'MANG VỀ SHOP' : 'GIAO ĐẾN',
                ),
                if (order.cargoType != 'food') ...[
                  const SizedBox(height: AppSpacing.md),
                  CargoBadge(
                    cargoType: order.cargoType,
                    cargoNote: order.cargoNote,
                    cargoWeight: order.cargoWeight,
                  ),
                ],
                if (order.orderNote?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: AppSpacing.md),
                  _OrderNote(note: order.orderNote!.trim()),
                ],
                if (_hasChips) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if ((order.distance ?? 0) > 0)
                        _DetailChip(
                          icon: Icons.route_rounded,
                          label:
                              'Quãng đường ${order.distance!.toStringAsFixed(1)} km',
                          color: AppColors.info,
                        ),
                      if (order.voucherCode?.trim().isNotEmpty == true)
                        _DetailChip(
                          icon: Icons.confirmation_number_rounded,
                          label: order.discountAmount > 0
                              ? 'Voucher ${order.voucherCode} · giảm ${Fmt.currency(order.discountAmount)}'
                              : 'Voucher ${order.voucherCode}',
                          color: AppColors.secondary,
                        ),
                      if (order.bonusFee > 0)
                        _DetailChip(
                          icon: Icons.add_circle_rounded,
                          label: 'Thưởng thêm +${Fmt.currency(order.bonusFee)}',
                          color: AppColors.success,
                        ),
                      if (order.nightSurcharge > 0)
                        _DetailChip(
                          icon: Icons.nightlight_round,
                          label:
                              'Đã gồm phụ phí đêm ${Fmt.currency(order.nightSurcharge)}',
                          color: const Color(0xFF6655B5),
                        ),
                      if (order.rainBonusEligible &&
                          order.rainBonusConfirmedAmount > 0)
                        _DetailChip(
                          icon: Icons.water_drop_rounded,
                          label:
                              'Thưởng mưa +${Fmt.currency(order.rainBonusConfirmedAmount)}',
                          color: AppColors.info,
                        ),
                    ],
                  ),
                ],
                if (order.isBatch &&
                    order.status == 'processing' &&
                    order.stops.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  BatchStopsCard(order: order, onCompleted: onBatchCompleted),
                ],
                const SizedBox(height: AppSpacing.lg),
                _ActiveActionButton(
                  label: order.nextAction,
                  loading: actionLoading,
                  onPressed: onAction,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopRunningHeader extends StatelessWidget {
  final OrderModel order;
  final Color statusColor;
  final String? positionLabel;

  const _ShopRunningHeader({
    required this.order,
    required this.statusColor,
    required this.positionLabel,
  });

  static const _color = AppColors.secondary;

  Widget get _identity => Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _color,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(
                    order.isBatch && order.stopsCount > 1
                        ? '${order.displayTitle} · ${order.stopsCount} điểm'
                        : order.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                      color: _color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  '#${order.code}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
              const SizedBox(height: 3),
              Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      order.statusLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(Icons.circle,
                        size: 4, color: AppColors.textTertiary),
                    Text(
                      'Shop book',
                      style: AppTextStyles.caption.copyWith(
                        color: _color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (positionLabel != null)
                      _SmallLabel(label: positionLabel!),
                  ]),
            ],
          ),
        ),
      ]);

  Widget get _fee => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              Fmt.currency(order.customerCollectionAmount),
              style: AppTextStyles.metric.copyWith(
                color: AppColors.primaryDark,
                fontSize: AppFontSize.xl2,
              ),
            ),
          ),
          Text(
            'CẦN THU',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primaryDark,
              fontSize: 9,
              letterSpacing: .7,
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: .08),
          border: Border(
            bottom: BorderSide(color: _color.withValues(alpha: .14)),
          ),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < 310) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _identity,
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  Expanded(
                    child: Text(
                      'Thu người nhận',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(width: 112, child: _fee),
                ]),
              ],
            );
          }
          return Row(children: [
            Expanded(child: _identity),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(width: 100, child: _fee),
          ]);
        }),
      );
}

class _ShopStoreRow extends StatelessWidget {
  final String name;
  const _ShopStoreRow({required this.name});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.secondarySoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(children: [
          const Icon(Icons.store_mall_directory_outlined,
              size: 17, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.sm),
          Text('Cửa hàng',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ]),
      );
}

/// Tách "Cần thu" thành thu hộ shop + phí ship để tài xế đối chiếu với người nhận.
class _ShopActiveCollection extends StatelessWidget {
  final OrderModel order;
  const _ShopActiveCollection({required this.order});

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, int amount, Color color) =>
        Expanded(
          child: Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    Fmt.currency(amount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ]),
        );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: .18)),
      ),
      child: Row(children: [
        item(Icons.payments_rounded, 'THU HỘ SHOP', order.codAmount ?? 0,
            AppColors.warning),
        const SizedBox(
          height: 38,
          child: VerticalDivider(width: 20, color: AppColors.divider),
        ),
        item(Icons.local_shipping_rounded, 'PHÍ SHIP', order.shippingFee,
            AppColors.textPrimary),
      ]),
    );
  }
}

class _CallCenterRunningCard extends StatelessWidget {
  final OrderModel order;
  final Color statusColor;
  final String? positionLabel;
  final bool actionLoading;
  final VoidCallback onNavigatePickup;
  final VoidCallback onAction;

  const _CallCenterRunningCard({
    required this.order,
    required this.statusColor,
    required this.positionLabel,
    required this.actionLoading,
    required this.onNavigatePickup,
    required this.onAction,
  });

  bool get _hasRewards =>
      order.bonusFee > 0 ||
      (order.rainBonusEligible && order.rainBonusConfirmedAmount > 0);

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.primary.withValues(alpha: .22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CallCenterRunningHeader(
              order: order,
              statusColor: statusColor,
              positionLabel: positionLabel,
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_hasRewards) ...[
                    _CallCenterActiveRewards(order: order),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  CallCenterPickupDetails(
                    pickupAddress: order.pickupAddress,
                    pickupLat: order.pickupLat,
                    pickupLng: order.pickupLng,
                    note: order.orderNote,
                    onOpenMap:
                        order.pickupLat != null && order.pickupLng != null
                            ? onNavigatePickup
                            : null,
                  ),
                  if (order.nightSurcharge > 0 ||
                      order.voucherCode?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        if (order.nightSurcharge > 0)
                          _DetailChip(
                            icon: Icons.nightlight_round,
                            label:
                                'Phụ phí đêm ${Fmt.currency(order.nightSurcharge)}',
                            color: const Color(0xFF6655B5),
                          ),
                        if (order.voucherCode?.trim().isNotEmpty == true)
                          _DetailChip(
                            icon: Icons.confirmation_number_rounded,
                            label: order.discountAmount > 0
                                ? 'Voucher ${order.voucherCode} · giảm ${Fmt.currency(order.discountAmount)}'
                                : 'Voucher ${order.voucherCode}',
                            color: AppColors.secondary,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _ActiveActionButton(
                    label: order.nextAction,
                    loading: actionLoading,
                    onPressed: onAction,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CallCenterRunningHeader extends StatelessWidget {
  final OrderModel order;
  final Color statusColor;
  final String? positionLabel;

  const _CallCenterRunningHeader({
    required this.order,
    required this.statusColor,
    required this.positionLabel,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF3ED), Color(0xFFFFE7DC)],
          ),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              size: 21,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      Fmt.serviceLabel(order.serviceType),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '#${order.code}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  Text(
                    Fmt.orderStatus(order.status),
                    style: AppTextStyles.caption.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Icon(Icons.circle,
                      size: 4, color: AppColors.textTertiary),
                  const SizedBox(width: 7),
                  Text(
                    'Tổng đài',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (positionLabel != null) ...[
                    const SizedBox(width: 7),
                    _SmallLabel(label: positionLabel!),
                  ],
                ]),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.currency(order.baseShippingFee),
                style: AppTextStyles.metric.copyWith(
                  color: AppColors.primaryDark,
                  fontSize: AppFontSize.xl2,
                ),
              ),
              Text(
                'PHÍ SHIP GỐC',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primaryDark,
                  fontSize: 9,
                  letterSpacing: .7,
                ),
              ),
            ],
          ),
        ]),
      );
}

class _CallCenterActiveRewards extends StatelessWidget {
  final OrderModel order;
  const _CallCenterActiveRewards({required this.order});

  @override
  Widget build(BuildContext context) {
    final rewards = <({IconData icon, String label, int amount, Color color})>[
      if (order.bonusFee > 0)
        (
          icon: Icons.card_giftcard_rounded,
          label: 'CÔNG TY THƯỞNG',
          amount: order.bonusFee,
          color: AppColors.success,
        ),
      if (order.rainBonusEligible && order.rainBonusConfirmedAmount > 0)
        (
          icon: Icons.water_drop_rounded,
          label: 'THƯỞNG MƯA',
          amount: order.rainBonusConfirmedAmount,
          color: AppColors.info,
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.success.withValues(alpha: .18)),
      ),
      child: Row(children: [
        for (var i = 0; i < rewards.length; i++) ...[
          if (i > 0)
            const SizedBox(
              height: 38,
              child: VerticalDivider(width: 20, color: AppColors.divider),
            ),
          Expanded(child: _ActiveRewardItem(reward: rewards[i])),
        ],
      ]),
    );
  }
}

class _ActiveRewardItem extends StatelessWidget {
  final ({IconData icon, String label, int amount, Color color}) reward;
  const _ActiveRewardItem({required this.reward});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: reward.color.withValues(alpha: .12),
            shape: BoxShape.circle,
          ),
          child: Icon(reward.icon, size: 18, color: reward.color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reward.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: reward.color,
                  fontSize: 9,
                  letterSpacing: .35,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '+${Fmt.currency(reward.amount)}',
                style: AppTextStyles.bodyStrong.copyWith(
                  color: reward.color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ]);
}

class _ActiveActionButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const _ActiveActionButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return SwipeButton(
      label: loading ? 'Đang cập nhật...' : 'Vuốt để $label',
      color: AppColors.primary,
      loading: loading,
      onConfirm: loading ? null : onPressed,
    );
  }
}

class _Header extends StatelessWidget {
  final OrderModel order;
  final Color serviceColor;
  final Color statusColor;
  final String? positionLabel;

  const _Header({
    required this.order,
    required this.serviceColor,
    required this.statusColor,
    required this.positionLabel,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: serviceColor.withValues(alpha: .075),
          border: Border(
            bottom: BorderSide(color: serviceColor.withValues(alpha: .10)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: serviceColor,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: [
                  BoxShadow(
                    color: serviceColor.withValues(alpha: .22),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Fmt.serviceIcon(order.serviceType),
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          order.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.sectionTitle.copyWith(
                            fontSize: AppFontSize.lg,
                          ),
                        ),
                      ),
                      if (positionLabel != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        _SmallLabel(label: positionLabel!),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '#${order.code} · ${Fmt.orderStatus(order.status)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Fmt.currency(order.driverEarning),
                    style: AppTextStyles.metric.copyWith(
                      color: AppColors.success,
                      fontSize: AppFontSize.xl,
                    ),
                  ),
                  Text(
                    'THU NHẬP',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.success,
                      fontSize: 9,
                      letterSpacing: .7,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CurrentTask extends StatelessWidget {
  final bool assigned;
  final Color color;
  final bool isPriority;

  const _CurrentTask({
    required this.assigned,
    required this.color,
    required this.isPriority,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(
                assigned
                    ? Icons.storefront_rounded
                    : Icons.local_shipping_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assigned ? 'Đang đi lấy hàng' : 'Đang giao đến khách',
                    style: AppTextStyles.bodyStrong.copyWith(color: color),
                  ),
                  Text(
                    assigned
                        ? 'Điểm lấy là điểm đến tiếp theo'
                        : 'Điểm giao là điểm đến tiếp theo',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isPriority) _SmallLabel(label: 'ƯU TIÊN', color: color),
          ],
        ),
      );
}

class _Route extends StatelessWidget {
  final String pickupName;
  final String pickupAddress;
  final String? pickupPhone;
  final String deliveryName;
  final String deliveryAddress;
  final String? deliveryPhone;
  final VoidCallback onNavigatePickup;
  final VoidCallback onNavigateDelivery;
  final bool assigned;
  final Color color;
  final String pickupLabel;
  final String deliveryLabel;
  final bool showDelivery;

  const _Route({
    required this.pickupName,
    required this.pickupAddress,
    this.pickupPhone,
    required this.deliveryName,
    required this.deliveryAddress,
    this.deliveryPhone,
    required this.onNavigatePickup,
    required this.onNavigateDelivery,
    required this.assigned,
    required this.color,
    this.pickupLabel = 'ĐIỂM LẤY',
    this.deliveryLabel = 'ĐIỂM GIAO',
    this.showDelivery = true,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RouteLabel(
              label: pickupLabel,
              active: assigned,
              color: color,
              icon: Icons.radio_button_checked_rounded,
            ),
            const SizedBox(height: AppSpacing.xs),
            _RouteText(
              name: pickupName,
              address: pickupAddress,
              phone: pickupPhone,
              onNavigate: onNavigatePickup,
            ),
            if (showDelivery) ...[
              const SizedBox(height: AppSpacing.md),
              _RouteLabel(
                label: deliveryLabel,
                active: !assigned,
                color: AppColors.success,
                icon: Icons.location_on_rounded,
              ),
              const SizedBox(height: AppSpacing.xs),
              _RouteText(
                  name: deliveryName,
                  address: deliveryAddress,
                  phone: deliveryPhone,
                  onNavigate: onNavigateDelivery),
            ],
          ],
        ),
      );
}

class _RouteLabel extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final IconData icon;

  const _RouteLabel({
    required this.label,
    required this.active,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(width: 18, child: Icon(icon, size: 17, color: color)),
          const SizedBox(width: AppSpacing.md),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: active ? color : AppColors.textTertiary,
              fontSize: 9,
              letterSpacing: .8,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (active) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ],
        ],
      );
}

class _RouteText extends StatelessWidget {
  final String name;
  final String address;
  final String? phone;
  final VoidCallback onNavigate;

  const _RouteText({
    required this.name,
    required this.address,
    this.phone,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyStrong.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (address.isNotEmpty && address != name) ...[
              const SizedBox(height: 2),
              Text(
                address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (phone?.trim().isNotEmpty == true)
                  InkWell(
                    onTap: () => launchPhoneCall(phone!.trim()),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.phone_rounded,
                          size: 13, color: AppColors.info),
                      const SizedBox(width: 4),
                      Text(
                        phone!.trim(),
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.info,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ]),
                  )
                else
                  Text(
                    'Chưa có số điện thoại',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                InkWell(
                  onTap: onNavigate,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.navigation_rounded,
                        size: 13, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Mở chỉ đường',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ],
        ),
      );
}

class _OrderNote extends StatelessWidget {
  final String note;
  const _OrderNote({required this.note});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.warningSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.warning.withValues(alpha: .14)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.sticky_note_2_rounded,
              size: 19,
              color: AppColors.warning,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GHI CHÚ ĐƠN HÀNG',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.warning,
                      fontSize: 9,
                      letterSpacing: .7,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  FormattedNote(
                    note: note,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DetailChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

class _SmallLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallLabel({
    required this.label,
    this.color = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}
