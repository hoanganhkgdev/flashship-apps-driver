import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';
import '../router/app_router.dart';
import 'notification_service.dart';

/// Lắng nghe RTDB path dispatch/driver_{id}/offer.
/// Khi backend ghi offer → navigate tới màn hình offer.
/// Khi backend xóa offer (timeout / accept / decline / customer cancel) → dismiss.
///
/// Singleton — chỉ start/stop theo online status, không phụ thuộc màn hình.
class OfferListenerService {
  static final instance = OfferListenerService._();
  OfferListenerService._();

  StreamSubscription? _sub;
  int? _driverId;
  // Mã đơn đang hiện trên màn hình offer (null = không có gì đang hiện) —
  // trước đây chỉ là cờ đúng/sai, không phân biệt được đơn nào. Nếu đơn A
  // hết hạn và đơn B được ghi gần như cùng lúc, Firebase có thể chỉ giao sự
  // kiện cuối (đơn B) — cờ đúng/sai sẽ thấy "đang hiện rồi" và bỏ qua đơn B,
  // tài xế vẫn đứng nhìn đơn A đã chết. So sánh theo orderId sửa đúng lỗi này.
  int? _visibleOrderId;
  String? _lastOrderCode;

  /// Callback được set bởi HomeScreen để reset tab khi offer bị dismiss
  VoidCallback? onOfferDismissed;

  void start(int driverId) {
    if (_sub != null && _driverId == driverId) return;
    stop();
    _driverId = driverId;

    _sub = FirebaseDatabase.instance
        .ref('dispatch/driver_$driverId/offer')
        .onValue
        .listen((event) => _handleValue(event.snapshot.value), onError: (e) {
      debugPrint('[OfferListener] RTDB error: $e');
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _driverId = null;
    _visibleOrderId = null;
  }

  /// Gọi khi offer screen tự xử lý (accept / decline / tự dismiss) — chỉ mở
  /// lại nếu đúng đơn đang được coi là hiện, tránh 1 lệnh gọi trễ của màn
  /// hình đơn CŨ vô tình xoá trạng thái "đang hiện" của đơn MỚI hơn.
  void markOfferHandled(int orderId) {
    if (_visibleOrderId == orderId) _visibleOrderId = null;
  }

  /// Đảm bảo offer hiện tại (nếu còn) đang được hiển thị — gọi khi tài xế
  /// bấm vào thông báo, không phụ thuộc listener RTDB đã chạy hay chưa (app
  /// vừa mở lại từ trạng thái bị kill thì listener chưa kịp start). Đọc
  /// thẳng 1 lần từ RTDB — nguồn dữ liệu đầy đủ, không dùng dữ liệu tối
  /// thiểu có trong payload thông báo (thiếu địa chỉ/tiền công...).
  Future<void> ensureOfferVisible(int driverId) async {
    _driverId ??= driverId;
    try {
      final snap = await FirebaseDatabase.instance
          .ref('dispatch/driver_$driverId/offer')
          .get();
      _handleValue(snap.value);
    } catch (e) {
      debugPrint('[OfferListener] ensureOfferVisible failed: $e');
    }
  }

  void _handleValue(Object? data) {
    if (data == null) {
      // Offer bị thu hồi (hết hạn / người khác nhận / khách huỷ)
      // → xoá luôn banner trong khay để không bấm vào đơn đã chết.
      _cancelOfferBanner();
      if (_visibleOrderId != null) {
        _visibleOrderId = null;
        _navigateHome();
      }
      return;
    }

    if (data is! Map) return;
    final offer = Map<String, dynamic>.from(data);
    _lastOrderCode = '${offer['order_code'] ?? ''}';

    // Kiểm tra orderId hợp lệ TRƯỚC khi đụng vào _visibleOrderId — trước
    // đây bật cờ "đang hiện" rồi mới kiểm tra bên trong _navigateToOffer(),
    // nên payload thiếu order_id sẽ làm cờ kẹt "đang hiện" mãi mãi dù chưa
    // từng mở màn hình nào (dispose() không cứu được vì màn hình không hề
    // tồn tại để mà huỷ).
    final orderId = (offer['order_id'] as num?)?.toInt();
    if (orderId == null) return;

    final expiresAt = (offer['expires_at'] as num?)?.toInt() ?? 0;
    final remaining = expiresAt - DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (remaining <= 0) {
      _cancelOfferBanner();
      _clearOffer();
      return;
    }

    if (_visibleOrderId != orderId) {
      _visibleOrderId = orderId;
      _navigateToOffer(offer, orderId);
    }
  }

  void _cancelOfferBanner() {
    final code = _lastOrderCode;
    if (code != null && code.isNotEmpty) {
      NotificationService.cancelOfferNotification(code);
      _lastOrderCode = null;
    }
  }

  void _navigateToOffer(Map<String, dynamic> offer, int orderId) {
    var retries = 0;
    void attempt() {
      if (_driverId == null) return; // đã stop() trong lúc chờ
      final router = appRouter;
      if (router != null) {
        router.go('/order/offer/$orderId', extra: offer);
      } else if (++retries < 10) {
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
      }
    }

    attempt();
  }

  void _navigateHome() {
    onOfferDismissed?.call(); // reset tab về 0
    final router = appRouter;
    if (router != null) {
      router.go('/home');
    }
  }

  Future<void> _clearOffer() async {
    if (_driverId == null) return;
    try {
      await FirebaseDatabase.instance
          .ref('dispatch/driver_$_driverId/offer')
          .remove();
    } catch (_) {}
  }
}
