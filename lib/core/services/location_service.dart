import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// [accuracy] tính bằng mét — service này KHÔNG tự lọc theo độ chính xác nữa,
/// mà giao nguyên cho bên nhận quyết định. Trước đây lọc ngay tại đây (bỏ im
/// lặng mọi fix >50m) khiến tài xế ở nơi sóng GPS kém (hầm xe, nhà cao tầng)
/// có thể KHÔNG gửi được vị trí nào suốt cả phiên mà không ai biết — bên nhận
/// cần nhìn thấy cả fix kém để còn có phương án dự phòng.
typedef LocationCallback = void Function(double lat, double lng, double bearing, double accuracy);

class LocationService {
  static final LocationService instance = LocationService._();
  LocationService._();

  StreamSubscription<Position>? _sub;
  LocationCallback? _onLocation;
  int _errorCount = 0;

  /// false sau stop() — dùng để chặn các nguồn đẩy vị trí KHÁC (vd timer tự
  /// lên lịch lại khi đứng yên) tiếp tục hoạt động dù stream GPS đã dừng.
  /// Quan trọng khi stop() được gọi từ 1 State khác không có quyền huỷ trực
  /// tiếp timer đó (vd SessionGuard force-logout gọi từ widget cha).
  bool get isRunning => _sub != null;

  /// Xếp hàng mọi lượt start()/restart() chạy TUẦN TỰ — 2 lượt gọi chồng lấn
  /// (vd app resume dồn dập trong thời gian ngắn) trước đây có thể cùng lúc
  /// thấy "chưa có gì để huỷ" (vì bên kia còn đang chờ xin quyền GPS, chưa
  /// kịp gán _sub) rồi cả 2 cùng tự tạo 1 luồng GPS riêng — luồng bị "bỏ
  /// quên" vẫn sống âm thầm bên cạnh luồng mới, khiến 1 máy tự gửi 2 toạ độ
  /// khác nhau xen kẽ dù chỉ 1 thiết bị, 1 phiên đăng nhập (xem điều tra tài
  /// xế #51/#496). Mọi thao tác tạo/huỷ stream đều đi qua đúng 1 chuỗi này
  /// để tại một thời điểm chỉ có tối đa 1 luồng đang được xử lý.
  Future<void> _chain = Future.value();

  Future<void> _runExclusive(Future<void> Function() action) {
    final result = _chain.then((_) => action());
    _chain = result.catchError((_) {});
    return result;
  }

  Future<void> start(LocationCallback onLocation) {
    _onLocation = onLocation;
    return _runExclusive(() async {
      if (_sub != null) return;
      _errorCount = 0;
      await _listen();
    });
  }

  /// Dùng khi app resume từ background — đảm bảo stream vẫn sống.
  Future<void> restart() {
    return _runExclusive(() async {
      // Kiểm tra _onLocation NGAY TRONG hàng đợi (không phải lúc gọi hàm) —
      // nếu stop() chạy xen giữa lúc restart() được xếp hàng và lúc tới lượt
      // chạy thật, phải thấy đúng trạng thái mới nhất, không "hồi sinh" lại
      // stream sau khi đã bị dừng.
      if (_onLocation == null) return;
      _errorCount = 0;
      await _listen();
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _onLocation = null;
    _errorCount = 0;
  }

  Future<void> _listen() async {
    // Tự huỷ stream cũ (nếu có) TRƯỚC khi tạo stream mới — không phụ thuộc
    // caller đã tự dọn hay chưa. Quan trọng cho nhánh retry lỗi mạng bên
    // dưới, vốn gọi thẳng _listen() qua _runExclusive chứ không qua start()/
    // restart(): nếu thiếu bước này, 1 restart() khác chạy trước trong lúc
    // đang chờ retry có thể để lại 2 stream sống song song — đúng kiểu bug
    // đã gặp (1 máy tự gửi 2 toạ độ khác nhau xen kẽ).
    _sub?.cancel();
    _sub = null;

    if (_onLocation == null) return;
    if (!await _ensurePermission()) return;

    final settings = _buildSettings();

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        _errorCount = 0;
        final bearing = pos.heading < 0 ? 0.0 : pos.heading;
        _onLocation?.call(pos.latitude, pos.longitude, bearing, pos.accuracy);
      },
      onError: (e) async {
        debugPrint('[LocationService] Stream error: $e');
        _sub?.cancel();
        _sub = null;
        // Thử lại KHÔNG giới hạn số lần, chỉ chặn trần độ trễ ở 30s. Trước đây
        // dừng hẳn sau 5 lần lỗi liên tiếp: tài xế vẫn hiển thị "đang online"
        // nhưng vị trí đứng im vĩnh viễn, không log, không tự phục hồi (trừ
        // khi tình cờ đưa app xuống nền rồi mở lại → restart()). Còn ý định
        // online (_onLocation != null) thì còn phải thử lại.
        if (_onLocation == null) return;
        _errorCount++;
        final secs  = (_errorCount * 3).clamp(3, 30); // 3s, 6s, 9s … tối đa 30s
        final delay = Duration(seconds: secs);
        debugPrint('[LocationService] Retry #$_errorCount in ${delay.inSeconds}s');
        await Future.delayed(delay);
        if (_onLocation != null) await _runExclusive(_listen);
      },
      cancelOnError: true,
    );
  }

  LocationSettings _buildSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 5),
        forceLocationManager: false,
        // Không có foreground service, Android (Doze/tiết kiệm pin) đóng băng
        // GPS + timer heartbeat/vị trí sau vài phút tắt màn hình — tài xế vẫn
        // "online" nhưng app đã bị hệ điều hành cho ngủ, không nhận được đơn.
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'FlashShip đang hoạt động',
          notificationText: 'Đang nhận đơn hàng — đừng tắt để không bị gián đoạn',
          notificationChannelName: 'Đang chạy nền',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    return AppleSettings(
      accuracy: LocationAccuracy.high,
      activityType: ActivityType.automotiveNavigation,
      distanceFilter: 10,
      pauseLocationUpdatesAutomatically: false,
      allowBackgroundLocationUpdates: true,
      showBackgroundLocationIndicator: true,
    );
  }

  Future<bool> _ensurePermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) return false;
    return perm == LocationPermission.always || perm == LocationPermission.whileInUse;
  }
}
