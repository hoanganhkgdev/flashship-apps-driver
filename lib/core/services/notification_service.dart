import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/orders/providers/order_provider.dart';
import '../../features/wallet/providers/wallet_provider.dart';
import 'offer_listener_service.dart';

final _localNotif = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final data = message.data;
  if (data['type'] == 'order_offer') {
    final orderCode = data['order_code'] ?? '';
    final pickupAddress = data['pickup_address'] ?? 'Nhấn để xem đơn hàng';

    final androidDetails = AndroidNotificationDetails(
      'order_offer_channel',
      'Đơn hàng mới',
      channelDescription: 'Thông báo đơn hàng mới cho tài xế',
      importance: Importance.max,
      priority: Priority.high,
      sound: const RawResourceAndroidNotificationSound('order_offer'),
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500, 200, 500, 200, 500]),
      fullScreenIntent: false,
      category: AndroidNotificationCategory.call,
    );

    const iosDetails = DarwinNotificationDetails(
      sound: 'order_offer.aiff',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await _localNotif.show(
      orderCode.hashCode,
      '🚀 Đơn hàng mới #$orderCode',
      pickupAddress,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }
}

class NotificationService {
  static final _fcm = FirebaseMessaging.instance;

  static Future<void> init(WidgetRef ref) async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotif.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Tạo Android notification channel với custom sound
    const channel = AndroidNotificationChannel(
      'order_offer_channel',
      'Đơn hàng mới',
      description: 'Thông báo đơn hàng mới cho tài xế',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('order_offer'),
      enableVibration: true,
    );
    await _localNotif.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    await _refreshFcmToken(ref);
    _fcm.onTokenRefresh.listen((_) => _refreshFcmToken(ref));

    // Foreground: show local notification + refresh state
    FirebaseMessaging.onMessage.listen((msg) {
      final type = msg.data['type'];
      if (type == 'order_offer') {
        // Foreground: RTDB listener tự navigate, chỉ show notification nhỏ
        final data = msg.data;
        _localNotif.show(
          (data['order_code'] ?? '').hashCode,
          '🚀 Đơn hàng mới #${data['order_code'] ?? ''}',
          data['pickup_address'] ?? 'Nhấn để xem đơn hàng',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'order_offer_channel', 'Đơn hàng mới',
              importance: Importance.max, priority: Priority.high,
              sound: RawResourceAndroidNotificationSound('order_offer'),
              playSound: true,
            ),
            iOS: DarwinNotificationDetails(
              sound: 'order_offer.aiff',
              presentSound: true,
              interruptionLevel: InterruptionLevel.timeSensitive,
            ),
          ),
        );
      } else if (type == 'order_status') {
        try { ref.read(activeOrderProvider.notifier).fetch(); } catch (_) {}
      } else if (type == 'debt_overdue') {
        try { ref.read(walletProvider.notifier).fetch(); } catch (_) {}
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((_) {});
  }

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
