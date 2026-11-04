import '../../../core/utils/formatters.dart';

class OrderModel {
  final int id;
  final String code;
  final String serviceType;
  final String status;
  final String? driverOrderRole;
  final int? mainOrderId;
  final DateTime? bundleWindowExpiresAt;
  final String? pickupName;
  final String? pickupPlaceName;
  final String pickupAddress;
  final String? pickupPhone;
  final String? customerName;
  final String? customerPhone;
  final String? deliveryPlaceName;
  final String deliveryAddress;
  final String deliveryPhone;
  final String? orderNote;
  final String? storeName;
  final String platform;
  final String? shopServiceType;
  final String cargoType;
  final String? cargoNote;
  final double? cargoWeight;
  final bool isBatch;
  final int stopsCount;
  final List<Map<String, dynamic>> stops;
  final double? distance;
  final int shippingFee;
  final int bonusFee;
  final int nightSurcharge;
  final bool isRainMode;
  final int rainBonusAmount;
  // Khác với isRainMode/rainBonusAmount (xem trước lúc CHƯA nhận, ở màn
  // Offer) — 2 field này là giá trị ĐÃ CHỐT cho đơn đã nhận (rain_bonus_
  // eligible chốt lúc acceptOrder(), không đổi lại theo trạng thái mưa hiện
  // tại nữa dù sau đó tắt/bật lại giữa chừng).
  final bool rainBonusEligible;
  final int rainBonusConfirmedAmount;
  final int discountAmount;
  final String? voucherCode;
  final String paymentMethod;
  final int? codAmount;
  final DateTime createdAt;
  final DateTime? completedAt;
  final double? pickupLat;
  final double? pickupLng;
  final double? deliveryLat;
  final double? deliveryLng;

  const OrderModel({
    required this.id,
    required this.code,
    required this.serviceType,
    required this.status,
    this.driverOrderRole,
    this.mainOrderId,
    this.bundleWindowExpiresAt,
    this.pickupName,
    this.pickupPlaceName,
    required this.pickupAddress,
    this.pickupPhone,
    this.customerName,
    this.customerPhone,
    this.deliveryPlaceName,
    required this.deliveryAddress,
    required this.deliveryPhone,
    this.orderNote,
    this.storeName,
    this.platform = 'customer_app',
    this.shopServiceType,
    this.cargoType = 'food',
    this.cargoNote,
    this.cargoWeight,
    this.isBatch = false,
    this.stopsCount = 0,
    this.stops = const [],
    this.distance,
    required this.shippingFee,
    this.bonusFee = 0,
    this.nightSurcharge = 0,
    this.isRainMode = false,
    this.rainBonusAmount = 0,
    this.rainBonusEligible = false,
    this.rainBonusConfirmedAmount = 0,
    this.discountAmount = 0,
    this.voucherCode,
    required this.paymentMethod,
    this.codAmount,
    required this.createdAt,
    this.completedAt,
    this.pickupLat,
    this.pickupLng,
    this.deliveryLat,
    this.deliveryLng,
  });

  factory OrderModel.fromJson(Map<String, dynamic> j) => OrderModel(
        id: ((j['id'] ?? j['order_id']) as num).toInt(),
        code: j['code'] as String? ?? j['order_code'] as String? ?? '',
        serviceType: j['service_type'] as String? ?? 'delivery',
        status: j['status'] as String? ?? 'pending',
        driverOrderRole: j['driver_order_role'] as String?,
        mainOrderId: (j['main_order_id'] as num?)?.toInt(),
        bundleWindowExpiresAt: j['bundle_window_expires_at'] != null
            ? DateTime.tryParse(j['bundle_window_expires_at'].toString())
            : null,
        pickupName: (j['pickup_name'] as String?)?.isNotEmpty == true
            ? j['pickup_name'] as String
            : (j['sender_name'] as String?)?.isNotEmpty == true
                ? j['sender_name'] as String
                : null,
        pickupPlaceName: j['pickup_place_name'] as String?,
        pickupAddress: j['pickup_address'] as String? ?? '',
        pickupPhone: j['pickup_phone'] as String?,
        customerName: (j['receiver_name'] as String?)?.isNotEmpty == true
            ? j['receiver_name'] as String
            : (j['customer'] as Map<String, dynamic>?)?['name'] as String?,
        customerPhone:
            (j['customer'] as Map<String, dynamic>?)?['phone'] as String? ??
                j['customer_phone'] as String?,
        deliveryPlaceName: j['delivery_place_name'] as String?,
        deliveryAddress: j['delivery_address'] as String? ?? '',
        deliveryPhone: j['delivery_phone'] as String? ?? '',
        orderNote: j['order_note'] as String?,
        storeName: j['store_name'] as String?,
        platform: j['platform'] as String? ?? 'customer_app',
        shopServiceType: j['shop_service_type'] as String?,
        cargoType: j['cargo_type'] as String? ?? 'food',
        cargoNote: j['cargo_note'] as String?,
        cargoWeight: (j['cargo_weight'] as num?)?.toDouble(),
        isBatch: j['is_batch'] as bool? ?? false,
        stopsCount: (j['stops_count'] as num?)?.toInt() ?? 0,
        stops: (j['stops'] as List? ?? []).cast<Map<String, dynamic>>(),
        distance: double.tryParse(j['distance']?.toString() ?? ''),
        shippingFee: (j['shipping_fee'] as num?)?.toInt() ?? 0,
        bonusFee: (j['bonus_fee'] as num?)?.toInt() ?? 0,
        nightSurcharge: (j['night_surcharge'] as num?)?.toInt() ?? 0,
        isRainMode: j['is_rain_mode'] as bool? ?? false,
        rainBonusAmount: (j['rain_bonus_amount'] as num?)?.toInt() ?? 0,
        rainBonusEligible: j['rain_bonus_eligible'] as bool? ?? false,
        rainBonusConfirmedAmount:
            (j['rain_bonus_amount'] as num?)?.toInt() ?? 0,
        discountAmount: (j['discount_amount'] as num?)?.toInt() ?? 0,
        voucherCode: j['voucher_code'] as String?,
        paymentMethod: j['payment_method'] as String? ?? 'prepaid',
        codAmount: (j['cod_amount'] as num?)?.toInt(),
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
        completedAt: j['completed_at'] != null
            ? DateTime.tryParse(j['completed_at'] as String)
            : null,
        pickupLat: j['pickup_lat'] == null
            ? null
            : double.tryParse(j['pickup_lat'].toString()),
        pickupLng: j['pickup_lng'] == null
            ? null
            : double.tryParse(j['pickup_lng'].toString()),
        deliveryLat: j['delivery_lat'] == null
            ? null
            : double.tryParse(j['delivery_lat'].toString()),
        deliveryLng: j['delivery_lng'] == null
            ? null
            : double.tryParse(j['delivery_lng'].toString()),
      );

  /// Bản sao chỉ đổi trạng thái — giữ nguyên mọi field (đơn ghép, tên địa
  /// điểm, cargo, mưa...). Dùng cho cập nhật lạc quan.
  OrderModel withStatus(String newStatus) => OrderModel(
        id: id,
        code: code,
        serviceType: serviceType,
        status: newStatus,
        driverOrderRole: driverOrderRole,
        mainOrderId: mainOrderId,
        bundleWindowExpiresAt: bundleWindowExpiresAt,
        pickupName: pickupName,
        pickupPlaceName: pickupPlaceName,
        pickupAddress: pickupAddress,
        pickupPhone: pickupPhone,
        customerName: customerName,
        customerPhone: customerPhone,
        deliveryPlaceName: deliveryPlaceName,
        deliveryAddress: deliveryAddress,
        deliveryPhone: deliveryPhone,
        orderNote: orderNote,
        storeName: storeName,
        platform: platform,
        shopServiceType: shopServiceType,
        cargoType: cargoType,
        cargoNote: cargoNote,
        cargoWeight: cargoWeight,
        isBatch: isBatch,
        stopsCount: stopsCount,
        stops: stops,
        distance: distance,
        shippingFee: shippingFee,
        bonusFee: bonusFee,
        nightSurcharge: nightSurcharge,
        isRainMode: isRainMode,
        rainBonusAmount: rainBonusAmount,
        rainBonusEligible: rainBonusEligible,
        rainBonusConfirmedAmount: rainBonusConfirmedAmount,
        discountAmount: discountAmount,
        voucherCode: voucherCode,
        paymentMethod: paymentMethod,
        codAmount: codAmount,
        createdAt: createdAt,
        completedAt: completedAt,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        deliveryLat: deliveryLat,
        deliveryLng: deliveryLng,
      );

  /// Ngược lại với [OrderModel.fromJson] — `fromJson(toJson())` phải ra đúng
  /// đơn cũ, để đơn lưu trong máy không mất field khi mở lại app.
  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'service_type': serviceType,
        'status': status,
        'driver_order_role': driverOrderRole,
        'main_order_id': mainOrderId,
        'bundle_window_expires_at': bundleWindowExpiresAt?.toIso8601String(),
        'pickup_name': pickupName,
        'pickup_place_name': pickupPlaceName,
        'pickup_address': pickupAddress,
        'pickup_phone': pickupPhone,
        'receiver_name': customerName,
        'customer_phone': customerPhone,
        'delivery_place_name': deliveryPlaceName,
        'delivery_address': deliveryAddress,
        'delivery_phone': deliveryPhone,
        'order_note': orderNote,
        'store_name': storeName,
        'platform': platform,
        'shop_service_type': shopServiceType,
        'cargo_type': cargoType,
        'cargo_note': cargoNote,
        'cargo_weight': cargoWeight,
        'is_batch': isBatch,
        'stops_count': stopsCount,
        'stops': stops,
        'distance': distance,
        'shipping_fee': shippingFee,
        'bonus_fee': bonusFee,
        'night_surcharge': nightSurcharge,
        'is_rain_mode': isRainMode,
        'rain_bonus_eligible': rainBonusEligible,
        'rain_bonus_amount': rainBonusConfirmedAmount,
        'discount_amount': discountAmount,
        'voucher_code': voucherCode,
        'payment_method': paymentMethod,
        'cod_amount': codAmount,
        'created_at': createdAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'delivery_lat': deliveryLat,
        'delivery_lng': deliveryLng,
      };

  bool get isCod => paymentMethod == 'cod';
  bool get isActive => ['assigned', 'processing'].contains(status);
  bool get isShopOrder => platform == 'shop_app';
  bool get isCallCenter => platform == 'call_center';
  bool get isCustomerApp => platform == 'customer_app';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get hasDiscount => discountAmount > 0;
  int get shoppingStopCount {
    if (serviceType != 'shopping') return 0;
    final count = RegExp(
      r'={2,}\s*Điểm\s+\d+\s*:',
      caseSensitive: false,
      unicode: true,
    ).allMatches(orderNote ?? '').length;
    return count > 0 ? count : 1;
  }

  bool get hasMultipleShoppingStops => shoppingStopCount > 1;

  // shipping_fee đã gồm phụ phí đêm và đã trừ discount. Thưởng mưa
  // là khoản nền tảng trả riêng sau khi hoàn thành nên cộng thêm ở đây.
  int get driverEarning =>
      shippingFee +
      bonusFee +
      (rainBonusEligible ? rainBonusConfirmedAmount : 0);

  /// Phí vận chuyển hiển thị riêng với tài xế. Phụ phí đêm và các khoản
  /// thưởng do công ty trả được trình bày tách biệt để tránh thu nhầm khách.
  int get baseShippingFee {
    final fee = shippingFee - nightSurcharge;
    return fee < 0 ? 0 : fee;
  }

  /// Tiền tài xế cần chuẩn bị để trả shop. App khách hiện lưu câu chuẩn này
  /// trong ghi chú; `cod_amount` chỉ là trường tương thích dữ liệu cũ.
  int get shopPaymentAmount {
    // Đơn app shop: cod_amount là tiền THU HỘ người nhận, không phải tiền trả shop.
    if (serviceType == 'topup' || isShopOrder) return 0;
    if ((codAmount ?? 0) > 0) return codAmount!;
    final note = orderNote;
    if (note == null || note.isEmpty) return 0;
    final match = RegExp(
      r'tài\s*xế\s*chuẩn\s*bị\s*([\d.,]+)\s*(?:đ|₫)?\s*để\s*trả\s*shop',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(note);
    if (match == null) return 0;
    return int.tryParse(match.group(1)!.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  int get topupAmount => serviceType == 'topup' ? (codAmount ?? 0) : 0;

  String get statusLabel => switch (status) {
        'pending' => 'Chờ tài xế',
        'assigned' => 'Đã nhận',
        'processing' => switch (serviceType) {
            'shopping' => 'Đã mua xong',
            'topup' => 'Đã đến nơi nạp',
            'bike' => 'Đã đón khách',
            'motor' || 'car' => 'Đã đến xe',
            _ => 'Đã lấy hàng',
          },
        'completed' => 'Hoàn thành',
        'cancelled' => 'Đã hủy',
        _ => status,
      };

  // Tổng tiền cần thu khách: phí giao sau giảm giá (đã gồm phụ phí đêm)
  // cộng tiền hàng/COD. Bonus do hệ thống trả nên không tính vào đây.
  int get customerCollectionAmount => shippingFee + (codAmount ?? 0);

  String get nextAction => switch (status) {
        'assigned' => switch (serviceType) {
            'shopping' => 'Đã mua xong',
            'topup' => 'Đã đến nơi nạp',
            'bike' => 'Đã đón khách',
            'motor' || 'car' => 'Đã đến xe',
            _ => 'Đã lấy hàng',
          },
        // Đơn batch tự hoàn thành khi giao hết các điểm (xem _BatchStopsCard) —
        // không cho bấm "Hoàn thành" thẳng ở thanh dưới kẻo bỏ sót điểm chưa giao.
        'processing' => isBatch ? '' : 'Hoàn thành',
        _ => '',
      };

  // Ba mốc vận hành: assigned → processing → completed.
  String get nextStatus => switch (status) {
        'assigned' => 'processing',
        'processing' => 'completed',
        _ => '',
      };

  bool get isLastStep => status == 'processing';

  // Tên hiển thị dịch vụ — logic này bị lặp y hệt ở 5 chỗ trong 3 screen
  // (active_order/order_offer/history) trước khi gom về đây.
  String get displayTitle => isShopOrder
      ? switch (shopServiceType) {
          'shop_batch' => 'Đơn gộp',
          'shop_pickup' => 'Lấy hộ',
          _ => 'Giao đơn',
        }
      : Fmt.serviceLabel(serviceType);
}
