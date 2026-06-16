class DriverModel {
  final int id;
  final String name;
  final String phone;
  final String? email;
  final bool isOnline;
  final DateTime? onlineSince;
  final int dailyOnlineSeconds; // giây online đã tích lũy hôm nay (không kể session hiện tại)
  final double? latitude;
  final double? longitude;
  final String? planType;
  final int balance;
  final String? profilePhotoUrl;

  const DriverModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.isOnline,
    this.onlineSince,
    this.dailyOnlineSeconds = 0,
    this.latitude,
    this.longitude,
    this.planType,
    this.balance = 0,
    this.profilePhotoUrl,
  });

  factory DriverModel.fromJson(Map<String, dynamic> j) => DriverModel(
    id:                  (j['id'] as num).toInt(),
    name:                j['name'] as String? ?? '',
    phone:               j['phone'] as String? ?? '',
    email:               j['email'] as String?,
    isOnline:            j['is_online'] == true || j['is_online'] == 1,
    onlineSince:         j['online_since'] != null
        ? DateTime.tryParse(j['online_since'] as String)
        : null,
    dailyOnlineSeconds:  (j['daily_online_seconds'] as num?)?.toInt() ?? 0,
    latitude:            j['latitude'] == null ? null : double.tryParse(j['latitude'].toString()),
    longitude:           j['longitude'] == null ? null : double.tryParse(j['longitude'].toString()),
    planType:            j['plan_type'] as String?,
    balance:             (j['balance'] as num?)?.toInt() ?? 0,
    profilePhotoUrl:     j['profile_photo_url'] as String?,
  );

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'D';
  }

  DriverModel copyWith({
    bool? isOnline,
    DateTime? onlineSince,
    bool clearOnlineSince = false,
    int? dailyOnlineSeconds,
    int? balance,
  }) => DriverModel(
    id: id, name: name, phone: phone, email: email,
    isOnline:           isOnline           ?? this.isOnline,
    onlineSince:        clearOnlineSince ? null : (onlineSince ?? this.onlineSince),
    dailyOnlineSeconds: dailyOnlineSeconds ?? this.dailyOnlineSeconds,
    latitude:           latitude, longitude: longitude,
    planType:           planType,
    balance:            balance ?? this.balance,
    profilePhotoUrl:    profilePhotoUrl,
  );
}
