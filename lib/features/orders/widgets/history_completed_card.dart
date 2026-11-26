import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launch_utils.dart';
import '../models/order_model.dart';
import 'call_center_pickup_details.dart';
import 'order_card_parts.dart';
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
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.sectionTitle.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (summary != null)
              Flexible(
                  child: Container(
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
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )),
          ],
        ),
      );
}

/// Thẻ một đơn đã hoàn thành — gọn cho danh sách dài: lướt là thấy kiếm
/// được bao nhiêu, đã thu khách bao nhiêu và đi tuyến nào. Cùng ngôn ngữ với
/// thẻ đơn mới / đang chạy (màu theo nguồn đơn, "Bạn nhận" màu xanh).
class HistoryCompletedCard extends StatelessWidget {
  final OrderModel order;

  const HistoryCompletedCard({super.key, required this.order});

  Color get _accent => order.isShopOrder
      ? AppColors.secondary
      : order.isCallCenter
          ? AppColors.primary
          : Fmt.serviceColor(order.serviceType);

  IconData get _icon => order.isShopOrder
      ? Icons.storefront_rounded
      : order.isCallCenter
          ? Icons.support_agent_rounded
          : Fmt.serviceIcon(order.serviceType);

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

  String get _pickup => order.storeName?.isNotEmpty == true
      ? order.storeName!
      : order.pickupPlaceName?.isNotEmpty == true
          ? order.pickupPlaceName!
          : order.pickupAddress;

  String get _delivery => order.isBatch && order.stopsCount > 1
      ? '${order.stopsCount} điểm giao'
      : order.deliveryPlaceName?.isNotEmpty == true
          ? order.deliveryPlaceName!
          : order.deliveryAddress.isNotEmpty
              ? order.deliveryAddress
              : (order.customerName ?? '');

  /// Dòng "đã thu khách" — điều tài xế cần đối chiếu khi xem lại.
  String get _collected {
    final who = order.isShopOrder ? 'người nhận' : 'khách';
    if (order.customerCollectionAmount == 0) {
      return order.platformFreeship
          ? 'Freeship · không thu $who'
          : 'Không thu tiền $who';
    }
    final cod = order.codAmount ?? 0;
    final codWord = order.isShopOrder
        ? 'thu hộ'
        : order.serviceType == 'topup'
            ? 'tiền nạp'
            : 'tiền hàng';
    final detail = cod > 0
        ? ' · ${feeWord(order.serviceType)} ${moneyShort(order.customerShippingFee)} + $codWord ${moneyShort(cod)}'
        : '';
    return 'Đã thu $who ${Fmt.currency(order.customerCollectionAmount)}$detail';
  }

  String get _pickupLabel {
    if (order.isShopOrder) {
      return order.shopServiceType == 'shop_pickup'
          ? 'ĐIỂM LẤY HỘ'
          : 'LẤY TẠI SHOP';
    }
    return Fmt.pickupLabel(order.serviceType);
  }

  String get _deliveryLabel {
    if (order.isShopOrder) {
      return order.shopServiceType == 'shop_pickup'
          ? 'ĐÃ MANG VỀ SHOP'
          : 'ĐÃ GIAO ĐẾN';
    }
    return Fmt.deliveryLabel(order.serviceType);
  }

  String get _earnNote {
    final fee = feeWord(order.serviceType);
    return <String>[
      order.platformFreeship
          ? 'cty trả $fee ${moneyShort(order.shippingFee)}'
          : '$fee ${moneyShort(order.shippingFee)}',
      if (order.discountAmount > 0)
        'bù voucher ${moneyShort(order.discountAmount)}',
      if (order.bonusFee > 0) 'thưởng ${moneyShort(order.bonusFee)}',
      if (order.rainBonusEligible && order.rainBonusConfirmedAmount > 0)
        'mưa ${moneyShort(order.rainBonusConfirmedAmount)}',
    ].join(' + ');
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final local = (order.completedAt ?? order.createdAt).toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final showDelivery = !order.isCallCenter &&
        (order.isShopOrder || Fmt.showsDeliveryPoint(order.serviceType)) &&
        _delivery.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: AppBrand.gradient,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(_icon, size: 20, color: AppBrand.ink),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _title,
                        style: AppTextStyles.bodyStrong.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '#${order.code}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 13, color: AppColors.success),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '$time · $_source',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Bạn nhận — con số chính của lịch sử.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: .65),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'BẠN NHẬN',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.success,
                        fontSize: 11,
                        letterSpacing: .4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        Fmt.currency(order.driverEarning),
                        style: AppTextStyles.metric.copyWith(
                          color: AppColors.success,
                          fontSize: AppFontSize.lg,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.divider,
              ),
            ),
            child: Column(
              children: [
                _Point(
                  label: _pickupLabel,
                  text: _pickup,
                  color: accent,
                  filled: true,
                  hasNext: showDelivery,
                ),
                if (showDelivery)
                  _Point(
                    label: _deliveryLabel,
                    text: _delivery,
                    color: AppColors.success,
                    filled: false,
                    hasNext: false,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: AppColors.divider,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _collected,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (order.topupAmount > 0)
                  Text(
                    'Đã nạp ${Fmt.currency(order.topupAmount)}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  'Bạn nhận: $_earnNote',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (order.orderNote?.trim().isNotEmpty == true)
            _Details(order: order),
        ],
      ),
    );
  }
}

/// Ghi chú (SĐT tổng đài, danh sách mua hộ…) thu gọn sau nút "Xem chi tiết" —
/// lịch sử vẫn cần khi phải gọi lại khách / đối chiếu, nhưng không làm dài
/// mọi thẻ trong danh sách.
class _Details extends StatefulWidget {
  final OrderModel order;
  const _Details({required this.order});

  @override
  State<_Details> createState() => _DetailsState();
}

class _DetailsState extends State<_Details> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final note = order.orderNote!.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _open = !_open),
            icon: Icon(
              _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 18,
            ),
            label: Text(_open ? 'Ẩn chi tiết' : 'Xem chi tiết'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.success,
              backgroundColor: AppColors.successSoft.withValues(alpha: .7),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 40),
              shape: const StadiumBorder(),
            ),
          ),
        ),
        if (_open)
          if (order.isCallCenter)
            CallCenterPickupDetails(
              pickupAddress: order.pickupAddress,
              pickupLat: order.pickupLat,
              pickupLng: order.pickupLng,
              note: note,
              onOpenMap: order.pickupLat != null && order.pickupLng != null
                  ? () => launchNavigation(
                        lat: order.pickupLat,
                        lng: order.pickupLng,
                        address: order.pickupAddress,
                      )
                  : null,
            )
          else if (order.serviceType == 'shopping' && !order.isShopOrder)
            ShoppingOrderNote(note: note)
          else
            OrderNoteBlock(note: note),
      ],
    );
  }
}

class _Point extends StatelessWidget {
  final String label;
  final String text;
  final Color color;
  final bool filled;
  final bool hasNext;

  const _Point({
    required this.label,
    required this.text,
    required this.color,
    required this.filled,
    required this.hasNext,
  });

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 38,
            child: Column(children: [
              const SizedBox(height: 4),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: filled ? color : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: .16),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
              if (hasNext)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: AppColors.divider,
                  ),
                ),
            ]),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: hasNext ? 6 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      letterSpacing: .4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]),
      );
}
