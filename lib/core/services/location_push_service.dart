import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';
import 'session_guard_service.dart';

/// Sở hữu TOÀN BỘ việc đẩy vị trí lên Firebase: lấy vị trí lần đầu, nhận
/// luồng GPS, chống trùng, và đồng hồ giữ nhịp 20s khi tài xế đứng yên.
///
/// Trước đây toàn bộ phần này nằm trong `_DashboardPageState` (widget UI).
/// Khi widget bị huỷ mà đang có 1 lệnh ghi Firebase dở dang, lúc lệnh đó
/// xong nó vẫn hẹn lại đồng hồ MỚI trên widget đã chết — đồng hồ này ôm theo
/// toạ độ cũ đóng băng, cứ 20s ghi đè lên Firebase 1 lần rồi tự hẹn lại chính
/// nó, không gì dừng được (chốt chặn `LocationService.isRunning` vô tác dụng
/// vì đó là singleton dùng chung, widget mới vẫn đang chạy). Mỗi lần lặp lại
/// tình huống đó đẻ thêm 1 đồng hồ "ma", gây ra vị trí nhảy loạn theo đúng
/// chu kỳ 20s giữa nhiều toạ độ cũ — xem điều tra tài xế #68/#107/#148/#232.
///
/// Gom về singleton này để chỉ có ĐÚNG 1 đồng hồ tồn tại về mặt cấu trúc, và
/// dùng [_generation] chặn mọi tác vụ dở dang của phiên cũ ghi đè phiên mới.
/// Ghi thô 1 điểm vị trí — mặc định là Firebase thật, test thay bằng hàm giả
/// lập để điều khiển chính xác thời điểm "mạng trả lời" mà không cần thiết bị
/// thật, GPS thật, hay build app thật.
typedef LocationRawWriter = Future<void> Function(int driverId, Map<String, dynamic> data);

class LocationPushService {
  static final LocationPushService instance = LocationPushService._();
  LocationPushService._();

  /// Chỉ dùng trong test — tạo 1 instance độc lập (không phải singleton dùng
  /// chung toàn app) để mô phỏng lỗi "đồng hồ ma" mà không đụng gì tới
  /// Firebase/GPS thật. Xem test/location_push_service_test.dart.
  @visibleForTesting
  LocationPushService.debugForTest({LocationRawWriter? writer})
      : _rawWrite = writer ?? _defaultRawWrite;

  LocationRawWriter _rawWrite = _defaultRawWrite;

  static Future<void> _defaultRawWrite(int driverId, Map<String, dynamic> data) {
    return FirebaseDatabase.instance.ref('locations/driver_$driverId').update(data);
  }

  static const _refreshInterval  = Duration(seconds: 20);
  static const _accuracyMaxMeter = 50.0;

  /// Quá lâu không có fix nào đủ chính xác (hầm gửi xe, nhà cao tầng, máy cũ)
  /// thì chấp nhận dùng tạm fix kém — vị trí lệch vài trăm mét vẫn hơn hẳn
  /// việc tài xế "tàng hình" hoàn toàn với hệ thống phát đơn.
  static const _degradedAfter    = Duration(seconds: 60);

  int?      _driverId;
  String?   _deviceId;
  Timer?    _refreshTimer;
  double?   _lastPushedLat;
  double?   _lastPushedLng;
  double?   _lastPushedBearing;
  DateTime? _noGoodFixSince;

  /// Tăng mỗi lần start()/stop() — mọi tác vụ bất đồng bộ đều chụp lại giá
  /// trị này lúc bắt đầu và bỏ kết quả nếu đã lệch, để lệnh ghi dở dang của
  /// phiên cũ không bao giờ hẹn lại đồng hồ hay ghi đè trạng thái phiên mới.
  int _generation = 0;

  bool get isPushing => _driverId != null;

  /// Chỉ dùng trong test — gán thẳng driverId để gọi được [debugPush] mà
  /// không cần đi qua start() thật (vốn cần quyền GPS/Geolocator thật).
  @visibleForTesting
  void debugSetDriverId(int? id) => _driverId = id;

  /// Chỉ dùng trong test — gọi thẳng logic ghi (giống hệt production dùng),
  /// không qua luồng GPS thật.
  @visibleForTesting
  Future<void> debugPush(double lat, double lng, double bearing, {bool force = false}) =>
      _push(lat, lng, bearing, force: force);

  /// Chỉ dùng trong test — xem đồng hồ giữ nhịp có đang tồn tại không, để
  /// khẳng định KHÔNG có đồng hồ "ma" nào bị bỏ sót sau stop().
  @visibleForTesting
  bool get debugHasPendingRefreshTimer => _refreshTimer != null;

  Future<void> start(int driverId) async {
    stop();
    final gen = _generation;
    _driverId = driverId;
    _deviceId ??= await SessionGuardService.getDeviceId();
    if (gen != _generation) return;

    await _fetchOnce();
    if (gen != _generation) return;

    await LocationService.instance.start(_onFix);
    if (gen != _generation) return;

    _scheduleRefresh();
  }

  void stop() {
    _generation++;
    _refreshTimer?.cancel();
    _refreshTimer     = null;
    _driverId         = null;
    _lastPushedLat    = null;
    _lastPushedLng    = null;
    _lastPushedBearing = null;
    _noGoodFixSince   = null;
    LocationService.instance.stop();
  }

  // ── Nội bộ ──────────────────────────────────────────────────────────────────

  /// Fix đủ chính xác → đẩy ngay. Fix kém → chỉ đẩy nếu đã quá [_degradedAfter]
  /// mà vẫn chưa có fix nào tốt, và tối đa 1 lần mỗi chu kỳ đó (vẫn luôn ưu
  /// tiên fix tốt ngay khi có lại).
  void _onFix(double lat, double lng, double bearing, double accuracy) {
    if (accuracy <= _accuracyMaxMeter) {
      _noGoodFixSince = null;
      _push(lat, lng, bearing);
      return;
    }

    final now = DateTime.now();
    _noGoodFixSince ??= now;
    if (now.difference(_noGoodFixSince!) >= _degradedAfter) {
      debugPrint('[LocationPush] ${_degradedAfter.inSeconds}s không có fix ≤${_accuracyMaxMeter}m '
          '→ đẩy tạm fix accuracy=${accuracy.round()}m để không bị tàng hình');
      _noGoodFixSince = now; // đặt lại đồng hồ, tránh spam fix kém liên tục
      _push(lat, lng, bearing);
    }
  }

  /// Lấy 1 vị trí ngay khi vừa bật online — không đợi luồng GPS bắn lần đầu
  /// (có thể mất vài giây), tránh khoảng trống tài xế "vô hình" lúc mới bật.
  Future<void> _fetchOnce() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6), // tránh treo khi GPS chưa bắt được tín hiệu
        ),
      );
      // Đi chung đường với luồng GPS để dùng chung luật lọc/dự phòng độ chính
      // xác, không tự lọc riêng một kiểu như trước.
      _onFix(pos.latitude, pos.longitude, pos.heading < 0 ? 0.0 : pos.heading, pos.accuracy);
    } catch (e) {
      debugPrint('[LocationPush] getCurrentPosition failed: $e'); // hết giờ/không có GPS → luồng sẽ tự cập nhật
    }
  }

  /// Hẹn giờ 1 lần, luôn đặt lại từ đúng thời điểm lần đẩy gần nhất (không
  /// dùng Timer.periodic cố định — sẽ bị lệch nhịp: nếu tick rơi đúng lúc vừa
  /// mới đẩy xong thì chưa đủ ngưỡng, phải đợi tới tick SAU nữa mới đẩy, khiến
  /// khoảng cách thực tế thành ~40s thay vì 20s).
  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    if (_driverId == null) return;
    final gen = _generation;
    _refreshTimer = Timer(_refreshInterval, () {
      if (gen != _generation || _driverId == null) return;
      if (_lastPushedLat != null && _lastPushedLng != null) {
        debugPrint('[LocationPush] Đứng yên đủ 20s → đẩy lại toạ độ đang có (force)');
        _push(_lastPushedLat!, _lastPushedLng!, _lastPushedBearing ?? 0, force: true);
      } else {
        // Chưa từng đẩy được lần nào (fetch-once lẫn luồng đều chưa xong) —
        // chưa có gì để đẩy lại, thử kiểm tra tiếp sau 20s nữa.
        _scheduleRefresh();
      }
    });
  }

  Future<void> _push(double lat, double lng, double bearing, {bool force = false}) async {
    final driverId = _driverId;
    if (driverId == null) return;
    // Toạ độ y hệt lần đẩy gần nhất (luồng vẫn có thể bắn lại dù chưa đổi
    // thật, hoặc trùng với lần fetch-once lúc mới bật online) → bỏ qua, trừ
    // khi force=true (đẩy lại chủ động từ _scheduleRefresh lúc đứng yên).
    if (!force && _lastPushedLat == lat && _lastPushedLng == lng) return;

    final gen = _generation;

    // KHÔNG tự kiểm tra session_device trước khi ghi nữa. Security Rules của
    // Firebase (database.rules.json) đã chặn cứng ngay tại máy chủ:
    //   auth.uid == 'driver_<id>_' + dispatch/driver_<id>/session_device
    // Thiết bị cũ bị đăng nhập đè sẽ bị TỪ CHỐI ghi, dù nó có tự kiểm tra hay
    // không. Việc kiểm tra thêm ở client vừa thừa (yếu hơn hẳn: đọc rồi mới
    // ghi nên vẫn có khe hở giữa 2 bước), vừa tốn nguyên 1 vòng gọi mạng cho
    // MỖI lần đẩy GPS (5–20 giây/lần, suốt ca làm việc). Thay bằng cách bắt
    // đúng lỗi bị từ chối ở dưới — vừa chính xác tuyệt đối vừa miễn phí.
    try {
      // update() thay vì set() để không xóa các field khác backend có thể ghi vào node này
      await _rawWrite(driverId, {
        'lat': lat,
        'lng': lng,
        'bearing': bearing,
        'updated_at': ServerValue.timestamp,
        if (_deviceId != null) 'device_id': _deviceId,
        'platform': Platform.isAndroid ? 'android' : 'ios',
      });
      // Đã stop() hoặc start() lại trong lúc chờ mạng — bỏ kết quả này, KHÔNG
      // ghi lại trạng thái và KHÔNG hẹn đồng hồ (đây chính là chỗ sinh ra
      // đồng hồ "ma" ở bản cũ khi phần này còn nằm trong widget).
      if (gen != _generation) return;
      _lastPushedLat     = lat;
      _lastPushedLng     = lng;
      _lastPushedBearing = bearing;
    } on FirebaseException catch (e) {
      // Security Rules từ chối = thiết bị này không còn là phiên hiện hành
      // (máy khác vừa đăng nhập đè). Đây là câu trả lời CHẮC CHẮN từ máy chủ,
      // đáng tin hơn mọi phép tự kiểm tra ở client — dừng hẳn và đăng xuất.
      if (e.code == 'permission-denied') {
        // Phân biệt 2 nguyên nhân cùng cho ra "permission-denied":
        //  1. CHƯA đăng nhập được Firebase Auth (vd lúc login gọi
        //     /auth/firebase-token bị lỗi mạng — chỗ đó cố tình không chặn
        //     đăng nhập). Đây là lỗi hạ tầng, KHÔNG phải bị đăng nhập đè —
        //     đăng xuất ở đây là đá oan tài xế ra khỏi app.
        //  2. Có đăng nhập Firebase nhưng Rules vẫn từ chối ⇒ session_device
        //     trên máy chủ đã đổi ⇒ đúng là máy khác vừa đăng nhập đè.
        if (FirebaseAuth.instance.currentUser != null) {
          debugPrint('[LocationPush] Firebase từ chối ghi — thiết bị đã bị đăng nhập đè, tự logout');
          stop();
          SessionGuardService.instance.onForceLogout?.call();
          return;
        }
        debugPrint('[LocationPush] Bị từ chối ghi do chưa có phiên Firebase Auth '
            '(không phải bị đăng nhập đè) — giữ nguyên đăng nhập, sẽ thử lại sau');
      } else {
        debugPrint('[LocationPush] Firebase write failed: $e');
      }
    } catch (e) {
      debugPrint('[LocationPush] Firebase write failed: $e');
    }

    // Hẹn lại đồng hồ 20s dù ghi THÀNH CÔNG hay THẤT BẠI. Nếu chỉ hẹn khi
    // thành công, đúng 1 lần mất mạng ngay lúc đồng hồ bắn là đứt hẳn chuỗi
    // giữ nhịp: tài xế đứng yên sẽ không bao giờ làm mới updated_at nữa, và
    // sau 10 phút bị backend coi như mất tích, không nhận được đơn nào.
    if (gen == _generation && _driverId != null) _scheduleRefresh();
  }
}
