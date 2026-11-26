import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launch_utils.dart';
import '../models/order_model.dart';
import 'batch_stops_card.dart';
import 'call_center_pickup_details.dart';
import 'info_row.dart' show CargoBadge;
import 'order_card_parts.dart';
import 'shopping_order_note.dart';
import 'swipe_button.dart';

/// Thẻ đơn đang chạy — một bố cục chung cho mọi nguồn đơn (khách app, shop,
/// tổng đài). Nhìn vào là trả lời được 3 câu: thu khách bao nhiêu, mình nhận
/// bao nhiêu, đi đâu làm gì tiếp:
///   1. Đầu thẻ: dịch vụ, mã, trạng thái, nguồn đơn.
///   2. Dải tiền 2 cột: THU KHÁCH | BẠN NHẬN (kèm diễn giải ngắn).
///   3. Lộ trình dạng dòng thời gian, bước đang tới tô đậm, nút Gọi/Chỉ đường to.
///   4. Ghi chú, hàng hoá, điểm giao đơn gộp; cuối cùng là nút vuốt.
class RunningOrderView extends StatelessWidget {
  final OrderModel order;
  final String? positionLabel;
  final bool actionLoading;
  final VoidCallback onAction;
  final Future<void> Function() onBatchCompleted;

  const RunningOrderView({
    super.key,
    required this.order,
    required this.positionLabel,
    required this.actionLoading,
    required this.onAction,
    required this.onBatchCompleted,
  });

  Color get _accent => order.isShopOrder
      ? AppColors.secondary
      : order.isCallCenter
          ? AppColors.primary
          : Fmt.serviceColor(order.serviceType);

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
          _RunHeader(
              order: order, accent: accent, positionLabel: positionLabel),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MoneyStrip(order: order),
                if (order.topupAmount > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  OrderInfoLine(
                    icon: Icons.payments_rounded,
                    color: AppColors.success,
                    text: 'Số tiền cần nạp ${Fmt.currency(order.topupAmount)}',
                  ),
                ],
                // Chỉ nhắc ứng tiền trước khi lấy hàng; lấy xong thì không cần nữa.
                if (order.shopPaymentAmount > 0 &&
                    order.status == 'assigned') ...[
                  const SizedBox(height: AppSpacing.sm),
                  OrderInfoLine(
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.warningStrong,
                    text:
                        'Ứng trả shop ${Fmt.currency(order.shopPaymentAmount)} khi lấy hàng',
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                if (order.isCallCenter)
                  // Ghi chú tổng đài mang cả điểm lấy/giao và số điện thoại —
                  // component riêng tách sẵn từng điểm, bấm gọi được.
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
                  _RouteTimeline(order: order, accent: accent),
                if (order.isShopOrder && order.cargoType != 'food') ...[
                  const SizedBox(height: AppSpacing.md),
                  CargoBadge(
                    cargoType: order.cargoType,
                    cargoNote: order.cargoNote,
                    cargoWeight: order.cargoWeight,
                  ),
                ],
                if (!order.isCallCenter &&
                    order.orderNote?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: AppSpacing.md),
                  if (order.serviceType == 'shopping' && !order.isShopOrder)
                    ShoppingOrderNote(note: order.orderNote!.trim())
                  else
                    OrderNoteBlock(note: order.orderNote!.trim()),
                ],
                if (order.isBatch &&
                    order.status == 'processing' &&
                    order.stops.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  BatchStopsCard(order: order, onCompleted: onBatchCompleted),
                ],
                if (order.nextAction.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SwipeButton(
                    brandStyle: true,
                    label: actionLoading
                        ? 'Đang cập nhật...'
                        : 'Vuốt để ${order.nextAction}',
                    color: AppColors.primary,
                    loading: actionLoading,
                    onConfirm: actionLoading ? null : onAction,
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

// ── 1. Đầu thẻ ────────────────────────────────────────────────────────────────

class _RunHeader extends StatelessWidget {
  final OrderModel order;
  final Color accent;
  final String? positionLabel;

  const _RunHeader({
    required this.order,
    required this.accent,
    required this.positionLabel,
  });

  String get _title {
    if (!order.isShopOrder) return Fmt.serviceLabel(order.serviceType);
    return order.isBatch && order.stopsCount > 1
        ? '${order.displayTitle} · ${order.stopsCount} điểm'
        : order.displayTitle;
  }

  String get _source => order.isShopOrder
      ? 'Shop book'
      : order.isCallCenter
          ? 'Tổng đài'
          : 'Khách đặt app';

  IconData get _icon => order.isShopOrder
      ? Icons.storefront_rounded
      : order.isCallCenter
          ? Icons.support_agent_rounded
          : Fmt.serviceIcon(order.serviceType);

  @override
  Widget build(BuildContext context) {
    final statusColor =
        order.status == 'assigned' ? AppColors.info : AppColors.primary;
    return OrderCardHeader(
      icon: _icon,
      accent: accent,
      title: _title,
      code: order.code,
      pill: positionLabel,
      emphasized: true,
      brandStyle: true,
      meta: [
        (text: order.statusLabel, color: statusColor, strong: true),
        (text: _source, color: accent, strong: true),
      ],
    );
  }
}

// ── 2. Dải tiền ───────────────────────────────────────────────────────────────

class _MoneyStrip extends StatelessWidget {
  final OrderModel order;
  const _MoneyStrip({required this.order});

  String get _feeWord => feeWord(order.serviceType);

  String get _codWord => order.isShopOrder
      ? 'thu hộ'
      : order.serviceType == 'topup'
          ? 'tiền nạp'
          : 'tiền hàng';

  String get _collectNote {
    final cod = order.codAmount ?? 0;
    final parts = <String>[
      if (order.platformFreeship)
        'freeship, không thu $_feeWord'
      else
        '$_feeWord ${moneyShort(order.shippingFee)}',
      if (cod > 0) '$_codWord ${moneyShort(cod)}',
    ];
    final night = order.nightSurcharge > 0 && !order.platformFreeship
        ? ' · gồm đêm ${moneyShort(order.nightSurcharge)}'
        : '';
    // Shop không thu hộ: nói rõ để tài xế khỏi phải hỏi lại.
    final noCod = order.isShopOrder && (order.codAmount ?? 0) == 0
        ? ' · không thu hộ'
        : '';
    return parts.join(' + ') + night + noCod;
  }

  String get _earnNote {
    final parts = <String>[
      order.platformFreeship
          ? 'cty trả $_feeWord ${moneyShort(order.shippingFee)}'
          : '$_feeWord ${moneyShort(order.shippingFee)}',
      if (order.discountAmount > 0)
        'bù voucher ${moneyShort(order.discountAmount)}',
      if (order.bonusFee > 0) 'thưởng ${moneyShort(order.bonusFee)}',
      if (order.rainBonusEligible && order.rainBonusConfirmedAmount > 0)
        'mưa ${moneyShort(order.rainBonusConfirmedAmount)}',
    ];
    return parts.join(' + ');
  }

  @override
  Widget build(BuildContext context) => OrderMoneyStrip(
        collectLabel: order.isShopOrder ? 'THU NGƯỜI NHẬN' : 'THU KHÁCH',
        collect: order.customerCollectionAmount,
        collectNote: _collectNote,
        earn: order.driverEarning,
        earnNote: _earnNote,
        highlightEarn: true,
      );
}

// ── 3. Lộ trình ───────────────────────────────────────────────────────────────

typedef _Stop = ({
  String label,
  String name,
  String address,
  String? phone,
  double? lat,
  double? lng,
});

class _RouteTimeline extends StatelessWidget {
  final OrderModel order;
  final Color accent;

  const _RouteTimeline({required this.order, required this.accent});

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

  List<_Stop> get _stops {
    final pickupOnly = order.shopServiceType == 'shop_pickup';
    final pickup = (
      label: order.isShopOrder
          ? (pickupOnly ? 'ĐIỂM LẤY HỘ' : 'LẤY TẠI SHOP')
          : Fmt.pickupLabel(order.serviceType),
      name: _pickupName,
      address: order.pickupAddress,
      phone: order.serviceType == 'topup'
          ? order.deliveryPhone
          : order.pickupPhone,
      lat: order.pickupLat,
      lng: order.pickupLng,
    );
    // Đơn gộp: các điểm giao nằm ở thẻ "Các điểm giao" bên dưới.
    final hasDelivery = !order.isBatch &&
        (order.isShopOrder || Fmt.showsDeliveryPoint(order.serviceType)) &&
        (order.deliveryAddress.isNotEmpty || _deliveryName.isNotEmpty);
    return [
      pickup,
      if (hasDelivery)
        (
          label: order.isShopOrder
              ? (pickupOnly ? 'MANG VỀ SHOP' : 'GIAO ĐẾN')
              : Fmt.deliveryLabel(order.serviceType),
          name: _deliveryName,
          address: order.deliveryAddress,
          phone: order.deliveryPhone,
          lat: order.deliveryLat,
          lng: order.deliveryLng,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final stops = _stops;
    // Bước đang tới: chưa lấy hàng → điểm lấy; đã lấy → điểm giao.
    final current = order.status == 'assigned' ? 0 : stops.length - 1;
    final showDistance = (order.distance ?? 0) > 0 &&
        Fmt.showsRouteDistance(order.serviceType) &&
        !order.hasMultipleShoppingStops;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showDistance)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(children: [
                const Icon(Icons.route_rounded,
                    size: 15, color: AppColors.info),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Quãng đường ${order.distance!.toStringAsFixed(1)} km',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ]),
            ),
          for (var i = 0; i < stops.length; i++)
            _StopRow(
              stop: stops[i],
              state: i < current
                  ? _StopState.done
                  : i == current
                      ? _StopState.current
                      : _StopState.next,
              isLast: i == stops.length - 1,
              accent: accent,
            ),
        ],
      ),
    );
  }
}

enum _StopState { done, current, next }

class _StopRow extends StatelessWidget {
  final _Stop stop;
  final _StopState state;
  final bool isLast;
  final Color accent;

  const _StopRow({
    required this.stop,
    required this.state,
    required this.isLast,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final current = state == _StopState.current;
    final done = state == _StopState.done;
    final dotColor =
        done ? AppColors.success : (current ? accent : AppColors.textTertiary);
    final showAddress =
        stop.address.isNotEmpty && stop.address.trim() != stop.name.trim();
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Cột mốc + đường nối tới điểm sau.
        SizedBox(
          width: 22,
          child: Column(children: [
            const SizedBox(height: 2),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: current ? dotColor : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: dotColor, width: 2),
                boxShadow: current
                    ? [
                        BoxShadow(
                          color: dotColor.withValues(alpha: .22),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: done
                  ? const Icon(Icons.check_rounded,
                      size: 12, color: AppColors.success)
                  : null,
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
          child: Container(
            margin:
                EdgeInsets.only(bottom: isLast ? AppSpacing.sm : AppSpacing.md),
            padding: current ? const EdgeInsets.all(AppSpacing.sm) : null,
            decoration: current
                ? BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: AppColors.primaryDark.withValues(alpha: .6),
                    ),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        stop.label,
                        style: AppTextStyles.caption.copyWith(
                          color: done
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontSize: 12,
                          letterSpacing: .5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (current) _StepTag(text: 'Đang tới', color: accent),
                      if (done)
                        const _StepTag(
                            text: 'Đã xong', color: AppColors.success),
                    ]),
                const SizedBox(height: 3),
                Text(
                  stop.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontSize: 16,
                    color:
                        done ? AppColors.textSecondary : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (showAddress && !done) ...[
                  const SizedBox(height: 2),
                  Text(
                    stop.address,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
                // Điểm đã xong thu gọn; điểm đang tới/kế tiếp có nút to để bấm khi chạy xe.
                if (!done) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(children: [
                    if (stop.phone?.trim().isNotEmpty == true) ...[
                      Expanded(
                        // Hiện luôn số: tài xế cần đọc/nhắn được, không chỉ bấm gọi.
                        child: _ActionButton(
                          icon: Icons.call_rounded,
                          label: stop.phone!.trim(),
                          color: AppColors.info,
                          filled: false,
                          onTap: () => launchPhoneCall(stop.phone!),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.near_me_rounded,
                        label: 'Chỉ đường',
                        color: current ? accent : AppColors.textSecondary,
                        filled: current,
                        onTap: () => launchNavigation(
                          lat: stop.lat,
                          lng: stop.lng,
                          address: stop.address.isNotEmpty
                              ? stop.address
                              : stop.name,
                        ),
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _StepTag extends StatelessWidget {
  final String text;
  final Color color;
  const _StepTag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: color.withValues(alpha: .15)),
        ),
        child: Text(
          text,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: filled ? color.withValues(alpha: .13) : AppColors.surface,
        elevation: filled ? 1 : 0,
        shadowColor: color.withValues(alpha: .18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(
            color: color.withValues(alpha: filled ? .18 : .3),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: ConstrainedBox(
            // Vùng bấm đủ lớn khi đang chạy xe.
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  // Chữ to: thu nhỏ cho vừa nút, không cắt mất số điện thoại.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: AppTextStyles.label.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
