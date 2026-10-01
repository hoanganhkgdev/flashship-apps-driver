class ReferredShop {
  final String shopName;
  final String status; // pending | rewarded | rejected
  final int? rewardAmount;
  final DateTime? registeredAt;
  final DateTime? rewardedAt;

  const ReferredShop({
    required this.shopName,
    required this.status,
    this.rewardAmount,
    this.registeredAt,
    this.rewardedAt,
  });

  factory ReferredShop.fromJson(Map<String, dynamic> j) => ReferredShop(
        shopName: (j['shop_name'] as String?)?.trim().isNotEmpty == true
            ? j['shop_name'] as String
            : 'Cửa hàng',
        status: j['status'] as String? ?? 'pending',
        rewardAmount: (j['reward_amount'] as num?)?.toInt(),
        registeredAt: DateTime.tryParse(j['registered_at'] as String? ?? ''),
        rewardedAt: DateTime.tryParse(j['rewarded_at'] as String? ?? ''),
      );
}

class ReferralInfo {
  final String code;
  final int rewardAmount;
  final int requiredOrders;
  final int totalReferred;
  final int totalRewarded;
  final List<ReferredShop> shops;

  const ReferralInfo({
    required this.code,
    required this.rewardAmount,
    required this.requiredOrders,
    required this.totalReferred,
    required this.totalRewarded,
    required this.shops,
  });

  factory ReferralInfo.fromJson(Map<String, dynamic> j) => ReferralInfo(
        code: j['code'] as String? ?? '',
        rewardAmount: (j['reward_amount'] as num?)?.toInt() ?? 0,
        requiredOrders: (j['required_orders'] as num?)?.toInt() ?? 1,
        totalReferred: (j['total_referred'] as num?)?.toInt() ?? 0,
        totalRewarded: (j['total_rewarded'] as num?)?.toInt() ?? 0,
        shops: ((j['shops'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ReferredShop.fromJson)
            .toList(),
      );
}
