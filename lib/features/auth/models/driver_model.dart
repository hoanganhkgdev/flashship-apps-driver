class DriverModel {
  final int id;
  final String name;
  final String phone;
  final String? email;
  final bool isOnline;
  final DateTime? onlineSince;
  final int dailyOnlineSeconds;
  final String? dailyOnlineDate; // 'YYYY-MM-DD' — ngày của dailyOnlineSeconds
  final double? latitude;
  final double? longitude;
  final String? planType;
  final int balance;
  final String? profilePhotoUrl;
  final int status; // 0=pending, 1=active, 2=banned

  const DriverModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.isOnline,
    this.onlineSince,
    this.dailyOnlineSeconds = 0,
    this.dailyOnlineDate,
    this.latitude,
    this.longitude,
    this.planType,
    this.balance = 0,
    this.profilePhotoUrl,
    this.status = 0,
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
    dailyOnlineDate:     j['daily_online_date'] as String?,
    latitude:            j['latitude'] == null ? null : double.tryParse(j['latitude'].toString()),
    longitude:           j['longitude'] == null ? null : double.tryParse(j['longitude'].toString()),
    planType:            j['plan_type'] as String?,
    balance:             (j['balance'] as num?)?.toInt() ?? 0,
    profilePhotoUrl:     j['profile_photo_url'] as String?,
    // Default 1 (approved) khi field vắng mặt — chỉ xảy ra với stored data cũ
    // trước khi feature pending được thêm vào. Data mới từ backend luôn có field này.
    status:              (j['status'] as num?)?.toInt() ?? 1,
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
    String? dailyOnlineDate,
    int? balance,
    int? status,
  }) => DriverModel(
    id: id, name: name, phone: phone, email: email,
    isOnline:           isOnline           ?? this.isOnline,
    onlineSince:        clearOnlineSince ? null : (onlineSince ?? this.onlineSince),
    dailyOnlineSeconds: dailyOnlineSeconds ?? this.dailyOnlineSeconds,
    dailyOnlineDate:    dailyOnlineDate    ?? this.dailyOnlineDate,
    latitude:           latitude, longitude: longitude,
    planType:           planType,
    balance:            balance ?? this.balance,
    profilePhotoUrl:    profilePhotoUrl,
    status:             status ?? this.status,
  );
}
