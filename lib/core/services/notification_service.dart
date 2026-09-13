import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/orders/providers/order_provider.dart';
import '../../features/wallet/providers/wallet_provider.dart';
import 'offer_listener_service.dart';
import 'offer_ack_service.dart';

final _localNotif = FlutterLocalNotificationsPlugin();

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
void _navigateToOfferFromNotification(Map<String, dynamic> data, WidgetRef ref) {
  if (data['type'] != 'order_offer') return;
  final driverId = ref.read(authProvider).user?.id;
  if (driverId == null) return;
  OfferListenerService.instance.ensureOfferVisible(driverId);
}

/// KHÔNG tự show local notification ở đây nữa. Backend (`FCMService::
/// sendDriverWakeUp()`) đã gửi kèm khối `notification` (không chỉ `data`)
/// đúng kênh `order_offer_channel` — khi app ở nền/bị kill, hệ điều hành TỰ
/// hiển thị thông báo hệ thống thẳng từ khối đó, không cần code Dart chạy.
/// Trước đây gọi `_localNotif.show()` thêm ở đây tạo ra **2 thông báo trùng
/// lặp** mỗi lần app ở nền/bị kill, và bản thân lệnh gọi cũng rủi ro vì
/// plugin local-notifications chưa từng được `initialize()` trong tiến
/// trình nền riêng biệt này. Giữ hàm rỗng (chỉ init Firebase) vì
/// `FirebaseMessaging.onBackgroundMessage()` bắt buộc phải có 1 handler
/// đã đăng ký.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (message.data['type'] != 'order_offer') {
    return;
  }

  // notification+data ở background được OS hiển. Chỉ ACK khi
  // quyền thông báo thật sự đang được cấp; payload tới máy nhưng
  // OS bị chặn quyền không được dùng làm bằng chứng để phạt.
  final settings = await FirebaseMessaging.instance.getNotificationSettings();
  final allowed = settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;
  if (!allowed) return;

  final orderId = int.tryParse('${message.data['order_id'] ?? ''}');
  if (orderId != null) {
    await OfferAckService.received(
      orderId,
      receiptUrl: message.data['receipt_url'],
    );
  }
}

class NotificationService {
  static final _fcm = FirebaseMessaging.instance;

  /// Xoá banner offer khỏi khay khi offer bị thu hồi
  /// (hết hạn / người khác nhận / khách huỷ).
  static Future<void> cancelOfferNotification(String orderCode) =>
      _localNotif.cancel(orderCode.hashCode);

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
      // Bấm vào local notification (banner offer lúc app đang mở) → mở
      // đúng đơn thay vì chỉ mở app về trang chủ. Payload là JSON encode
      // lại từ data FCM gốc lúc show() — xem bên dưới.
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          _navigateToOfferFromNotification(data, ref);
        } catch (_) {}
      },
    );

    // Tạo Android notification channel với custom sound (đơn hàng mới)
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
    await _localNotif.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(generalChannel);

    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    // App bị kill hẳn, tài xế bấm vào thông báo hệ thống (OS tự hiện từ
    // khối `notification` backend gửi kèm) → mở lại đúng đơn. Chỉ có giá
    // trị đúng 1 lần ngay sau khi app khởi động do bị tap-launch.
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _navigateToOfferFromNotification(initialMessage.data, ref);
    }

    // Chỉ lấy token ngay nếu đã có quyền — tránh retry APNs 10s khi chưa hỏi
    if (granted == true) await _refreshFcmToken(ref);

    // Huỷ subscription cũ trước khi đăng ký lại (tránh leak khi re-login)
    _tokenRefreshSub?.cancel();
    _onMessageSub?.cancel();
    _onMessageOpenedSub?.cancel();

    _tokenRefreshSub = _fcm.onTokenRefresh.listen((_) => _refreshFcmToken(ref));

    // Foreground: show local notification + refresh state
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
        // Foreground: RTDB listener tự navigate, chỉ show notification nhỏ
        final data = msg.data;
        await _localNotif.show(
          (data['order_code'] ?? '').hashCode,
          'Có đơn hàng mới!',
          'Nhấn để xem và nhận đơn hàng',
          NotificationDetails(
            android: AndroidNotificationDetails(
              'order_offer_channel', 'Đơn hàng mới',
              importance: Importance.max, priority: Priority.high,
              sound: const RawResourceAndroidNotificationSound('order_offer'),
              playSound: true,
              timeoutAfter: _offerTimeoutMs(data),
            ),
            iOS: const DarwinNotificationDetails(
              sound: 'order_offer.aiff',
              presentSound: true,
              interruptionLevel: InterruptionLevel.timeSensitive,
            ),
          ),
          // Cần payload để onDidReceiveNotificationResponse biết đơn nào
          // khi tài xế bấm vào banner này lúc app đang mở/nền nhẹ.
          payload: jsonEncode(data),
        );
        if (orderId != null) {
          await OfferAckService.received(
            orderId,
            receiptUrl: data['receipt_url'],
          );
        }
      } else if (type == 'order_status' || type == 'order_assigned_direct') {
        try { ref.read(activeOrderProvider.notifier).fetch(); } catch (_) {}
      } else if (type == 'debt_overdue') {
        try { ref.read(walletProvider.notifier).fetch(); } catch (_) {}
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
                'general_channel', 'Thông báo chung',
                importance: Importance.high, priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(),
            ),
          );
        }
      }
    });

    // App đang ở nền (chưa bị kill), tài xế bấm vào thông báo hệ thống →
    // mở lại đúng đơn — trước đây callback rỗng, bấm vào chỉ đưa app lên
    // foreground ở màn hình đang dở, không thấy đơn đâu.
    _onMessageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _navigateToOfferFromNotification(msg.data, ref);
    });

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
