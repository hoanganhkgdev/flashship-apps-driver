class DriverModel {
  final int id;
  final String name;
  final String phone;
  final String? email;
  final bool isOnline;
  final DateTime? onlineSince;
  final double? latitude;
  final double? longitude;
  final String? planType;
  final int balance;
  final String? profilePhotoUrl;
  final int status; // 0=pending, 1=active, 2=banned
  final bool deleteRequested;
  final String?
      cccdStatus; // null=chưa biết/chưa nộp, pending/approved/rejected

  const DriverModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.isOnline,
    this.onlineSince,
    this.latitude,
    this.longitude,
    this.planType,
    this.balance = 0,
    this.profilePhotoUrl,
    this.status = 0,
    this.deleteRequested = false,
    this.cccdStatus,
  });

  factory DriverModel.fromJson(Map<String, dynamic> j) => DriverModel(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        email: j['email'] as String?,
        isOnline: j['is_online'] == true || j['is_online'] == 1,
        onlineSince: j['online_since'] != null
            ? DateTime.tryParse(j['online_since'] as String)
            : null,
        latitude: j['latitude'] == null
            ? null
            : double.tryParse(j['latitude'].toString()),
        longitude: j['longitude'] == null
            ? null
            : double.tryParse(j['longitude'].toString()),
        planType: j['plan_type'] as String?,
        balance: (j['balance'] as num?)?.toInt() ?? 0,
        profilePhotoUrl: j['profile_photo_url'] as String?,
        // Default 1 (approved) khi field vắng mặt — chỉ xảy ra với stored data cũ
        // trước khi feature pending được thêm vào. Data mới từ backend luôn có field này.
        status: (j['status'] as num?)?.toInt() ?? 1,
        deleteRequested: j['delete_requested_at'] != null,
        // Chỉ có trong response /driver/profile — response /auth/login và
        // /auth/verify-otp-register KHÔNG có field này (null ở đây không có
        // nghĩa là "chưa duyệt", chỉ là "chưa biết", nơi dùng field này phải tự
        // refreshUser() để lấy dữ liệu mới trước khi kết luận).
        cccdStatus: j['cccd_image_status'] as String?,
      );

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'D';
  }

  DriverModel copyWith({
    bool? isOnline,
    DateTime? onlineSince,
    bool clearOnlineSince = false,
    int? balance,
    int? status,
    bool? deleteRequested,
    String? cccdStatus,
  }) =>
      DriverModel(
        id: id,
        name: name,
        phone: phone,
        email: email,
        isOnline: isOnline ?? this.isOnline,
        onlineSince:
            clearOnlineSince ? null : (onlineSince ?? this.onlineSince),
        latitude: latitude,
        longitude: longitude,
        planType: planType,
        balance: balance ?? this.balance,
        profilePhotoUrl: profilePhotoUrl,
        status: status ?? this.status,
        deleteRequested: deleteRequested ?? this.deleteRequested,
        cccdStatus: cccdStatus ?? this.cccdStatus,
      );
}
