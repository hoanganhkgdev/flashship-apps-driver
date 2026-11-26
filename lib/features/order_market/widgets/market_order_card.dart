import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launch_utils.dart';
import '../models/market_order.dart';
import '../../orders/widgets/call_center_pickup_details.dart';
import '../../orders/widgets/info_row.dart' show CargoBadge;
import '../../orders/widgets/order_card_parts.dart';
import '../../orders/widgets/shopping_order_note.dart';
import '../../orders/widgets/swipe_button.dart';

/// Thẻ một đơn mới (tab Đơn mới) — cùng bố cục với thẻ đơn đang chạy để tài xế
/// quen một kiểu đọc, nhưng sắp cho việc QUYẾT ĐỊNH nhận đơn:
///   1. Đầu thẻ: dịch vụ, mã, đăng bao lâu, nguồn đơn.
///   2. Dải tiền THU KHÁCH | BẠN NHẬN, ô "Bạn nhận" tô nổi.
///   3. Khoảng cách tới điểm lấy + quãng đường.
///   4. Lộ trình gọn (lấy → giao), ghi chú, hàng hoá.
///   5. Nút vuốt nhận đơn.
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

  Color get _accent => order.isShopOrder
      ? AppColors.secondary
      : order.isCallCenter
          ? AppColors.primary
          : Fmt.serviceColor(order.serviceType);

  /// Freeship do tổng đài bật (không voucher): khách không trả phí ship, công
  /// ty trả nguyên phí cho tài xế — cùng điều kiện backend (platform_freeship).
  bool get _platformFreeship =>
      order.isFreeship && !order.hasVoucher && order.discountAmount <= 0;

  String get _title {
    if (order.isShopOrder) {
      return order.isShopBatch && order.stopsCount > 1
          ? '${order.shopTitle} · ${order.stopsCount} điểm'
          : order.shopTitle;
    }
    return Fmt.serviceLabel(order.serviceType);
  }

  String get _source => order.isShopOrder
      ? 'Shop book'
      : order.isCallCenter
          ? 'Đơn do tổng đài tạo'
          : 'Khách đặt app';

  IconData get _icon => order.isShopOrder
      ? Icons.storefront_rounded
      : order.isCallCenter
          ? Icons.support_agent_rounded
          : Fmt.serviceIcon(order.serviceType);

  static String _age(DateTime openedAt) {
    final minutes = DateTime.now().difference(openedAt).inMinutes;
    if (minutes < 1) return 'vừa đăng';
    if (minutes < 60) return '$minutes phút trước';
    return '${minutes ~/ 60} giờ trước';
  }

  // ── Tiền ───────────────────────────────────────────────────────────────────

  int get _collect =>
      (_platformFreeship ? 0 : order.shippingFee) + order.codAmount;

  String get _codWord => order.isShopOrder
      ? 'thu hộ'
      : order.serviceType == 'topup'
          ? 'tiền nạp'
          : 'tiền hàng';

  String get _collectNote {
    final fee = feeWord(order.serviceType);
    final parts = <String>[
      if (_platformFreeship)
        'freeship, không thu $fee'
      else
        '$fee ${moneyShort(order.shippingFee)}',
      if (order.codAmount > 0) '$_codWord ${moneyShort(order.codAmount)}',
    ];
    final night = order.nightSurcharge > 0 && !_platformFreeship
        ? ' · gồm đêm ${moneyShort(order.nightSurcharge)}'
        : '';
    // Shop không thu hộ: nói rõ để tài xế khỏi phải hỏi lại.
    final noCod =
        order.isShopOrder && order.codAmount == 0 ? ' · không thu hộ' : '';
    return parts.join(' + ') + night + noCod;
  }

  String get _earnNote {
    final fee = feeWord(order.serviceType);
    return <String>[
      _platformFreeship
          ? 'cty trả $fee ${moneyShort(order.shippingFee)}'
          : '$fee ${moneyShort(order.shippingFee)}',
      if (order.discountAmount > 0)
        'bù voucher ${moneyShort(order.discountAmount)}',
      if (order.bonusFee > 0) 'thưởng ${moneyShort(order.bonusFee)}',
      if (order.isRainMode && order.rainBonusAmount > 0)
        'mưa ${moneyShort(order.rainBonusAmount)}',
    ].join(' + ');
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider, width: 1.25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrderCardHeader(
            icon: _icon,
            accent: accent,
            title: _title,
            code: order.code,
            pill: 'ĐƠN MỚI',
            emphasized: true,
            brandStyle: true,
            meta: [
              (
                text: _age(order.openedAt),
                color: AppColors.textSecondary,
                strong: false
              ),
              (text: _source, color: accent, strong: true),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OrderMoneyStrip(
                  collectLabel:
                      order.isShopOrder ? 'THU NGƯỜI NHẬN' : 'THU KHÁCH',
                  collect: _collect,
                  collectNote: _collectNote,
                  earn: order.estimatedIncome,
                  earnNote: _earnNote,
                  highlightEarn: true,
                ),
                if (order.topupAmount > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  OrderInfoLine(
                    icon: Icons.payments_rounded,
                    color: AppColors.success,
                    text: 'Số tiền cần nạp ${Fmt.currency(order.topupAmount)}',
                  ),
                ],
                if (order.shopPaymentAmount > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  OrderInfoLine(
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.warningStrong,
                    text:
                        'Ứng trả shop ${Fmt.currency(order.shopPaymentAmount)} khi lấy hàng',
                  ),
                ],
                if (!order.hasMultipleShoppingStops) ...[
                  const SizedBox(height: AppSpacing.md),
                  _Distances(order: order),
                ],
                const SizedBox(height: AppSpacing.md),
                if (order.isCallCenter)
                  // Ghi chú tổng đài mang điểm lấy/giao và số điện thoại.
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
                  )
                else
                  _CompactRoute(order: order, accent: accent),
                if (order.isShopOrder && order.cargoType != 'food') ...[
                  const SizedBox(height: AppSpacing.md),
                  CargoBadge(
                    cargoType: order.cargoType,
                    cargoNote: order.cargoNote,
                    cargoWeight: order.cargoWeight,
                  ),
                ],
                if (!order.isCallCenter && order.hasNote) ...[
                  const SizedBox(height: AppSpacing.md),
                  if (order.serviceType == 'shopping' && !order.isShopOrder)
                    ShoppingOrderNote(note: order.orderNote!.trim())
                  else
                    OrderNoteBlock(note: order.orderNote!.trim()),
                ],
                const SizedBox(height: AppSpacing.lg),
                SwipeButton(
                  brandStyle: true,
                  label: claiming
                      ? 'Đang nhận...'
                      : 'Vuốt để nhận ${Fmt.claimNoun(order.serviceType)}',
                  color: disabled && !claiming
                      ? AppColors.textTertiary
                      : AppColors.primary,
                  loading: claiming,
                  onConfirm: disabled || claiming ? null : onClaim,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Khoảng cách ───────────────────────────────────────────────────────────────

class _Distances extends StatelessWidget {
  final MarketOrder order;
  const _Distances({required this.order});

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label, String value, Color color})>[
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
    ];
    return Row(children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(children: [
              Icon(items[i].icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chữ to: thu nhỏ nhãn cho vừa, không cắt "QUÃNG ĐƯ…".
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        items[i].label,
                        maxLines: 1,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          letterSpacing: .3,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      items[i].value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    ]);
  }
}

// ── Lộ trình gọn ──────────────────────────────────────────────────────────────

class _CompactRoute extends StatelessWidget {
  final MarketOrder order;
  final Color accent;

  const _CompactRoute({required this.order, required this.accent});

  @override
  Widget build(BuildContext context) {
    final pickupOnly = order.shopServiceType == 'shop_pickup';
    final pickupLabel = order.isShopOrder
        ? (pickupOnly ? 'ĐIỂM LẤY HỘ' : 'LẤY TẠI SHOP')
        : Fmt.pickupLabel(order.serviceType);
    final deliveryLabel = order.isShopOrder
        ? (pickupOnly
            ? 'MANG VỀ SHOP'
            : order.isShopBatch && order.stopsCount > 1
                ? 'GIAO ${order.stopsCount} ĐIỂM'
                : 'GIAO ĐẾN')
        : Fmt.deliveryLabel(order.serviceType);
    // Shop: tên cửa hàng là điểm lấy, địa chỉ ghi bên dưới.
    final pickupName = order.isShopOrder ? order.shopName : order.pickupAddress;
    final pickupAddress = order.isShopOrder ? order.pickupAddress : '';
    final showDelivery =
        order.isShopOrder || Fmt.showsDeliveryPoint(order.serviceType);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(children: [
        _RoutePoint(
          label: pickupLabel,
          name: pickupName,
          address: pickupAddress,
          color: accent,
          filled: true,
          isLast: !showDelivery,
        ),
        if (showDelivery)
          _RoutePoint(
            label: deliveryLabel,
            // Đơn gộp: danh sách điểm giao chỉ có sau khi nhận đơn.
            name: order.isShopBatch && order.stopsCount > 1
                ? '${order.stopsCount} điểm giao · xem sau khi nhận'
                : order.deliveryAddress.isNotEmpty
                    ? order.deliveryAddress
                    : order.hasNote
                        ? 'Xem trong ghi chú'
                        : 'Chưa có địa chỉ giao',
            address: '',
            color: AppColors.success,
            filled: false,
            isLast: true,
          ),
      ]),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  final String label;
  final String name;
  final String address;
  final Color color;
  final bool filled;
  final bool isLast;

  const _RoutePoint({
    required this.label,
    required this.name,
    required this.address,
    required this.color,
    required this.filled,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 20,
            child: Column(children: [
              const SizedBox(height: 3),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: filled ? color : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: .18),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: AppColors.divider,
                  ),
                ),
            ]),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      letterSpacing: .5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (address.isNotEmpty && address.trim() != name.trim())
                    Text(
                      address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ]),
      );
}
