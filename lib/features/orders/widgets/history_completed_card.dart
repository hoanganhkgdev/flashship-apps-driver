import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launch_utils.dart';
import '../models/order_model.dart';
import 'call_center_pickup_details.dart';
import 'formatted_note.dart';
import 'shopping_order_note.dart';

class HistoryDateLabel extends StatelessWidget {
  final String label;
  final String? summary;

  const HistoryDateLabel({
    super.key,
    required this.label,
    this.summary,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: AppTextStyles.sectionTitle.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (summary != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text(
                  summary!,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      );
}

class HistoryCompletedCard extends StatelessWidget {
  final OrderModel order;

  const HistoryCompletedCard({super.key, required this.order});

  String get _pickup => order.storeName?.isNotEmpty == true
      ? order.storeName!
      : order.pickupPlaceName?.isNotEmpty == true
          ? order.pickupPlaceName!
          : order.pickupAddress;

  String get _delivery => order.deliveryPlaceName?.isNotEmpty == true
      ? order.deliveryPlaceName!
      : order.customerName?.isNotEmpty == true
          ? order.customerName!
          : order.deliveryAddress;

  bool get _hasDetails =>
      order.nightSurcharge > 0 ||
      order.bonusFee > 0 ||
      (order.rainBonusEligible && order.rainBonusConfirmedAmount > 0) ||
      order.voucherCode?.trim().isNotEmpty == true ||
      order.isBatch;

  @override
  Widget build(BuildContext context) {
    final color = Fmt.serviceColor(order.serviceType);
    final local = (order.completedAt ?? order.createdAt).toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    if (order.isCallCenter) {
      return _CallCenterCompletedCard(order: order, time: time);
    }
    if (order.isCustomerApp) {
      return _CustomerAppCompletedCard(order: order, time: time);
    }
    if (order.isShopOrder) {
      return _ShopCompletedCard(
        order: order,
        time: time,
        pickup: _pickup,
        delivery: _delivery,
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withValues(alpha: .14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .07),
              border: Border(
                bottom: BorderSide(color: color.withValues(alpha: .09)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Fmt.serviceIcon(order.serviceType),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyStrong.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$time · #${order.code}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Fmt.currency(order.driverEarning),
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: AppColors.success,
                        fontSize: AppFontSize.lg,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 13,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Hoàn thành',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CompletedRoute(pickup: _pickup, delivery: _delivery),
                if (_hasDetails) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if (order.nightSurcharge > 0)
                        _MoneyChip(
                          icon: Icons.nightlight_round,
                          label:
                              'Phụ phí đêm ${Fmt.currency(order.nightSurcharge)}',
                          color: const Color(0xFF6655B5),
                        ),
                      if (order.bonusFee > 0)
                        _MoneyChip(
                          icon: Icons.add_circle_rounded,
                          label: 'Thưởng +${Fmt.currency(order.bonusFee)}',
                          color: AppColors.success,
                        ),
                      if (order.rainBonusEligible &&
                          order.rainBonusConfirmedAmount > 0)
                        _MoneyChip(
                          icon: Icons.water_drop_rounded,
                          label:
                              'Thưởng mưa +${Fmt.currency(order.rainBonusConfirmedAmount)}',
                          color: AppColors.info,
                        ),
                      if (order.voucherCode?.trim().isNotEmpty == true)
                        _MoneyChip(
                          icon: Icons.confirmation_number_rounded,
                          label: 'Voucher ${order.voucherCode}',
                          color: AppColors.secondary,
                        ),
                      if (order.isBatch)
                        _MoneyChip(
                          icon: Icons.call_split_rounded,
                          label: '${order.stopsCount} điểm giao',
                          color: AppColors.secondary,
                        ),
                    ],
                  ),
                ],
                if (order.orderNote?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      const Icon(
                        Icons.sticky_note_2_rounded,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          order.orderNote!.trim(),
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopCompletedCard extends StatelessWidget {
  final OrderModel order;
  final String time;
  final String pickup;
  final String delivery;

  const _ShopCompletedCard({
    required this.order,
    required this.time,
    required this.pickup,
    required this.delivery,
  });

  static const _color = AppColors.secondary;

  String get _shopName => order.storeName?.trim().isNotEmpty == true
      ? order.storeName!.trim()
      : order.pickupPlaceName?.trim().isNotEmpty == true
          ? order.pickupPlaceName!.trim()
          : 'Cửa hàng';

  bool get _hasChips =>
      (order.codAmount ?? 0) > 0 ||
      order.nightSurcharge > 0 ||
      order.bonusFee > 0 ||
      (order.rainBonusEligible && order.rainBonusConfirmedAmount > 0) ||
      order.voucherCode?.trim().isNotEmpty == true;

  @override
  Widget build(BuildContext context) {
    final pickupOnly = order.shopServiceType == 'shop_pickup';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: _color.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: .08),
              border: Border(
                bottom: BorderSide(color: _color.withValues(alpha: .14)),
              ),
            ),
            child: Row(children: [
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
                    Row(children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '$time · Shop book',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 96),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        Fmt.currency(order.driverEarning),
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: AppColors.success,
                          fontSize: AppFontSize.lg,
                        ),
                      ),
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
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ShopStoreRow(name: _shopName),
                const SizedBox(height: AppSpacing.md),
                _CompletedRoute(
                  pickup: pickup,
                  delivery: delivery,
                  pickupLabel: pickupOnly ? 'ĐIỂM LẤY HỘ' : 'LẤY TẠI SHOP',
                  deliveryLabel: pickupOnly ? 'MANG VỀ SHOP' : 'ĐÃ GIAO ĐẾN',
                ),
                if (_hasChips) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if ((order.codAmount ?? 0) > 0)
                        _MoneyChip(
                          icon: Icons.payments_rounded,
                          label: 'Đã thu hộ ${Fmt.currency(order.codAmount!)}',
                          color: AppColors.warning,
                        ),
                      if (order.nightSurcharge > 0)
                        _MoneyChip(
                          icon: Icons.nightlight_round,
                          label:
                              'Phụ phí đêm ${Fmt.currency(order.nightSurcharge)}',
                          color: const Color(0xFF6655B5),
                        ),
                      if (order.bonusFee > 0)
                        _MoneyChip(
                          icon: Icons.add_circle_rounded,
                          label: 'Thưởng +${Fmt.currency(order.bonusFee)}',
                          color: AppColors.success,
                        ),
                      if (order.rainBonusEligible &&
                          order.rainBonusConfirmedAmount > 0)
                        _MoneyChip(
                          icon: Icons.water_drop_rounded,
                          label:
                              'Thưởng mưa +${Fmt.currency(order.rainBonusConfirmedAmount)}',
                          color: AppColors.info,
                        ),
                      if (order.voucherCode?.trim().isNotEmpty == true)
                        _MoneyChip(
                          icon: Icons.confirmation_number_rounded,
                          label: 'Voucher ${order.voucherCode}',
                          color: AppColors.secondary,
                        ),
                    ],
                  ),
                ],
                if (order.orderNote?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: AppSpacing.md),
                  _CustomerAppCompletedNote(note: order.orderNote!.trim()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
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

class _CustomerAppCompletedCard extends StatelessWidget {
  final OrderModel order;
  final String time;

  const _CustomerAppCompletedCard({required this.order, required this.time});

  bool get _hasCompanyPayment =>
      order.discountAmount > 0 ||
      order.bonusFee > 0 ||
      (order.rainBonusEligible && order.rainBonusConfirmedAmount > 0);

  @override
  Widget build(BuildContext context) {
    final serviceColor = Fmt.serviceColor(order.serviceType);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: serviceColor.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CustomerAppCompletedHeader(
            order: order,
            time: time,
            serviceColor: serviceColor,
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_hasCompanyPayment) ...[
                  _CustomerAppCompletedPayments(order: order),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (((order.distance ?? 0) > 0 &&
                        !order.hasMultipleShoppingStops) ||
                    order.shopPaymentAmount > 0 ||
                    order.topupAmount > 0) ...[
                  _CustomerAppCompletedMetrics(order: order),
                  const SizedBox(height: AppSpacing.md),
                ],
                _CompletedRoute(
                  pickup: order.pickupAddress,
                  delivery: order.deliveryAddress,
                  pickupLabel: Fmt.pickupLabel(order.serviceType),
                  deliveryLabel: Fmt.deliveryLabel(order.serviceType),
                  showDelivery: Fmt.showsDeliveryPoint(order.serviceType),
                ),
                if (order.orderNote?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: AppSpacing.md),
                  if (order.serviceType == 'shopping')
                    ShoppingOrderNote(note: order.orderNote!.trim())
                  else
                    _CustomerAppCompletedNote(note: order.orderNote!.trim()),
                ],
                if (order.nightSurcharge > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _MoneyChip(
                      icon: Icons.nightlight_round,
                      label:
                          'Đã gồm phụ phí đêm ${Fmt.currency(order.nightSurcharge)}',
                      color: const Color(0xFF6655B5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerAppCompletedHeader extends StatelessWidget {
  final OrderModel order;
  final String time;
  final Color serviceColor;

  const _CustomerAppCompletedHeader({
    required this.order,
    required this.time,
    required this.serviceColor,
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
                const Icon(
                  Icons.check_circle_rounded,
                  size: 13,
                  color: AppColors.success,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '$time · Khách đặt app',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
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
            Fmt.customerFeeLabel(order.serviceType, completed: true),
            maxLines: 2,
            textAlign: TextAlign.right,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primaryDark,
              fontSize: 8,
              letterSpacing: .2,
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
                    'Khách đã trả',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(width: 118, child: _fee),
                ]),
              ],
            );
          }
          return Row(children: [
            Expanded(child: _identity),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(width: 105, child: _fee),
          ]);
        }),
      );
}

class _CustomerAppCompletedPayments extends StatelessWidget {
  final OrderModel order;
  const _CustomerAppCompletedPayments({required this.order});

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
            'CÔNG TY ĐÃ THANH TOÁN RIÊNG',
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
                    child: _CompletedRewardItem(reward: payment),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _CustomerAppCompletedMetrics extends StatelessWidget {
  final OrderModel order;
  const _CustomerAppCompletedMetrics({required this.order});

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

class _CustomerAppCompletedNote extends StatelessWidget {
  final String note;
  const _CustomerAppCompletedNote({required this.note});

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
              size: 18,
              color: AppColors.warning,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FormattedNote(
                note: note,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _CallCenterCompletedCard extends StatelessWidget {
  final OrderModel order;
  final String time;

  const _CallCenterCompletedCard({required this.order, required this.time});

  bool get _hasRewards =>
      order.bonusFee > 0 ||
      (order.rainBonusEligible && order.rainBonusConfirmedAmount > 0);

  bool get _hasExtras =>
      order.nightSurcharge > 0 || order.voucherCode?.trim().isNotEmpty == true;

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
            _CallCenterCompletedHeader(order: order, time: time),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_hasRewards) ...[
                    _CallCenterCompletedRewards(order: order),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  CallCenterPickupDetails(
                    pickupAddress: order.pickupAddress,
                    pickupLat: order.pickupLat,
                    pickupLng: order.pickupLng,
                    note: order.orderNote,
                    onOpenMap:
                        order.pickupLat != null && order.pickupLng != null
                            ? () => launchNavigation(
                                  lat: order.pickupLat,
                                  lng: order.pickupLng,
                                  address: order.pickupAddress,
                                )
                            : null,
                  ),
                  if (_hasExtras) ...[
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        if (order.nightSurcharge > 0)
                          _MoneyChip(
                            icon: Icons.nightlight_round,
                            label:
                                'Phụ phí đêm ${Fmt.currency(order.nightSurcharge)}',
                            color: const Color(0xFF6655B5),
                          ),
                        if (order.voucherCode?.trim().isNotEmpty == true)
                          _MoneyChip(
                            icon: Icons.confirmation_number_rounded,
                            label: order.discountAmount > 0
                                ? 'Voucher ${order.voucherCode} · giảm ${Fmt.currency(order.discountAmount)}'
                                : 'Voucher ${order.voucherCode}',
                            color: AppColors.secondary,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

class _CallCenterCompletedHeader extends StatelessWidget {
  final OrderModel order;
  final String time;

  const _CallCenterCompletedHeader({required this.order, required this.time});

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
        child: Row(
          children: [
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
                  Row(
                    children: [
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
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '$time · Tổng đài',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
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
          ],
        ),
      );
}

class _CallCenterCompletedRewards extends StatelessWidget {
  final OrderModel order;
  const _CallCenterCompletedRewards({required this.order});

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
      child: Row(
        children: [
          for (var i = 0; i < rewards.length; i++) ...[
            if (i > 0)
              const SizedBox(
                height: 38,
                child: VerticalDivider(width: 20, color: AppColors.divider),
              ),
            Expanded(child: _CompletedRewardItem(reward: rewards[i])),
          ],
        ],
      ),
    );
  }
}

class _CompletedRewardItem extends StatelessWidget {
  final ({IconData icon, String label, int amount, Color color}) reward;
  const _CompletedRewardItem({required this.reward});

  @override
  Widget build(BuildContext context) => Row(
        children: [
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: reward.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _CompletedRoute extends StatelessWidget {
  final String pickup;
  final String delivery;
  final String pickupLabel;
  final String deliveryLabel;
  final bool showDelivery;

  const _CompletedRoute({
    required this.pickup,
    required this.delivery,
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
            _RouteLine(
              icon: Icons.radio_button_checked_rounded,
              label: pickupLabel,
              color: AppColors.primary,
            ),
            const SizedBox(height: 3),
            _RouteAddress(pickup),
            if (showDelivery) ...[
              const SizedBox(height: AppSpacing.md),
              _RouteLine(
                icon: Icons.location_on_rounded,
                label: deliveryLabel,
                color: AppColors.success,
              ),
              const SizedBox(height: 3),
              _RouteAddress(delivery),
            ],
          ],
        ),
      );
}

class _RouteLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _RouteLine({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(width: 18, child: Icon(icon, size: 17, color: color)),
          const SizedBox(width: AppSpacing.md),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 9,
              letterSpacing: .8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
}

class _RouteAddress extends StatelessWidget {
  final String text;
  const _RouteAddress(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 30),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyStrong,
        ),
      );
}

class _MoneyChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MoneyChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
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
