import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/home/providers/home_providers.dart';
import '../../features/order_market/providers/order_market_provider.dart';
import '../../features/orders/providers/order_provider.dart';
import '../../features/wallet/providers/wallet_provider.dart';
import '../providers/app_container.dart';
import '../router/app_router.dart';

final _localNotif = FlutterLocalNotificationsPlugin();

/// Bấm vào thông báo. Dùng [appContainer] (sống suốt vòng đời app), không
/// dùng WidgetRef của màn hình — màn có thể đã bị huỷ (đăng xuất) khi bấm.
Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
  try {
    await _routeNotificationTap(data);
  } catch (e) {
    debugPrint('[Notif] xử lý bấm thông báo lỗi: $e');
  }
}

Future<void> _routeNotificationTap(Map<String, dynamic> data) async {
  final ref = appContainer;
  final type = data['type']?.toString();
  final router = appRouter;
  if (router == null) return;
  // Chưa đăng nhập: chỉ mở app, để router tự đưa về màn đăng nhập.
  if (!ref.read(authProvider).isAuthenticated) return;
  switch (type) {
    case 'debt_overdue':
      router.go('/wallet');
      break;
    case 'order_assigned_direct':
    case 'delivery_reminder':
      await ref.read(activeOrderProvider.notifier).fetch();
      final orders = ref.read(activeOrderProvider).orders;
      if (orders.isNotEmpty) {
        ref.read(homeTabProvider.notifier).state = 0;
        ref.read(homeOrdersTabProvider.notifier).state = 1;
        router.go('/home');
      } else {
        router.go('/home');
      }
      break;
    case 'order_status':
      await ref.read(activeOrderProvider.notifier).fetch();
      router.go('/home');
      break;
    case 'order_market':
      ref.read(homeTabProvider.notifier).state = 0;
      ref.read(homeOrdersTabProvider.notifier).state = 0;
      router.go('/home');
      unawaited(ref.read(orderMarketProvider.notifier).fetch(silent: true));
      break;
    default:
      router.go('/home');
  }
}

/// Thông báo đơn mới có khối `notification` nên hệ điều hành tự hiện; handler nền chỉ cần khởi tạo Firebase.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  static final _fcm = FirebaseMessaging.instance;
  static const _permissionRequestedKey =
      'android_notification_permission_requested';

  static StreamSubscription? _tokenRefreshSub;
  static StreamSubscription? _onMessageSub;
  static StreamSubscription? _onMessageOpenedSub;

  // Đã gửi FCM token lên backend cho tài xế nào (trong phiên app hiện tại) —
  // tránh POST thừa mỗi lần resume, nhưng vẫn gửi lại khi user bật quyền từ
  // Cài đặt hoặc khi đăng nhập tài khoản khác trên cùng máy.
  static int? _tokenSentFor;

  static int? get _driverId => appContainer.read(authProvider).user?.id;

  // Id thông báo foreground — tăng dần để 2 thông báo đến cùng giây không đè nhau.
  static int _nextLocalId =
      DateTime.now().millisecondsSinceEpoch ~/ 1000 % 1000000;

  /// Setup FCM + local notifications. KHÔNG request quyền ở đây.
  /// Trả về: true = đã được cấp, false = bị từ chối, null = chưa hỏi lần nào.
  static Future<bool?> init() async {
    final settings = await _fcm.getNotificationSettings();
    final status = settings.authorizationStatus;
    final prefs = await SharedPreferences.getInstance();
    final permissionRequested = prefs.getBool(_permissionRequestedKey) ?? false;
    bool? granted = (status == AuthorizationStatus.authorized ||
            status == AuthorizationStatus.provisional)
        ? true
        : status == AuthorizationStatus.denied
            // Android 13+ không phân biệt "chưa từng hỏi" với
            // "người dùng đã từ chối": cả hai đều trả `denied`.
            // Tự lưu cờ này để lần cài mới vẫn hiện priming
            // dialog và request quyền hệ thống đúng một lần.
            ? (Platform.isAndroid && !permissionRequested ? null : false)
            : null; // notDetermined

    const android = AndroidInitializationSettings('ic_stat_flashship');
    // Không request quyền trong initialize — để HomeScreen hỏi đúng lúc
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotif.initialize(
      const InitializationSettings(android: android, iOS: ios),
      // Bấm vào local notification (thông báo lúc app đang mở) → mở
      // đúng đơn thay vì chỉ mở app về trang chủ. Payload là JSON encode
      // lại từ data FCM gốc lúc show() — xem bên dưới.
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          _handleNotificationTap(data);
        } catch (_) {}
      },
    );

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    if (Platform.isAndroid && granted == true) {
      final android = _localNotif.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      granted = await android?.areNotificationsEnabled() ?? granted;
    }

    final localLaunch = await _localNotif.getNotificationAppLaunchDetails();
    final localPayload = localLaunch?.notificationResponse?.payload;
    if (localLaunch?.didNotificationLaunchApp == true && localPayload != null) {
      try {
        final data = jsonDecode(localPayload) as Map<String, dynamic>;
        await _handleNotificationTap(data);
      } catch (_) {}
    }

    // Kênh chung cho các thông báo còn lại (đơn bị huỷ, công nợ...) — không
    // set thì Android 8+ tự đẩy vào kênh mặc định "Miscellaneous" (chuông
    // im, dễ bị tài xế bỏ sót). Khớp với `default_notification_channel_id`
    // khai trong AndroidManifest.xml để FCM tự dùng kênh này cho MỌI thông
    // báo không chỉ định channel_id riêng — không cần sửa gì thêm ở backend.
    const generalChannel = AndroidNotificationChannel(
      'general_channel',
      'Thông báo chung',
      description: 'Đơn bị huỷ, công nợ, và các thông báo khác',
      importance: Importance.high,
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(generalChannel);

    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    // App bị kill hẳn, tài xế bấm vào thông báo hệ thống (OS tự hiện từ
    // khối `notification` backend gửi kèm) → mở lại đúng đơn. Chỉ có giá
    // trị đúng 1 lần ngay sau khi app khởi động do bị tap-launch.
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      await _handleNotificationTap(initialMessage.data);
    }

    // Chỉ lấy token ngay nếu đã có quyền — tránh retry APNs 10s khi chưa hỏi
    if (granted == true) await _refreshFcmToken();

    // Huỷ subscription cũ trước khi đăng ký lại (tránh leak khi re-login)
    _tokenRefreshSub?.cancel();
    _onMessageSub?.cancel();
    _onMessageOpenedSub?.cancel();

    _tokenRefreshSub = _fcm.onTokenRefresh.listen((_) => _refreshFcmToken());

    // Foreground: cập nhật state theo loại thông báo.
    _onMessageSub = FirebaseMessaging.onMessage.listen((msg) async {
      final ref = appContainer;
      // Đã đăng xuất: không làm mới dữ liệu, không hiện thông báo của phiên cũ.
      if (!ref.read(authProvider).isAuthenticated) return;
      final type = msg.data['type'];
      if (type == 'order_market') {
        // RTDB chỉ mang revision. FCM là kênh dự phòng độc lập: khi nhận được
        // push lúc foreground, tải danh sách có thẩm quyền từ API ngay để
        // tài xế không phải chờ nhịp poll hoặc tự kéo làm mới.
        try {
          await ref.read(orderMarketProvider.notifier).fetch(silent: true);
        } catch (_) {}
      } else if (type == 'order_status' || type == 'order_assigned_direct') {
        try {
          ref.read(activeOrderProvider.notifier).fetch();
        } catch (_) {}
      } else if (type == 'debt_overdue') {
        try {
          ref.read(walletProvider.notifier).fetch();
        } catch (_) {}
      }

      // Foreground: FCM không tự hiện banner — show local notification cho
      // mọi type (delivery_reminder, order_market, order_assigned_direct, broadcast...).
      if (msg.notification != null) {
        final n = msg.notification!;
        if (n.title != null || n.body != null) {
          _localNotif.show(
            _nextLocalId++,
            n.title ?? '',
            n.body ?? '',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'general_channel',
                'Thông báo chung',
                importance: Importance.high,
                priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(),
            ),
            payload: jsonEncode(msg.data),
          );
        }
      }
    });

    // App đang ở nền (chưa bị kill), tài xế bấm vào thông báo hệ thống →
    // mở lại đúng đơn — trước đây callback rỗng, bấm vào chỉ đưa app lên
    // foreground ở màn hình đang dở, không thấy đơn đâu.
    _onMessageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _handleNotificationTap(msg.data);
    });

    return granted;
  }

  /// Gọi khi tài xế đã xem priming dialog và đồng ý → mới hỏi quyền hệ thống.
  /// Truyền ref để gửi FCM token ngay sau khi cấp quyền lần đầu.
  static Future<bool> requestPermission() async {
    // Ghi trước khi gọi API hệ thống: kể cả khi Activity bị
    // recreate trong lúc dialog đang hiện, app cũng không hỏi lặp.
    if (Platform.isAndroid) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_permissionRequestedKey, true);
    }
    await _fcm.requestPermission(alert: true, badge: true, sound: true);
    final settings = await _fcm.getNotificationSettings();
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    if (granted) await _refreshFcmToken();
    return granted;
  }

  /// Gọi khi app resume: cập nhật trạng thái quyền cho banner, đồng thời
  /// nếu đã có quyền mà token chưa gửi (user vừa bật quyền từ Cài đặt) thì
  /// gửi FCM token lên backend — nếu không tài xế có quyền nhưng vẫn không
  /// nhận được push đơn hàng.
  /// Trả về true nếu CHƯA được cấp quyền (để hiện banner).
  static Future<bool> refreshPermissionState() async {
    final settings = await _fcm.getNotificationSettings();
    final status = settings.authorizationStatus;
    var granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
    if (Platform.isAndroid && granted) {
      final android = _localNotif.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      granted = await android?.areNotificationsEnabled() ?? granted;
    }
    if (granted && _tokenSentFor != _driverId) await _refreshFcmToken();
    return !granted;
  }

  static Future<void> _refreshFcmToken() async {
    final driverId = _driverId;
    if (driverId == null) return;
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
        await appContainer.read(apiClientProvider).post(
          '/driver/update-fcm-token',
          data: {
            'fcm_token': token,
            'platform': Platform.isIOS ? 'ios' : 'android',
          },
        );
        _tokenSentFor = driverId;
      }
    } catch (_) {}
  }
}
