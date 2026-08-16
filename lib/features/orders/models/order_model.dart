import '../../../core/utils/formatters.dart';

class OrderModel {
  final int id;
  final String code;
  final String serviceType;
  final String status;
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
  final String  platform;
  final String? shopServiceType;
  final String  cargoType;
  final String? cargoNote;
  final double? cargoWeight;
  final bool isBatch;
  final int stopsCount;
  final List<Map<String, dynamic>> stops;
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
    this.isBatch    = false,
    this.stopsCount = 0,
    this.stops      = const [],
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
    id:             ((j['id'] ?? j['order_id']) as num).toInt(),
    code:           j['code'] as String? ?? j['order_code'] as String? ?? '',
    serviceType:    j['service_type'] as String? ?? 'delivery',
    status:         j['status'] as String? ?? 'pending',
    pickupName:     (j['pickup_name'] as String?)?.isNotEmpty == true
                    ? j['pickup_name'] as String
                    : (j['sender_name'] as String?)?.isNotEmpty == true
                        ? j['sender_name'] as String
                        : null,
    pickupPlaceName: j['pickup_place_name'] as String?,
    pickupAddress:   j['pickup_address'] as String? ?? '',
    pickupPhone:     j['pickup_phone'] as String?,
    customerName:   (j['receiver_name'] as String?)?.isNotEmpty == true
                    ? j['receiver_name'] as String
                    : (j['customer'] as Map<String, dynamic>?)?['name'] as String?,
    customerPhone:  (j['customer'] as Map<String, dynamic>?)?['phone'] as String?
                    ?? j['customer_phone'] as String?,
    deliveryPlaceName: j['delivery_place_name'] as String?,
    deliveryAddress:   j['delivery_address'] as String? ?? '',
    deliveryPhone:     j['delivery_phone'] as String? ?? '',
    orderNote:       j['order_note']  as String?,
    storeName:       j['store_name']  as String?,
    platform:        j['platform']          as String? ?? 'customer_app',
    shopServiceType: j['shop_service_type'] as String?,
    cargoType:       j['cargo_type']        as String? ?? 'food',
    cargoNote:       j['cargo_note']  as String?,
    cargoWeight:     (j['cargo_weight'] as num?)?.toDouble(),
    isBatch:         j['is_batch']     as bool? ?? false,
    stopsCount:      (j['stops_count'] as num?)?.toInt() ?? 0,
    stops:           (j['stops']       as List? ?? [])
        .cast<Map<String, dynamic>>(),
    shippingFee:     (j['shipping_fee'] as num?)?.toInt() ?? 0,
    bonusFee:        (j['bonus_fee'] as num?)?.toInt() ?? 0,
    nightSurcharge:  (j['night_surcharge'] as num?)?.toInt() ?? 0,
    isRainMode:      j['is_rain_mode'] as bool? ?? false,
    rainBonusAmount: (j['rain_bonus_amount'] as num?)?.toInt() ?? 0,
    rainBonusEligible:        j['rain_bonus_eligible'] as bool? ?? false,
    rainBonusConfirmedAmount: (j['rain_bonus_amount'] as num?)?.toInt() ?? 0,
    discountAmount:  (j['discount_amount'] as num?)?.toInt() ?? 0,
    voucherCode:     j['voucher_code'] as String?,
    paymentMethod:   j['payment_method'] as String? ?? 'prepaid',
    codAmount:       (j['cod_amount'] as num?)?.toInt(),
    createdAt: j['created_at'] != null
        ? DateTime.tryParse(j['created_at'] as String) ?? DateTime.now()
        : DateTime.now(),
    completedAt: j['completed_at'] != null
        ? DateTime.tryParse(j['completed_at'] as String)
        : null,
    pickupLat:    j['pickup_lat'] == null ? null : double.tryParse(j['pickup_lat'].toString()),
    pickupLng:    j['pickup_lng'] == null ? null : double.tryParse(j['pickup_lng'].toString()),
    deliveryLat:  j['delivery_lat'] == null ? null : double.tryParse(j['delivery_lat'].toString()),
    deliveryLng:  j['delivery_lng'] == null ? null : double.tryParse(j['delivery_lng'].toString()),
  );

  bool get isCod       => paymentMethod == 'cod';
  bool get isActive    => ['assigned', 'processing'].contains(status);
  bool get isShopOrder  => platform == 'shop_app';
  bool get isCallCenter => platform == 'call_center';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get hasDiscount => discountAmount > 0;

  // shipping_fee backend đã trừ discount rồi, nên earning = fee net + bonus
  int get driverEarning => shippingFee + bonusFee;

  String get nextAction => switch (status) {
    'assigned'   => switch (serviceType) {
      'shopping'       => 'Đã mua xong',
      'topup'          => 'Đã đến nơi nạp',
      'bike'           => 'Đã đón khách',
      'motor' || 'car' => 'Đã đến xe',
      _                => 'Đã lấy hàng',
    },
    // Đơn batch tự hoàn thành khi giao hết các điểm (xem _BatchStopsCard) —
    // không cho bấm "Hoàn thành" thẳng ở thanh dưới kẻo bỏ sót điểm chưa giao.
    'processing' => isBatch ? '' : 'Hoàn thành',
    _            => '',
  };

  // Bỏ bước on_the_way: assigned → processing → completed
  String get nextStatus => switch (status) {
    'assigned'   => 'processing',
    'processing' => 'completed',
    _            => '',
  };

  bool get isLastStep => status == 'processing';

  // Tên hiển thị dịch vụ — logic này bị lặp y hệt ở 5 chỗ trong 3 screen
  // (active_order/order_offer/history) trước khi gom về đây.
  String get displayTitle => isShopOrder
      ? switch (shopServiceType) {
          'shop_batch'  => 'Đơn gộp',
          'shop_pickup' => 'Lấy hộ',
          _             => 'Giao đơn',
        }
      : Fmt.serviceLabel(serviceType);
}
