import 'package:flashship_driver/features/shifts/models/shift_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('đếm ngược Offline không phụ thuộc giờ server lệch với giờ máy', () {
    // Server ở "tương lai" 10 phút so với máy: trước đây máy trừ âm → đứng yên.
    final received = DateTime(2026, 11, 4, 9, 0, 0);
    final s = ShiftOfflineStatus.fromJson({
      'shift_name': 'Ca sáng',
      'limit_seconds': 600,
      'offline_seconds': 100,
      'measured_at': '2026-11-04T09:10:00',
      'shift_end_at': '2026-11-04T11:10:00',
    });
    final status = ShiftOfflineStatus(
      shiftName: s.shiftName,
      limitSeconds: s.limitSeconds,
      offlineSeconds: s.offlineSeconds,
      penalized: false,
      exempt: false,
      penaltyAmount: 0,
      measuredAt: s.measuredAt,
      shiftEndAt: s.shiftEndAt,
      receivedAt: received,
    );
    final later = received.add(const Duration(seconds: 60));
    expect(status.remainingSeconds(isOnline: false, now: later), 440);
    expect(status.remainingSeconds(isOnline: true, now: later), 500);
    expect(status.isActiveAt(received.add(const Duration(hours: 1))), isTrue);
    expect(status.isActiveAt(received.add(const Duration(hours: 3))), isFalse);
  });

  test('chỉ nhắc yêu cầu đổi ca bị từ chối trong 7 ngày', () {
    ShiftChangeRequestModel req(Duration ago) => ShiftChangeRequestModel.fromJson({
          'id': 1,
          'shift_ids': [1],
          'status': 'rejected',
          'processed_at': DateTime.now().subtract(ago).toIso8601String(),
          'created_at': DateTime.now().subtract(ago).toIso8601String(),
        });
    expect(req(const Duration(days: 2)).isRecentlyRejected, isTrue);
    expect(req(const Duration(days: 30)).isRecentlyRejected, isFalse);
  });
}
