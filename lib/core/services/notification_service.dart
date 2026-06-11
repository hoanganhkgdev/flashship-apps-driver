import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/orders/providers/order_provider.dart';
import 'offer_listener_service.dart';

final _localNotif = FlutterLocalNotificationsPlugin();

/// Background isolate handler — chỉ cần wake app, không parse order data.
/// OfferListenerService sẽ đọc offer từ RTDB sau khi app sống lại.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Không cần làm gì — FCM chỉ là wake-up signal.
  // Khi app resume, OfferListenerService tự đọc RTDB stream.
}

class NotificationService {
  static final _fcm = FirebaseMessaging.instance;

  static Future<void> init(WidgetRef ref) async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Local notifications — dùng cho order_status update khi app foreground
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotif.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    await _refreshFcmToken(ref);
    _fcm.onTokenRefresh.listen((_) => _refreshFcmToken(ref));

    // Foreground: FCM chỉ trigger refresh state, không navigate
    FirebaseMessaging.onMessage.listen((msg) {
      final type = msg.data['type'];
      if (type == 'order_offer') {
        // Wake-up signal — OfferListenerService đã lắng nghe RTDB, không cần làm gì
      } else if (type == 'order_status') {
        try { ref.read(activeOrderProvider.notifier).fetch(); } catch (_) {}
      }
    });

    // Khi driver tap notification từ background — OfferListenerService tự xử lý
    // Không cần parse FCM payload để navigate
    FirebaseMessaging.onMessageOpenedApp.listen((_) {
      // App đã ở foreground, RTDB stream sẽ fire nếu có offer
    });

    // Killed state → app mở → RTDB stream tự fire
    // Không cần xử lý getInitialMessage cho offer nữa
  }

  /// Gọi sau khi driver xác nhận online để đảm bảo OfferListenerService đang chạy.
  static void ensureOfferListener(int driverId) {
    OfferListenerService.instance.start(driverId);
  }

  static Future<void> _refreshFcmToken(WidgetRef ref) async {
    try {
      if (Platform.isIOS) {
        for (var i = 0; i < 5; i++) {
          final apns = await _fcm.getAPNSToken();
          if (apns != null) break;
          await Future.delayed(const Duration(seconds: 2));
        }
      }
      final token = await _fcm.getToken();
      if (token != null) {
        await ref.read(apiClientProvider).post(
          '/driver/update-fcm-token',
          data: {'fcm_token': token},
        );
      }
    } catch (_) {}
  }
}
