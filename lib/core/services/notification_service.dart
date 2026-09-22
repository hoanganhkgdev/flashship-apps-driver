import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:offer_overlay/offer_overlay.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/orders/providers/order_provider.dart';
import '../../features/wallet/providers/wallet_provider.dart';
import '../router/app_router.dart';
import 'location_push_service.dart';
import 'offer_listener_service.dart';
import 'offer_ack_service.dart';

final _localNotif = FlutterLocalNotificationsPlugin();

const _lockedOfferChannel = AndroidNotificationChannel(
  'order_offer_locked_v1',
  'Đơn hàng khi khóa màn hình',
  description: 'Thông báo đơn hàng; chuông do app phát theo thời hạn đơn',
  importance: Importance.max,
  playSound: false,
  enableVibration: true,
);

const _orderOfferChannel = AndroidNotificationChannel(
  'order_offer_channel',
  'Đơn hàng mới',
  description: 'Thông báo đơn hàng mới cho tài xế',
  importance: Importance.max,
  sound: RawResourceAndroidNotificationSound('order_offer'),
  enableVibration: true,
);

/// ID ổn định giữa main isolate và background isolate. `String.hashCode`
/// không phải hợp đồng lưu trữ bền vững, nên không dùng nó để show/cancel
/// notification ở hai tiến trình thực thi khác nhau.
int _offerNotificationId(String orderCode) {
  var hash = 0x811C9DC5;
  for (final byte in utf8.encode(orderCode)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0x7FFFFFFF;
  }
  return hash;
}

/// Banner offer chỉ nên sống đến lúc đơn hết hạn — tính từ expires_at server
/// gửi kèm (epoch giây). Không có/không hợp lệ thì mặc định 25s.
int _offerTimeoutMs(Map<String, dynamic> data) {
  final exp = int.tryParse('${data['expires_at'] ?? ''}') ?? 0;
  if (exp > 0) {
    final remain = exp * 1000 - DateTime.now().millisecondsSinceEpoch;
    if (remain <= 1000) return 1000; // đã hết hạn từ trước — tắt gần như ngay
    if (remain < 60000) return remain;
  }
  return 25000;
}

/// Đảm bảo màn hình offer đang hiện khi tài xế BẤM VÀO thông báo — bất kể
/// lúc bấm app đang tắt hẳn, ở nền, hay đang mở. Dùng chung cho cả 3 nguồn
/// tap: `getInitialMessage()` (app bị kill, bấm mở lại), `onMessageOpenedApp`
/// (app ở nền), `onDidReceiveNotificationResponse` (bấm local notification
/// lúc app còn sống). Trước đây cả 3 đường này đều không làm gì.
///
/// KHÔNG tự dựng dữ liệu đơn từ payload thông báo (chỉ có order_id/
/// order_code/expires_at, thiếu địa chỉ/tiền công...) — payload đó từng bị
/// dùng thẳng làm dữ liệu màn hình, hiện ra toàn ô trống, và nếu RTDB đã mở
/// sẵn màn hình đúng (trường hợp phổ biến nhất — app đang chạy) thì còn GHI
/// ĐÈ mất màn hình tốt đó bằng bản trống. Giao hẳn cho
/// `OfferListenerService.ensureOfferVisible()` — đọc thẳng RTDB (nguồn dữ
/// liệu đầy đủ) và tái dùng đúng logic điều hướng đã có, không tạo đường
/// điều hướng thứ 2 chạy song song dễ lệch nhau.
void _navigateToOfferFromNotification(
    Map<String, dynamic> data, WidgetRef ref) {
  if (data['type'] != 'order_offer') return;
  final driverId = ref.read(authProvider).user?.id;
  if (driverId == null) return;
  OfferListenerService.instance.ensureOfferVisible(driverId);
}

Future<void> _handleNotificationTap(
    Map<String, dynamic> data, WidgetRef ref) async {
  final type = data['type']?.toString();
  if (type == 'order_offer') {
    final orderCode = '${data['order_code'] ?? ''}';
    if (orderCode.isNotEmpty) {
      await _localNotif.cancel(_offerNotificationId(orderCode));
    }
    _navigateToOfferFromNotification(data, ref);
    return;
  }

  final router = appRouter;
  if (router == null) return;
  switch (type) {
    case 'debt_overdue':
      router.go('/wallet');
      break;
    case 'driver_gps_stale_warning':
    case 'driver_auto_offline':
      router.go('/home');
      break;
    case 'order_assigned_direct':
    case 'delivery_reminder':
      await ref.read(activeOrderProvider.notifier).fetch();
      final orders = ref.read(activeOrderProvider).orders;
      if (orders.isNotEmpty) {
        router.go('/order/active', extra: {'orderId': orders.first.id});
      } else {
        router.go('/home');
      }
      break;
    case 'order_status':
      await ref.read(activeOrderProvider.notifier).fetch();
      router.go('/home');
      break;
    default:
      router.go('/home');
  }
}

/// Android nhận order offer dạng high-priority data-only và tự tạo local
/// notification tại đây. Nhờ app sở hữu ID notification, RTDB listener có thể
/// xoá đúng banner khi offer hết hạn/thu hồi; `timeoutAfter` cũng ngăn banner
/// cũ nằm trong khay hàng giờ. iOS vẫn nhận alert trực tiếp từ APNs.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (message.data['type'] != 'order_offer') {
    return;
  }

  final data = message.data;
  final ackOnly = data['ack_only'] == '1';
  final expiry = int.tryParse('${data['expires_at'] ?? ''}');
  if (expiry != null &&
      expiry * 1000 <= DateTime.now().millisecondsSinceEpoch) {
    return;
  }

  // Chỉ ACK khi tài xế thực sự có một kênh nhìn thấy offer: thẻ nổi hoặc
  // notification. Payload tới máy nhưng mọi quyền đều bị chặn không được dùng
  // làm bằng chứng để phạt.
  final settings = await FirebaseMessaging.instance.getNotificationSettings();
  final notificationAllowed =
      settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
  var delivered = notificationAllowed;

  // Android nhận offer dạng high-priority data-only. Tự tạo notification để
  // kiểm soát được ID và timeout; FCM notification do hệ điều hành tự tạo
  // không thể bị app xoá đúng lúc offer hết hạn/thu hồi.
  if (Platform.isAndroid && !ackOnly) {
    // Hai UI cùng lúc rất rối: ưu tiên thẻ nổi. Chỉ tạo notification khi thẻ
    // không thể hiện (màn hình khóa, chưa cấp overlay, hoặc hệ thống từ chối).
    final overlayShown = await OfferOverlay.show(data);
    delivered = overlayShown || notificationAllowed;
    if (!overlayShown && notificationAllowed) {
      final notifications = FlutterLocalNotificationsPlugin();
      await notifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_flashship'),
        ),
      );
      await notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_orderOfferChannel);

      final orderCode = '${data['order_code'] ?? ''}';
      final repeatSound = await OfferOverlay.locked();
      final channel = repeatSound ? _lockedOfferChannel : _orderOfferChannel;
      await notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      final timeoutMs = _offerTimeoutMs(data);
      await notifications.show(
        _offerNotificationId(orderCode),
        data['title']?.toString() ?? 'Có đơn hàng mới!',
        data['body']?.toString() ?? 'Nhấn để xem và nhận đơn hàng',
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.max,
            priority: Priority.high,
            sound: const RawResourceAndroidNotificationSound('order_offer'),
            playSound: !repeatSound,
            // Hiện đầy đủ trên màn hình khóa. Không dùng full-screen intent:
            // Android 14+ chỉ dành quyền đó cho app gọi điện/báo thức.
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.recommendation,
            ticker: 'Có đơn hàng mới — chạm để mở',
            styleInformation: BigTextStyleInformation(
              data['body']?.toString() ?? 'Mở khóa và chạm để xem đơn hàng mới',
              contentTitle: data['title']?.toString() ?? 'Có đơn hàng mới!',
              summaryText: 'Flash Driver',
            ),
            timeoutAfter: repeatSound ? timeoutMs.clamp(1, 25000) : timeoutMs,
            ongoing: true,
            autoCancel: true,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                'open_offer',
                'Xem đơn',
                showsUserInterface: true,
              ),
            ],
          ),
        ),
        payload: jsonEncode(data),
      );
      if (repeatSound) await OfferOverlay.ring(data);
    }
  }

  if (!delivered) return;

  final orderId = int.tryParse('${data['order_id'] ?? ''}');
  if (orderId != null) {
    await OfferAckService.received(
      orderId,
      receiptUrl: data['receipt_url'],
    );
  }
}

class NotificationService {
  static final _fcm = FirebaseMessaging.instance;
  static const _permissionRequestedKey =
      'android_notification_permission_requested';

  /// Xoá banner offer khỏi khay khi offer bị thu hồi
  /// (hết hạn / người khác nhận / khách huỷ).
  static Future<void> cancelOfferNotification(String orderCode) async {
    await OfferOverlay.hide(orderCode);
    await _localNotif.cancel(_offerNotificationId(orderCode));
  }

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
      // Bấm vào local notification (banner offer lúc app đang mở) → mở
      // đúng đơn thay vì chỉ mở app về trang chủ. Payload là JSON encode
      // lại từ data FCM gốc lúc show() — xem bên dưới.
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          _handleNotificationTap(data, ref);
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
        await _handleNotificationTap(data, ref);
      } catch (_) {}
    }

    // Tạo Android notification channel với custom sound (đơn hàng mới)
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_orderOfferChannel);

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
      await _handleNotificationTap(initialMessage.data, ref);
    }

    // Chỉ lấy token ngay nếu đã có quyền — tránh retry APNs 10s khi chưa hỏi
    if (granted == true) await _refreshFcmToken(ref);

    // Huỷ subscription cũ trước khi đăng ký lại (tránh leak khi re-login)
    _tokenRefreshSub?.cancel();
    _onMessageSub?.cancel();
    _onMessageOpenedSub?.cancel();

    _tokenRefreshSub = _fcm.onTokenRefresh.listen((_) => _refreshFcmToken(ref));

    // Foreground: cập nhật state; riêng offer do RTDB mở màn hình trực tiếp.
    _onMessageSub = FirebaseMessaging.onMessage.listen((msg) async {
      final type = msg.data['type'];
      if (type == 'order_offer') {
        final orderId = int.tryParse('${msg.data['order_id'] ?? ''}');
        if (msg.data['ack_only'] == '1') {
          if (orderId != null) {
            await OfferAckService.received(
              orderId,
              receiptUrl: msg.data['receipt_url'],
            );
          }
          return;
        }
        // Foreground: RTDB listener tự mở màn offer; màn hình đó là nguồn
        // phát chuông duy nhất. Không tạo local notification/banner ở đây.
        // Khi app background, message đi qua firebaseBackgroundHandler và
        // handler đó mới tạo notification Android.
        final data = msg.data;
        if (orderId != null) {
          await OfferAckService.received(
            orderId,
            receiptUrl: data['receipt_url'],
          );
        }
      } else if (type == 'order_status' || type == 'order_assigned_direct') {
        try {
          ref.read(activeOrderProvider.notifier).fetch();
        } catch (_) {}
      } else if (type == 'debt_overdue') {
        try {
          ref.read(walletProvider.notifier).fetch();
        } catch (_) {}
      } else if (type == 'driver_auto_offline') {
        // Backend cảnh báo sau 3 phút không có GPS tươi và đóng phiên nếu
        // thêm 1 phút nữa vẫn không phục hồi vị trí.
        LocationPushService.instance.stop();
        OfferListenerService.instance.stop();
        try {
          // Cập nhật state cục bộ trước để nút đổi ngay, rồi đối chiếu profile
          // server nhằm đồng bộ đầy đủ các trường còn lại.
          await ref.read(authProvider.notifier).updateOnlineStatus(false);
          await ref.read(authProvider.notifier).refreshUser();
        } catch (_) {}
      }

      // Foreground: FCM không tự hiện banner — show local notification cho
      // các type chưa có local notification riêng (delivery_reminder,
      // order_taken, order_assigned_direct, broadcast...). order_offer đã
      // show custom notification phía trên (kênh riêng + chuông riêng).
      if (type != 'order_offer' && msg.notification != null) {
        final n = msg.notification!;
        if (n.title != null || n.body != null) {
          _localNotif.show(
            DateTime.now().millisecondsSinceEpoch ~/ 1000,
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
      _handleNotificationTap(msg.data, ref);
    });

    return granted;
  }

  /// Gọi khi tài xế đã xem priming dialog và đồng ý → mới hỏi quyền hệ thống.
  /// Truyền ref để gửi FCM token ngay sau khi cấp quyền lần đầu.
  static Future<bool> requestPermission(WidgetRef ref) async {
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
    var granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
    if (Platform.isAndroid && granted) {
      final android = _localNotif.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      granted = await android?.areNotificationsEnabled() ?? granted;
    }
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
          data: {
            'fcm_token': token,
            'platform': Platform.isIOS ? 'ios' : 'android',
          },
        );
        _tokenSent = true;
      }
    } catch (_) {}
  }
}
