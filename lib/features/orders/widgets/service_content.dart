import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/order_model.dart';
import 'info_row.dart';
import 'order_note_card.dart';
import 'route_block.dart';

// ────────────────────────────────────────────────────────────────────────────
// Service content — hiển thị theo từng loại dịch vụ
// ────────────────────────────────────────────────────────────────────────────

class ServiceContent extends StatelessWidget {
  final OrderModel order;
  const ServiceContent({super.key, required this.order});

  Color get color => Fmt.serviceColor(order.serviceType);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ── Header: icon + tên dịch vụ + mã đơn ─────────────────
      Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Fmt.serviceIcon(order.serviceType), color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              order.displayTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            Text(
              _serviceSubtitle(order.serviceType),
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ]),
        ),
        // Badge SHOP / BATCH
        if (order.isShopOrder) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              order.isBatch ? 'SHOP • ${order.stopsCount} ĐIỂM' : 'SHOP',
              style: const TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface, borderRadius: BorderRadius.circular(8),
          ),
          child: Text(order.code,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ),
      ]),

      // Shop order: hiện cargo type badge
      if (order.isShopOrder && order.cargoType != 'food') ...[
        const SizedBox(height: 8),
        CargoBadge(cargoType: order.cargoType, cargoNote: order.cargoNote,
            cargoWeight: order.cargoWeight),
      ],

      const SizedBox(height: 14),

      // ── Body theo loại dịch vụ ────────────────────────────────
      switch (order.serviceType) {
        'delivery' => DeliveryBody(order: order),
        'shopping' => ShoppingBody(order: order),
        'topup'    => TopupBody(order: order),
        'bike'     => BikeBody(order: order),
        _          => MotorCarBody(order: order),
      },

    ],
  );

  String _serviceSubtitle(String type) {
    if (order.isShopOrder) {
      return switch (order.shopServiceType) {
        'shop_pickup' => 'Đến điểm lấy, mang về cửa hàng',
        'shop_batch'  => 'Đến shop lấy, giao nhiều điểm',
        _             => 'Đến cửa hàng lấy, giao cho khách',
      };
    }
    return switch (type) {
      'delivery' => 'Lấy hàng và giao đến khách',
      'shopping' => 'Mua hàng rồi giao — ứng tiền trước',
      'topup'    => 'Nạp tiền điện thoại cho khách',
      'bike'     => 'Chở khách đến điểm đến',
      'motor'    => 'Lái xe máy của khách',
      'car'      => 'Lái ô tô của khách',
      _          => '',
    };
  }
}

// ── Delivery body ─────────────────────────────────────────────────────────────

class DeliveryBody extends StatelessWidget {
  final OrderModel order;
  const DeliveryBody({super.key, required this.order});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RouteBlock(
        pickupLabel:    'Lấy hàng tại',
        pickupPlaceName: order.isShopOrder
            ? (order.storeName?.isNotEmpty == true ? order.storeName : order.pickupPlaceName)
            : order.pickupPlaceName,
        pickupAddress:  order.pickupAddress,
        pickupPhone:    order.pickupPhone?.isNotEmpty == true ? order.pickupPhone : null,
        showNoPickupPhone: true,
        deliveryLabel:    'Giao đến',
        deliveryPlaceName: order.deliveryPlaceName?.isNotEmpty == true
            ? order.deliveryPlaceName
            : order.customerName,
        deliveryAddress: order.deliveryAddress,
        deliveryPhone:   order.deliveryPhone,
      ),
      if (order.orderNote?.isNotEmpty == true) ...[
        const SizedBox(height: 10),
        OrderNoteCard(note: order.orderNote!, label: 'Ghi chú'),
      ],
      if (order.cargoType != 'standard') ...[
        const SizedBox(height: 10),
        CargoBadge(cargoType: order.cargoType, cargoNote: order.cargoNote, cargoWeight: order.cargoWeight),
      ],
    ],
  );
}

// ── Shopping body ─────────────────────────────────────────────────────────────

class ShoppingBody extends StatelessWidget {
  final OrderModel order;
  const ShoppingBody({super.key, required this.order});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Cảnh báo ứng tiền
      if ((order.codAmount ?? 0) > 0)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shopping_cart_checkout_rounded, color: AppColors.warning, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Cần ứng tiền mua hàng', style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(Fmt.currency(order.codAmount!),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.warning)),
            ])),
          ]),
        ),
      RouteBlock(
        pickupLabel:    'Mua tại',
        pickupPlaceName: order.isShopOrder
            ? (order.storeName?.isNotEmpty == true ? order.storeName : order.pickupPlaceName)
            : order.pickupPlaceName,
        pickupAddress:  order.pickupAddress,
        pickupPhone:    order.pickupPhone?.isNotEmpty == true ? order.pickupPhone : null,
        deliveryLabel:    'Giao đến',
        deliveryPlaceName: order.deliveryPlaceName?.isNotEmpty == true
            ? order.deliveryPlaceName
            : order.customerName,
        deliveryAddress: order.deliveryAddress,
        deliveryPhone:   order.deliveryPhone,
      ),
      if (order.orderNote?.isNotEmpty == true) ...[
        const SizedBox(height: 10),
        OrderNoteCard(note: order.orderNote!, label: 'Danh sách / ghi chú'),
      ],
    ],
  );
}

// ── Topup body ────────────────────────────────────────────────────────────────

class TopupBody extends StatelessWidget {
  final OrderModel order;
  const TopupBody({super.key, required this.order});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InfoRow(
        icon: Icons.smartphone_rounded,
        iconColor: AppColors.success,
        label: 'Số điện thoại cần nạp',
        value: order.deliveryPhone,
      ),
      if ((order.codAmount ?? 0) > 0) ...[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1, color: AppColors.divider),
        ),
        InfoRow(
          icon: Icons.attach_money_rounded,
          iconColor: AppColors.warning,
          label: 'Số tiền nạp',
          value: Fmt.currency(order.codAmount!),
        ),
      ],
      if (order.orderNote?.isNotEmpty == true) ...[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1, color: AppColors.divider),
        ),
        InfoRow(
          icon: Icons.notes_rounded,
          iconColor: AppColors.textSecondary,
          label: 'Ghi chú (nhà mạng / loại thẻ)',
          value: order.orderNote!,
        ),
      ],
    ]),
  );
}

// ── Bike body ─────────────────────────────────────────────────────────────────

class BikeBody extends StatelessWidget {
  final OrderModel order;
  const BikeBody({super.key, required this.order});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RouteBlock(
        pickupLabel: 'Đón khách tại',
        pickupAddress: order.pickupAddress,
        deliveryLabel: 'Đến',
        deliveryAddress: order.deliveryAddress,
        deliveryPhone: order.deliveryPhone.isNotEmpty ? order.deliveryPhone : null,
        deliveryPhoneLabel: 'SĐT khách',
      ),
      if (order.orderNote?.isNotEmpty == true) ...[
        const SizedBox(height: 10),
        OrderNoteCard(note: order.orderNote!, label: 'Ghi chú'),
      ],
    ],
  );
}

// ── Motor / Car body ──────────────────────────────────────────────────────────

class MotorCarBody extends StatelessWidget {
  final OrderModel order;
  const MotorCarBody({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final isMotor = order.serviceType == 'motor';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RouteBlock(
          pickupLabel: isMotor ? 'Vị trí xe máy' : 'Vị trí ô tô',
          pickupAddress: order.pickupAddress,
          deliveryLabel: 'Lái đến',
          deliveryAddress: order.deliveryAddress,
          deliveryPhone: order.deliveryPhone.isNotEmpty ? order.deliveryPhone : null,
          deliveryPhoneLabel: 'SĐT chủ xe',
        ),
        if (order.orderNote?.isNotEmpty == true) ...[
          const SizedBox(height: 10),
          OrderNoteCard(note: order.orderNote!, label: 'Ghi chú'),
        ],
      ],
    );
  }
}
