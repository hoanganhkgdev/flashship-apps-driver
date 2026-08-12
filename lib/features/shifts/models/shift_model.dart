class ShiftModel {
  final int id;
  final String code;
  final String name;
  final String startTime; // "06:00:00"
  final String endTime;   // "12:00:00" (có thể "00:00:00" nếu ca qua nửa đêm)

  const ShiftModel({
    required this.id,
    required this.code,
    required this.name,
    required this.startTime,
    required this.endTime,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json) => ShiftModel(
        id:        (json['id'] as num).toInt(),
        code:      json['code']       as String? ?? '',
        name:      json['name']       as String? ?? '',
        startTime: json['start_time'] as String? ?? '',
        endTime:   json['end_time']   as String? ?? '',
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
        id:       (json['id'] as num).toInt(),
        shiftIds: (json['shift_ids'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            [],
        status:      json['status']     as String? ?? 'pending',
        adminNote:   json['admin_note'] as String?,
        processedAt: json['processed_at'] != null
            ? DateTime.tryParse(json['processed_at'] as String)
            : null,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );

  bool get isPending  => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}
