import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launch_utils.dart';
import '../models/market_order.dart';
import '../../orders/widgets/call_center_pickup_details.dart';
import '../../orders/widgets/formatted_note.dart';
import '../../orders/widgets/info_row.dart' show CargoBadge;
import '../../orders/widgets/shopping_order_note.dart';
import '../../orders/widgets/swipe_button.dart';

/// Thẻ một đơn mới tối ưu cho thao tác ngoài đường: thu nhập và loại dịch vụ
/// đọc được trong một nhịp nhìn, tuyến lấy/giao tách nhãn rõ ràng, nút nhận
/// luôn là hành động nổi bật nhất.
class MarketOrderCard extends StatelessWidget {
  final MarketOrder order;
  final bool claiming;
  final bool disabled;
  final VoidCallback onClaim;

  const MarketOrderCard({
    super.key,
    required this.order,
    required this.claiming,
    required this.disabled,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    if (order.isCallCenter) {
      return _CallCenterOrderCard(
        order: order,
        claiming: claiming,
        disabled: disabled,
        onClaim: onClaim,
      );
    }
    if (order.isCustomerApp) {
      return _CustomerAppOrderCard(
        order: order,
        claiming: claiming,
        disabled: disabled,
        onClaim: onClaim,
      );
    }
    if (order.isShopOrder) {
      return _ShopOrderCard(
        order: order,
        claiming: claiming,
        disabled: disabled,
        onClaim: onClaim,
      );
    }

    final serviceColor = Fmt.serviceColor(order.serviceType);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: serviceColor.withValues(alpha: .075),
              border: Border(
                bottom: BorderSide(color: serviceColor.withValues(alpha: .12)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: serviceColor,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(Fmt.serviceIcon(order.serviceType),
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Fmt.serviceLabel(order.serviceType),
                        style: AppTextStyles.bodyStrong.copyWith(
                          fontSize: AppFontSize.base,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(children: [
                        _MetaLabel(text: '#${order.code}'),
                        const SizedBox(width: AppSpacing.sm),
                        Icon(Icons.schedule_rounded,
                            size: 13, color: serviceColor),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _age(order.openedAt),
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ]),
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
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: .14),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Fmt.currency(order.estimatedIncome),
                        style: AppTextStyles.metric.copyWith(
                          color: AppColors.primaryDark,
                          fontSize: AppFontSize.xl,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'THU NHẬP',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primaryDark,
                          fontSize: 9,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!order.hasMultipleShoppingStops ||
                    order.shopPaymentAmount > 0) ...[
                  _DecisionMetrics(order: order),
                  const SizedBox(height: AppSpacing.lg),
                ],
                _Route(
                  pickup: order.pickupAddress,
                  delivery: order.deliveryAddress,
                  color: serviceColor,
                  pickupLabel: Fmt.pickupLabel(order.serviceType),
                  deliveryLabel: Fmt.deliveryLabel(order.serviceType),
                  showDelivery: Fmt.showsDeliveryPoint(order.serviceType),
                ),
                if (order.hasNote) ...[
                  const SizedBox(height: AppSpacing.md),
                  if (order.serviceType == 'shopping')
                    ShoppingOrderNote(note: order.orderNote!.trim())
                  else
                    _OrderNote(note: order.orderNote!.trim()),
                ],
                _OrderExtras(order: order),
                const SizedBox(height: AppSpacing.lg),
                _ClaimButton(
                  claiming: claiming,
                  disabled: disabled,
                  onClaim: onClaim,
                  noun: Fmt.claimNoun(order.serviceType),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _age(DateTime openedAt) {
    final minutes = DateTime.now().difference(openedAt).inMinutes;
    if (minutes < 1) return 'vừa đăng';
    if (minutes < 60) return '$minutes phút trước';
    return '${minutes ~/ 60} giờ trước';
  }
}

class _CustomerAppOrderCard extends StatelessWidget {
  final MarketOrder order;
  final bool claiming;
  final bool disabled;
  final VoidCallback onClaim;

  const _CustomerAppOrderCard({
    required this.order,
    required this.claiming,
    required this.disabled,
    required this.onClaim,
  });

  bool get _hasCompanyPayment =>
      order.discountAmount > 0 ||
      order.bonusFee > 0 ||
      (order.isRainMode && order.rainBonusAmount > 0);

  @override
  Widget build(BuildContext context) {
    final serviceColor = Fmt.serviceColor(order.serviceType);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: serviceColor.withValues(alpha: .22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
            decoration: BoxDecoration(
              color: serviceColor.withValues(alpha: .075),
              border: Border(
                bottom: BorderSide(color: serviceColor.withValues(alpha: .12)),
              ),
            ),
            child: _CustomerAppHeader(
              order: order,
              serviceColor: serviceColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_hasCompanyPayment) ...[
                  _CustomerAppRewards(order: order),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (!order.hasMultipleShoppingStops ||
                    order.shopPaymentAmount > 0) ...[
                  _DecisionMetrics(order: order),
                  const SizedBox(height: AppSpacing.lg),
                ],
                _Route(
                  pickup: order.pickupAddress,
                  delivery: order.deliveryAddress,
                  color: serviceColor,
                  pickupLabel: Fmt.pickupLabel(order.serviceType),
                  deliveryLabel: Fmt.deliveryLabel(order.serviceType),
                  showDelivery: Fmt.showsDeliveryPoint(order.serviceType),
                ),
                if (order.hasNote) ...[
                  const SizedBox(height: AppSpacing.md),
                  if (order.serviceType == 'shopping')
                    ShoppingOrderNote(note: order.orderNote!.trim())
                  else
                    _OrderNote(note: order.orderNote!.trim()),
                ],
                _OrderExtras(
                  order: order,
                  includeRewards: false,
                  includeVoucher: order.discountAmount <= 0,
                ),
                const SizedBox(height: AppSpacing.lg),
                _ClaimButton(
                  claiming: claiming,
                  disabled: disabled,
                  onClaim: onClaim,
                  noun: Fmt.claimNoun(order.serviceType),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerAppHeader extends StatelessWidget {
  final MarketOrder order;
  final Color serviceColor;

  const _CustomerAppHeader({
    required this.order,
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
                Flexible(
                  child: Text(
                    MarketOrderCard._age(order.openedAt),
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                const Icon(Icons.circle,
                    size: 4, color: AppColors.textTertiary),
                const SizedBox(width: 7),
                Text(
                  'Khách đặt app',
                  style: AppTextStyles.caption.copyWith(
                    color: serviceColor,
                    fontWeight: FontWeight.w800,
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
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
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
        },
      );
}

class _CallCenterOrderCard extends StatelessWidget {
  final MarketOrder order;
  final bool claiming;
  final bool disabled;
  final VoidCallback onClaim;

  const _CallCenterOrderCard({
    required this.order,
    required this.claiming,
    required this.disabled,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: .22),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFF3ED), Color(0xFFFFE7DC)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
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
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                '#${order.code}',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 7,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                MarketOrderCard._age(order.openedAt),
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                'Đơn do tổng đài tạo',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .72),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: .12),
                      ),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          'Phí giao hàng',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        Fmt.currency(order.baseShippingFee),
                        style: AppTextStyles.metric.copyWith(
                          color: AppColors.primaryDark,
                          fontSize: AppFontSize.xl,
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (order.bonusFee > 0 ||
                      (order.isRainMode && order.rainBonusAmount > 0)) ...[
                    _CallCenterRewards(order: order),
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
                  _OrderExtras(order: order, includeRewards: false),
                  const SizedBox(height: AppSpacing.lg),
                  _ClaimButton(
                    claiming: claiming,
                    disabled: disabled,
                    onClaim: onClaim,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Đơn do shop tạo trên app shop: nhận diện bằng tên shop, tiền cần nắm
/// trước khi nhận là phí ship và tiền thu hộ người nhận.
class _ShopOrderCard extends StatelessWidget {
  final MarketOrder order;
  final bool claiming;
  final bool disabled;
  final VoidCallback onClaim;

  const _ShopOrderCard({
    required this.order,
    required this.claiming,
    required this.disabled,
    required this.onClaim,
  });

  static const _color = AppColors.secondary;

  @override
  Widget build(BuildContext context) {
    final pickupOnly = order.shopServiceType == 'shop_pickup';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: _color.withValues(alpha: .18)),
      ),
      clipBehavior: Clip.antiAlias,
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
            child: _ShopHeader(order: order),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ShopStoreRow(name: order.shopName),
                const SizedBox(height: AppSpacing.md),
                _ShopCollection(order: order),
                const SizedBox(height: AppSpacing.md),
                _DecisionMetrics(order: order),
                const SizedBox(height: AppSpacing.lg),
                _Route(
                  pickup: order.pickupAddress,
                  delivery: order.deliveryAddress,
                  color: _color,
                  pickupLabel: pickupOnly ? 'ĐIỂM LẤY HỘ' : 'LẤY TẠI SHOP',
                  deliveryLabel: pickupOnly
                      ? 'MANG VỀ SHOP'
                      : order.isShopBatch && order.stopsCount > 1
                          ? 'GIAO ${order.stopsCount} ĐIỂM'
                          : 'GIAO ĐẾN',
                ),
                if (order.cargoType != 'food') ...[
                  const SizedBox(height: AppSpacing.md),
                  CargoBadge(
                    cargoType: order.cargoType,
                    cargoNote: order.cargoNote,
                    cargoWeight: order.cargoWeight,
                  ),
                ],
                if (order.hasNote) ...[
                  const SizedBox(height: AppSpacing.md),
                  _OrderNote(note: order.orderNote!.trim()),
                ],
                _OrderExtras(order: order),
                const SizedBox(height: AppSpacing.lg),
                _ClaimButton(
                  claiming: claiming,
                  disabled: disabled,
                  onClaim: onClaim,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopHeader extends StatelessWidget {
  final MarketOrder order;
  const _ShopHeader({required this.order});

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
                    order.isShopBatch && order.stopsCount > 1
                        ? '${order.shopTitle} · ${order.stopsCount} điểm'
                        : order.shopTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: _color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text('#${order.code}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    )),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Flexible(
                  child: Text(MarketOrderCard._age(order.openedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      )),
                ),
                const SizedBox(width: 7),
                const Icon(Icons.circle,
                    size: 4, color: AppColors.textTertiary),
                const SizedBox(width: 7),
                Text('Shop book',
                    style: AppTextStyles.caption.copyWith(
                      color: _color,
                      fontWeight: FontWeight.w700,
                    )),
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
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 310) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _identity,
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  Expanded(
                    child: Text('Khách cần trả',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        )),
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
        },
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

/// Tiền tài xế thu người nhận khi giao: thu hộ tiền hàng cho shop + phí ship.
class _ShopCollection extends StatelessWidget {
  final MarketOrder order;
  const _ShopCollection({required this.order});

  @override
  Widget build(BuildContext context) {
    if (order.collectAmount <= 0) {
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
          const Icon(Icons.money_off_rounded,
              size: 17, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Không thu hộ tiền hàng',
              style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: .18)),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: .14),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.payments_rounded,
                size: 18, color: AppColors.warning),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('TỔNG THU NGƯỜI NHẬN',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 9,
                  letterSpacing: .35,
                  fontWeight: FontWeight.w600,
                )),
          ),
          Text(Fmt.currency(order.receiverPayAmount),
              style: AppTextStyles.sectionTitle.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              )),
        ]),
        const SizedBox(height: AppSpacing.sm),
        const Divider(),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          Expanded(
            child: _ShopMoneyPart(
              label: 'THU HỘ SHOP',
              amount: order.collectAmount,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(
            height: 30,
            child: VerticalDivider(width: 20, color: AppColors.divider),
          ),
          Expanded(
            child: _ShopMoneyPart(
              label: 'PHÍ SHIP',
              amount: order.shippingFee,
              color: AppColors.textPrimary,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _ShopMoneyPart extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;

  const _ShopMoneyPart({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 2),
          Text(Fmt.currency(amount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyStrong.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              )),
        ],
      );
}

class _ClaimButton extends StatelessWidget {
  final bool claiming;
  final bool disabled;
  final VoidCallback onClaim;
  final String noun;

  const _ClaimButton({
    required this.claiming,
    required this.disabled,
    required this.onClaim,
    this.noun = 'đơn',
  });

  @override
  Widget build(BuildContext context) => SwipeButton(
        label: claiming ? 'Đang nhận $noun...' : 'Vuốt để nhận $noun',
        color: AppColors.primary,
        loading: claiming,
        onConfirm: disabled ? null : onClaim,
      );
}

class _OrderExtras extends StatelessWidget {
  final MarketOrder order;
  final bool includeRewards;
  final bool includeVoucher;
  const _OrderExtras({
    required this.order,
    this.includeRewards = true,
    this.includeVoucher = true,
  });

  bool get _visible =>
      order.nightSurcharge > 0 ||
      (includeRewards && order.bonusFee > 0) ||
      (includeRewards && order.isRainMode && order.rainBonusAmount > 0) ||
      order.isFreeship ||
      (includeVoucher && order.hasVoucher);

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        if (order.nightSurcharge > 0)
          _Chip(
            Icons.nightlight_round,
            'Phụ phí đêm ${Fmt.currency(order.nightSurcharge)}',
            tone: _ChipTone.night,
          ),
        if (includeRewards && order.bonusFee > 0)
          _Chip(
            Icons.add_circle_rounded,
            'Thưởng thêm ${Fmt.currency(order.bonusFee)}',
            tone: _ChipTone.success,
          ),
        if (includeRewards && order.isRainMode && order.rainBonusAmount > 0)
          _Chip(
            Icons.water_drop_rounded,
            'Thưởng mưa +${Fmt.currency(order.rainBonusAmount)}',
            tone: _ChipTone.rain,
          ),
        if (order.isFreeship)
          const _Chip(
            Icons.local_shipping_rounded,
            'Freeship',
            tone: _ChipTone.success,
          ),
        if (includeVoucher && order.hasVoucher)
          _Chip(
            Icons.confirmation_number_rounded,
            order.discountAmount > 0
                ? 'Voucher ${order.voucherCode} · giảm ${Fmt.currency(order.discountAmount)}'
                : 'Voucher ${order.voucherCode}',
            tone: _ChipTone.voucher,
          ),
      ]),
    );
  }
}

class _CustomerAppRewards extends StatelessWidget {
  final MarketOrder order;
  const _CustomerAppRewards({required this.order});

  @override
  Widget build(BuildContext context) {
    final rewards = <({IconData icon, String label, int amount, Color color})>[
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
      if (order.isRainMode && order.rainBonusAmount > 0)
        (
          icon: Icons.water_drop_rounded,
          label: 'THƯỞNG MƯA',
          amount: order.rainBonusAmount,
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
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              for (final reward in rewards)
                SizedBox(
                  width: rewards.length == 1 ? double.infinity : 132,
                  child: _RewardItem(reward: reward),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CallCenterRewards extends StatelessWidget {
  final MarketOrder order;
  const _CallCenterRewards({required this.order});

  @override
  Widget build(BuildContext context) {
    final rewards = <({IconData icon, String label, int amount, Color color})>[
      if (order.bonusFee > 0)
        (
          icon: Icons.card_giftcard_rounded,
          label: 'BONUS',
          amount: order.bonusFee,
          color: AppColors.success,
        ),
      if (order.isRainMode && order.rainBonusAmount > 0)
        (
          icon: Icons.water_drop_rounded,
          label: 'THƯỞNG MƯA',
          amount: order.rainBonusAmount,
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
            Expanded(child: _RewardItem(reward: rewards[i])),
          ],
        ],
      ),
    );
  }
}

class _RewardItem extends StatelessWidget {
  final ({IconData icon, String label, int amount, Color color}) reward;
  const _RewardItem({required this.reward});

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
                  letterSpacing: .45,
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
      ]);
}

class _DecisionMetrics extends StatelessWidget {
  final MarketOrder order;
  const _DecisionMetrics({required this.order});

  @override
  Widget build(BuildContext context) {
    final metrics =
        <({IconData icon, String label, String value, Color color})>[
      if (!order.hasMultipleShoppingStops) ...[
        (
          icon: Icons.near_me_rounded,
          label: Fmt.pickupDistanceLabel(order.serviceType),
          value: order.pickupDistanceKm == null
              ? 'Đang tính'
              : '${order.pickupDistanceKm!.toStringAsFixed(1)} km',
          color: AppColors.primary,
        ),
        if (Fmt.showsRouteDistance(order.serviceType))
          (
            icon: Icons.route_rounded,
            label: 'QUÃNG ĐƯỜNG',
            value: order.distance == null
                ? 'Chưa rõ'
                : '${order.distance!.toStringAsFixed(1)} km',
            color: AppColors.info,
          ),
      ],
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

    return Row(
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          if (i > 0)
            const SizedBox(
              height: 46,
              child: VerticalDivider(width: 17, color: AppColors.divider),
            ),
          Expanded(child: _DecisionMetric(metric: metrics[i])),
        ],
      ],
    );
  }
}

class _DecisionMetric extends StatelessWidget {
  final ({IconData icon, String label, String value, Color color}) metric;
  const _DecisionMetric({required this.metric});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(metric.icon, size: 14, color: metric.color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                metric.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 8,
                  letterSpacing: .35,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 5),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyStrong.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.sticky_note_2_rounded,
                size: 18,
                color: AppColors.warning,
              ),
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

class _MetaLabel extends StatelessWidget {
  final String text;
  const _MetaLabel({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          text,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _Route extends StatelessWidget {
  final String pickup;
  final String delivery;
  final Color color;
  final String pickupLabel;
  final String deliveryLabel;
  final bool showDelivery;
  const _Route({
    required this.pickup,
    required this.delivery,
    required this.color,
    this.pickupLabel = 'ĐIỂM LẤY',
    this.deliveryLabel = 'ĐIỂM GIAO',
    this.showDelivery = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RouteLabel(
            text: pickupLabel,
            icon: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: color, width: 3),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(
              pickup.isEmpty ? 'Chưa có điểm lấy' : pickup,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyStrong,
            ),
          ),
          if (showDelivery) ...[
            const SizedBox(height: AppSpacing.md),
            _RouteLabel(
              text: deliveryLabel,
              icon: const Icon(
                Icons.location_on_rounded,
                size: 18,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Text(
                delivery.isEmpty ? 'Không có địa chỉ giao' : delivery,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyStrong.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteLabel extends StatelessWidget {
  final String text;
  final Widget icon;
  const _RouteLabel({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(width: 18, child: Center(child: icon)),
          const SizedBox(width: AppSpacing.md),
          Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 9,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  final _ChipTone tone;
  const _Chip(
    this.icon,
    this.text, {
    this.tone = _ChipTone.neutral,
  });

  Color get _foreground => switch (tone) {
        _ChipTone.success => AppColors.success,
        _ChipTone.voucher => AppColors.secondary,
        _ChipTone.night => const Color(0xFF6655B5),
        _ChipTone.rain => AppColors.info,
        _ChipTone.neutral => AppColors.textSecondary,
      };

  Color get _background => switch (tone) {
        _ChipTone.success => AppColors.successSoft,
        _ChipTone.voucher => AppColors.secondarySoft,
        _ChipTone.night => const Color(0xFFF0EDFF),
        _ChipTone.rain => AppColors.infoSoft,
        _ChipTone.neutral => AppColors.surfaceAlt,
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: _foreground.withValues(
              alpha: tone != _ChipTone.neutral ? 0.12 : 0,
            ),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: _foreground),
          const SizedBox(width: 5),
          Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: _foreground,
            ),
          ),
        ]),
      );
}

enum _ChipTone { neutral, success, voucher, night, rain }
