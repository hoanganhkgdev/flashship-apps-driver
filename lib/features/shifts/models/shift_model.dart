class ShiftModel {
  final int id;
  final String code;
  final String name;
  final String startTime; // "06:00:00"
  final String endTime; // "12:00:00" (có thể "00:00:00" nếu ca qua nửa đêm)

  const ShiftModel({
    required this.id,
    required this.code,
    required this.name,
    required this.startTime,
    required this.endTime,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json) => ShiftModel(
        id: (json['id'] as num).toInt(),
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        startTime: json['start_time'] as String? ?? '',
        endTime: json['end_time'] as String? ?? '',
      );

  static String _hm(String t) => t.length >= 5 ? t.substring(0, 5) : t;
  String get timeRange => '${_hm(startTime)} - ${_hm(endTime)}';
}

class ShiftChangeRequestModel {
  final int id;
  final List<int> shiftIds;
  final String status; // pending | approved | rejected
  final String? adminNote;
  final DateTime? processedAt;
  final DateTime createdAt;

  const ShiftChangeRequestModel({
    required this.id,
    required this.shiftIds,
    required this.status,
    this.adminNote,
    this.processedAt,
    required this.createdAt,
  });

  factory ShiftChangeRequestModel.fromJson(Map<String, dynamic> json) =>
      ShiftChangeRequestModel(
        id: (json['id'] as num).toInt(),
        shiftIds: (json['shift_ids'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            [],
        status: json['status'] as String? ?? 'pending',
        adminNote: json['admin_note'] as String?,
        processedAt: json['processed_at'] != null
            ? DateTime.tryParse(json['processed_at'] as String)
            : null,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}

/// Trạng thái Offline trong ca đang diễn ra (mỗi ca được Offline tối đa
/// [limitSeconds], vượt quá bị phạt [penaltyAmount]).
class ShiftOfflineStatus {
  final String shiftName;
  final int limitSeconds;
  final int offlineSeconds;
  final bool penalized;
  final bool exempt;
  final int penaltyAmount;
  final DateTime measuredAt;
  final DateTime shiftEndAt;

  const ShiftOfflineStatus({
    required this.shiftName,
    required this.limitSeconds,
    required this.offlineSeconds,
    required this.penalized,
    required this.exempt,
    required this.penaltyAmount,
    required this.measuredAt,
    required this.shiftEndAt,
  });

  factory ShiftOfflineStatus.fromJson(Map<String, dynamic> j) =>
      ShiftOfflineStatus(
        shiftName: j['shift_name']?.toString() ?? '',
        limitSeconds: (j['limit_seconds'] as num?)?.toInt() ?? 0,
        offlineSeconds: (j['offline_seconds'] as num?)?.toInt() ?? 0,
        penalized: j['penalized'] == true,
        exempt: j['exempt'] == true,
        penaltyAmount: (j['penalty_amount'] as num?)?.toInt() ?? 0,
        measuredAt: DateTime.tryParse(j['measured_at']?.toString() ?? '') ??
            DateTime.now(),
        shiftEndAt: DateTime.tryParse(j['shift_end_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  /// Số giây Offline còn được phép tại thời điểm [now]. Lúc đang Offline thì
  /// đếm ngược theo đồng hồ máy kể từ lúc server đo; lúc Online giữ nguyên.
  int remainingSeconds({required bool isOnline, DateTime? now}) {
    final t = now ?? DateTime.now();
    final extra =
        isOnline ? 0 : t.difference(measuredAt).inSeconds.clamp(0, 86400);
    final left = limitSeconds - (offlineSeconds + extra);
    return left < 0 ? 0 : left;
  }

  bool isActiveAt(DateTime now) => now.isBefore(shiftEndAt);
}
