class MarketOrder {
  final int id;
  final String code;
  final String serviceType;
  final String platform;
  final String pickupAddress;
  final String deliveryAddress;
  final String? orderNote;
  final double? pickupLat;
  final double? pickupLng;

  /// null khi chưa biết vị trí của tài xế để tính khoảng cách tới điểm lấy.
  final double? pickupDistanceKm;
  final double? distance;
  final int shippingFee;
  final int bonusFee;
  final int nightSurcharge;
  final bool isRainMode;
  final int rainBonusAmount;
  final int codAmount;
  final bool isFreeship;
  final String? voucherCode;
  final int discountAmount;

  // Chỉ có ở đơn app shop.
  final String? storeName;
  final String? pickupPlaceName;
  final String? shopServiceType;
  final String cargoType;
  final String? cargoNote;
  final double? cargoWeight;
  final int stopsCount;

  /// Thời điểm đơn lên danh sách (đơn không hết hạn, nằm đó đến khi có người nhận).
  final DateTime openedAt;

  const MarketOrder({
    required this.id,
    required this.code,
    required this.serviceType,
    this.platform = 'customer_app',
    required this.pickupAddress,
    required this.deliveryAddress,
    this.orderNote,
    this.pickupLat,
    this.pickupLng,
    this.pickupDistanceKm,
    this.distance,
    required this.shippingFee,
    required this.bonusFee,
    required this.nightSurcharge,
    required this.isRainMode,
    required this.rainBonusAmount,
    required this.codAmount,
    required this.isFreeship,
    this.voucherCode,
    this.discountAmount = 0,
    this.storeName,
    this.pickupPlaceName,
    this.shopServiceType,
    this.cargoType = 'food',
    this.cargoNote,
    this.cargoWeight,
    this.stopsCount = 0,
    required this.openedAt,
  });

  MarketOrder withDistance(double? km) => MarketOrder(
        id: id,
        code: code,
        serviceType: serviceType,
        platform: platform,
        pickupAddress: pickupAddress,
        deliveryAddress: deliveryAddress,
        orderNote: orderNote,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        pickupDistanceKm: km,
        distance: distance,
        shippingFee: shippingFee,
        bonusFee: bonusFee,
        nightSurcharge: nightSurcharge,
        isRainMode: isRainMode,
        rainBonusAmount: rainBonusAmount,
        codAmount: codAmount,
        isFreeship: isFreeship,
        voucherCode: voucherCode,
        discountAmount: discountAmount,
        storeName: storeName,
        pickupPlaceName: pickupPlaceName,
        shopServiceType: shopServiceType,
        cargoType: cargoType,
        cargoNote: cargoNote,
        cargoWeight: cargoWeight,
        stopsCount: stopsCount,
        openedAt: openedAt,
      );

  // shippingFee đã gồm phụ phí đêm và đã trừ voucher; cộng các khoản công
  // ty trả riêng (thưởng, bù voucher, mưa) — khớp OrderMoney::driverEarnings
  // ở backend, tức số tiền thật sự vào ví khi hoàn thành.
  int get estimatedIncome =>
      shippingFee +
      bonusFee +
      discountAmount +
      (isRainMode ? rainBonusAmount : 0);
  int get baseShippingFee {
    final fee = shippingFee - nightSurcharge;
    return fee < 0 ? 0 : fee;
  }

  /// Khoản tài xế cần chuẩn bị để trả shop khi lấy hàng. App khách hiện ghi
  /// khoản này vào đầu ghi chú; `cod_amount` chỉ được giữ làm dữ liệu tương
  /// thích với các đơn cũ, không mang nghĩa thu hộ trong giao diện tài xế.
  int get shopPaymentAmount {
    // Đơn app shop: cod_amount là tiền THU HỘ người nhận, xem collectAmount.
    if (serviceType == 'topup' || isShopOrder) return 0;
    if (codAmount > 0) return codAmount;
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

  int get topupAmount => serviceType == 'topup' ? codAmount : 0;

  bool get hasNote => orderNote?.trim().isNotEmpty == true;
  bool get hasVoucher => voucherCode?.trim().isNotEmpty == true;
  bool get isCallCenter => platform == 'call_center';
  bool get isCustomerApp => platform == 'customer_app';
  bool get isShopOrder => platform == 'shop_app';
  bool get isShopBatch => shopServiceType == 'shop_batch';

  /// Tiền thu hộ người nhận của đơn shop (tiền hàng, trả lại shop sau).
  int get collectAmount => isShopOrder ? codAmount : 0;

  /// Tổng tài xế thu người nhận đơn shop: phí ship + thu hộ — cùng cách tính
  /// với "Cần thu khách" (OrderModel.customerCollectionAmount) sau khi nhận đơn.
  int get receiverPayAmount => shippingFee + collectAmount;

  String get shopName => storeName?.trim().isNotEmpty == true
      ? storeName!.trim()
      : pickupPlaceName?.trim().isNotEmpty == true
          ? pickupPlaceName!.trim()
          : 'Cửa hàng';

  /// Cùng nhãn với OrderModel.displayTitle.
  String get shopTitle => switch (shopServiceType) {
        'shop_batch' => 'Đơn gộp',
        'shop_pickup' => 'Lấy hộ',
        _ => 'Giao đơn',
      };

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

  factory MarketOrder.fromJson(Map<String, dynamic> j) => MarketOrder(
        id: (j['id'] as num).toInt(),
        code: j['code']?.toString() ?? '',
        serviceType: j['service_type']?.toString() ?? 'delivery',
        platform: j['platform']?.toString() ?? 'customer_app',
        pickupAddress: j['pickup_address']?.toString() ?? '',
        deliveryAddress: j['delivery_address']?.toString() ?? '',
        orderNote: j['order_note']?.toString().trim(),
        pickupLat: double.tryParse(j['pickup_lat']?.toString() ?? ''),
        pickupLng: double.tryParse(j['pickup_lng']?.toString() ?? ''),
        pickupDistanceKm: j['pickup_distance_km'] == null
            ? null
            : double.tryParse(j['pickup_distance_km'].toString()),
        distance: j['distance'] == null
            ? null
            : double.tryParse(j['distance'].toString()),
        shippingFee: (j['shipping_fee'] as num?)?.toInt() ?? 0,
        bonusFee: (j['bonus_fee'] as num?)?.toInt() ?? 0,
        nightSurcharge: (j['night_surcharge'] as num?)?.toInt() ?? 0,
        isRainMode: j['is_rain_mode'] == true || j['is_rain_mode'] == 1,
        rainBonusAmount: (j['rain_bonus_amount'] as num?)?.toInt() ?? 0,
        codAmount: (j['cod_amount'] as num?)?.toInt() ?? 0,
        isFreeship: j['is_freeship'] == true || j['is_freeship'] == 1,
        voucherCode: j['voucher_code']?.toString().trim(),
        discountAmount: (j['discount_amount'] as num?)?.toInt() ?? 0,
        storeName: j['store_name']?.toString().trim(),
        pickupPlaceName: j['pickup_place_name']?.toString().trim(),
        shopServiceType: j['shop_service_type']?.toString(),
        cargoType: j['cargo_type']?.toString() ?? 'food',
        cargoNote: j['cargo_note']?.toString().trim(),
        cargoWeight: j['cargo_weight'] == null
            ? null
            : double.tryParse(j['cargo_weight'].toString()),
        stopsCount: (j['stops_count'] as num?)?.toInt() ?? 0,
        openedAt:
            DateTime.tryParse(j['opened_at']?.toString() ?? '')?.toLocal() ??
                DateTime.now(),
      );
}
