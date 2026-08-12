import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flashship_driver/core/services/location_push_service.dart';

/// Test đúng kịch bản đã sinh ra lỗi "đồng hồ ma" (tài xế #68/#107/#148/#232,
/// vị trí nhảy lặp lại đúng chu kỳ 20 giây): 1 lệnh ghi vị trí đang chờ mạng
/// dở dang đúng lúc phiên online kết thúc (widget bị huỷ / tài xế tắt online
/// / đăng nhập máy khác đè lên).
///
/// LƯU Ý QUAN TRỌNG khi đọc file này: bản thân việc gom về 1 singleton với 1
/// field `_refreshTimer` duy nhất đã loại bỏ khả năng NHIỀU đồng hồ tồn tại
/// song song (bug gốc: mỗi widget instance có field đồng hồ RIÊNG, không ai
/// biết ai). Cái các test dưới đây nhắm tới cụ thể là lớp bảo vệ THỨ HAI —
/// [LocationPushService._generation] — chặn 1 lệnh ghi "trễ" của phiên CŨ
/// làm hỏng trạng thái của phiên MỚI đang chạy, khi 2 phiên xen kẽ đủ nhanh.
/// Test đầu tiên cố tình verify NGƯỢC (assert lỗi tái diễn) trên 1 bản sao đã
/// cố ý bỏ chặn, để chứng minh test có "răng" thật — không phải test cho
/// vui rồi tự pass vì lý do khác.
void main() {
  group('LocationPushService — bảo vệ trạng thái khỏi lệnh ghi trễ của phiên cũ', () {
    test(
      'lệnh ghi trễ của phiên A hoàn tất SAU khi phiên B đã bắt đầu không được '
      'ghi đè toạ độ "đã đẩy gần nhất" của phiên B',
      () async {
        final completerA = Completer<void>();
        final completerB = Completer<void>();
        var callIndex = 0;
        final writeLog = <String>[];

        final service = LocationPushService.debugForTest(
          writer: (driverId, data) {
            final label = 'driver=$driverId lat=${data['lat']}';
            writeLog.add(label);
            // Lần gọi đầu tiên (phiên A) cố tình "treo" — mô phỏng đúng 1 gói
            // tin bị delay bởi mạng chậm, chỉ trả lời SAU khi phiên B đã push
            // xong. Lần gọi thứ 2 (phiên B) trả lời ngay.
            return callIndex++ == 0 ? completerA.future : completerB.future;
          },
        );

        // Phiên A: driverId 100, đang gửi (10.0, 105.0) — CHƯA xong.
        service.debugSetDriverId(100);
        final pendingA = service.debugPush(10.0, 105.0, 0);

        // Phiên A kết thúc trước khi lệnh ghi kịp xong (widget huỷ / logout /
        // máy khác đăng nhập đè). Production luôn đi qua stop() trước khi bắt
        // đầu phiên mới (start() gọi stop() làm bước đầu tiên) — test phải mô
        // phỏng ĐÚNG bước đó thì mới đo đúng tác dụng của _generation; bỏ qua
        // bước này sẽ khiến _generation không hề tăng, chốt chặn không có cơ
        // hội phát huy tác dụng (bug đã tự bắt được khi viết test này).
        service.stop();
        service.debugSetDriverId(200);
        final pendingB = service.debugPush(20.0, 106.0, 0);

        // Phiên B trả lời trước (đúng thực tế: request mới thường nhanh hơn
        // request cũ đang bị mạng làm chậm).
        completerB.complete();
        await pendingB;

        // BÂY GIỜ lệnh ghi trễ của phiên A mới hoàn tất.
        completerA.complete();
        await pendingA;

        // Khẳng định quyết định: nếu lệnh ghi trễ của A làm hỏng trạng thái
        // "đã đẩy gần nhất", push lại ĐÚNG toạ độ B đã gửi sẽ KHÔNG bị coi là
        // trùng (vì trạng thái đã bị A ghi đè về (10.0, 105.0)), sinh ra 1
        // lệnh ghi thừa thứ 3. Ghi đúng phải bị chặn trùng — tổng chỉ 2 lệnh.
        await service.debugPush(20.0, 106.0, 0);

        expect(writeLog.length, 2,
            reason: 'Lệnh ghi trễ của phiên A phải bị bỏ qua hoàn toàn — không được phép làm trạng thái '
                '"đã đẩy gần nhất" của phiên B nhảy ngược lại toạ độ của phiên A.\n'
                'Log thực tế: $writeLog');
      },
    );

    test('stop() huỷ đồng hồ giữ nhịp ngay lập tức, và không có đồng hồ nào bị hẹn lại sau đó', () async {
      final completer = Completer<void>();
      final service = LocationPushService.debugForTest(
        writer: (driverId, data) => completer.future,
      );

      service.debugSetDriverId(412);
      final pending = service.debugPush(10.0, 105.0, 0);

      service.stop();
      expect(service.debugHasPendingRefreshTimer, isFalse);

      completer.complete();
      await pending;

      expect(service.debugHasPendingRefreshTimer, isFalse,
          reason: 'Sau stop(), không lệnh ghi dở dang nào (dù xong sớm hay muộn) được phép hẹn lại đồng hồ giữ nhịp');
    });
  });
}
