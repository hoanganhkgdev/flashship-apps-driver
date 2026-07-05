import 'dart:async';
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
      'Có đơn hàng mới!',
      'Nhấn để xem và nhận đơn hàng',
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }
}

class NotificationService {
  static final _fcm = FirebaseMessaging.instance;

  static StreamSubscription? _tokenRefreshSub;
  static StreamSubscription? _onMessageSub;
  static StreamSubscription? _onMessageOpenedSub;

  // Đã gửi FCM token lên backend chưa (trong phiên hiện tại) — tránh POST thừa
  // mỗi lần resume, nhưng vẫn gửi được khi user bật quyền từ Cài đặt.
  static bool _tokenSent = false;

  /// Setup FCM + local notifications. KHÔNG request quyền ở đây.
  /// Trả về: true = đã được cấp, false = bị từ chối, null = chưa hỏi lần nào.
  static Future<bool?> init(WidgetRef ref) async {
    final settings = await _fcm.getNotificationSettings();
    final status = settings.authorizationStatus;
    final bool? granted = (status == AuthorizationStatus.authorized ||
            status == AuthorizationStatus.provisional)
        ? true
        : status == AuthorizationStatus.denied
            ? false
            : null; // notDetermined

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Không request quyền trong initialize — để HomeScreen hỏi đúng lúc
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
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

    // Chỉ lấy token ngay nếu đã có quyền — tránh retry APNs 10s khi chưa hỏi
    if (granted == true) await _refreshFcmToken(ref);

    // Huỷ subscription cũ trước khi đăng ký lại (tránh leak khi re-login)
    _tokenRefreshSub?.cancel();
    _onMessageSub?.cancel();
    _onMessageOpenedSub?.cancel();

    _tokenRefreshSub = _fcm.onTokenRefresh.listen((_) => _refreshFcmToken(ref));

    // Foreground: show local notification + refresh state
    _onMessageSub = FirebaseMessaging.onMessage.listen((msg) {
      final type = msg.data['type'];
      if (type == 'order_offer') {
        // Foreground: RTDB listener tự navigate, chỉ show notification nhỏ
        final data = msg.data;
        _localNotif.show(
          (data['order_code'] ?? '').hashCode,
          'Có đơn hàng mới!',
          'Nhấn để xem và nhận đơn hàng',
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

    _onMessageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((_) {});

    return granted;
  }

  /// Gọi khi tài xế đã xem priming dialog và đồng ý → mới hỏi quyền hệ thống.
  /// Truyền ref để gửi FCM token ngay sau khi cấp quyền lần đầu.
  static Future<bool> requestPermission(WidgetRef ref) async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);
    final settings = await _fcm.getNotificationSettings();
    final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (granted) await _refreshFcmToken(ref);
    return granted;
  }

  /// Gọi khi app resume: cập nhật trạng thái quyền cho banner, đồng thời
  /// nếu đã có quyền mà token chưa gửi (user vừa bật quyền từ Cài đặt) thì
  /// gửi FCM token lên backend — nếu không tài xế có quyền nhưng vẫn không
  /// nhận được push đơn hàng.
  /// Trả về true nếu CHƯA được cấp quyền (để hiện banner).
  static Future<bool> refreshPermissionState(WidgetRef ref) async {
    final settings = await _fcm.getNotificationSettings();
    final status = settings.authorizationStatus;
    final granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
    if (granted && !_tokenSent) await _refreshFcmToken(ref);
    return !granted;
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
        _tokenSent = true;
      }
    } catch (_) {}
  }
}
