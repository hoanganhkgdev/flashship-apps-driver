import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';
import '../router/app_router.dart';

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
  bool _offerVisible = false;

  /// Callback được set bởi HomeScreen để reset tab khi offer bị dismiss
  VoidCallback? onOfferDismissed;

  void start(int driverId) {
    if (_sub != null && _driverId == driverId) return;
    stop();
    _driverId = driverId;

    _sub = FirebaseDatabase.instance
        .ref('dispatch/driver_$driverId/offer')
        .onValue
        .listen(_onEvent, onError: (_) {});
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _driverId = null;
    _offerVisible = false;
  }

  /// Gọi khi offer screen tự xử lý (accept / decline / tự dismiss).
  void markOfferHandled() => _offerVisible = false;

  void _onEvent(DatabaseEvent event) {
    final data = event.snapshot.value;

    if (data == null) {
      if (_offerVisible) {
        _offerVisible = false;
        _navigateHome();
      }
      return;
    }

    final offer = Map<String, dynamic>.from(data as Map);

    final expiresAt = (offer['expires_at'] as num?)?.toInt() ?? 0;
    final remaining = expiresAt - DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (remaining <= 0) {
      _clearOffer();
      return;
    }

    if (!_offerVisible) {
      _offerVisible = true;
      _navigateToOffer(offer);
    }
  }

  void _navigateToOffer(Map<String, dynamic> offer) {
    final orderId = (offer['order_id'] as num?)?.toInt();
    if (orderId == null) return;

    void attempt() {
      final router = appRouter;
      if (router != null) {
        router.go('/order/offer/$orderId', extra: offer);
      } else {
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
