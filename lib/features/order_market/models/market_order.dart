class MarketOrder {
  final int id;
  final String code;
  final String serviceType;
  final String pickupAddress;
  final String deliveryAddress;
  final double pickupDistanceKm;
  final double? distance;
  final int shippingFee;
  final int bonusFee;
  final int nightSurcharge;
  final int codAmount;
  final bool isFreeship;
  final DateTime expiresAt;

  const MarketOrder({
    required this.id,
    required this.code,
    required this.serviceType,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.pickupDistanceKm,
    this.distance,
    required this.shippingFee,
    required this.bonusFee,
    required this.nightSurcharge,
    required this.codAmount,
    required this.isFreeship,
    required this.expiresAt,
  });

  int get estimatedIncome => shippingFee + bonusFee + nightSurcharge;

  factory MarketOrder.fromJson(Map<String, dynamic> j) => MarketOrder(
        id: (j['id'] as num).toInt(),
        code: j['code']?.toString() ?? '',
        serviceType: j['service_type']?.toString() ?? 'delivery',
        pickupAddress: j['pickup_address']?.toString() ?? '',
        deliveryAddress: j['delivery_address']?.toString() ?? '',
        pickupDistanceKm:
            double.tryParse(j['pickup_distance_km'].toString()) ?? 0,
        distance: j['distance'] == null
            ? null
            : double.tryParse(j['distance'].toString()),
        shippingFee: (j['shipping_fee'] as num?)?.toInt() ?? 0,
        bonusFee: (j['bonus_fee'] as num?)?.toInt() ?? 0,
        nightSurcharge: (j['night_surcharge'] as num?)?.toInt() ?? 0,
        codAmount: (j['cod_amount'] as num?)?.toInt() ?? 0,
        isFreeship: j['is_freeship'] == true || j['is_freeship'] == 1,
        expiresAt: DateTime.tryParse(j['expires_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}
