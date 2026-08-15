import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/offer_listener_service.dart';
import '../../../core/services/session_guard_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../providers/home_providers.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/dashboard_banners.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/order_provider.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../orders/screens/history_screen.dart';
import '../../wallet/screens/earnings_screen.dart';
import '../../profile/screens/profile_screen.dart';
import 'dashboard_page.dart';

Future<String?> _checkLocationIssue() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return 'service';
  final perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied ||
      perm == LocationPermission.deniedForever) {
    return 'permission';
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Root shell
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  StreamSubscription<ServiceStatus>? _gpsStatusSub;
  Timer? _locationRecheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Theo dõi realtime khi GPS bị bật/tắt ngay lúc app đang mở (kéo thanh
    // notification tắt GPS mà không rời app → resume không kích hoạt).
    _gpsStatusSub = Geolocator.getServiceStatusStream().listen((_) async {
      final issue = await _checkLocationIssue();
      if (mounted) ref.read(locationIssueProvider.notifier).state = issue;
    }, onError: (_) {});

    // Lưới an toàn cho _gpsStatusSub — trên 1 số máy/OS, stream service
    // status không bắn lại đáng tin cậy lúc GPS được BẬT lại (nhất là khi
    // không có location manager nào đang hoạt động vì tài xế đang offline),
    // khiến banner "GPS đang tắt" bị đứng lại dù GPS đã bật. Poll nhẹ mỗi 5s
    // — nhưng chỉ thật sự gọi Geolocator khi đang có banner hiển thị, lúc
    // bình thường gần như không tốn gì.
    _locationRecheckTimer =
        Timer.periodic(const Duration(seconds: 5), (_) async {
      if (ref.read(locationIssueProvider) == null) return;
      final issue = await _checkLocationIssue();
      if (mounted) ref.read(locationIssueProvider.notifier).state = issue;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // try/finally đảm bảo location check luôn chạy dù có return sớm
      try {
        final status = await NotificationService.init(ref);
        if (status == true) {
          if (mounted) ref.read(notifDeniedProvider.notifier).state = false;
          return;
        }
        if (status == null) {
          // Chưa hỏi lần nào → hiện priming dialog trước
          if (!mounted) return;
          final confirmed = await showNotifPrimingDialog(context);
          if (!mounted) return;
          if (confirmed == true) {
            final granted = await NotificationService.requestPermission(ref);
            if (mounted) {
              ref.read(notifDeniedProvider.notifier).state = !granted;
            }
          } else {
            if (mounted) ref.read(notifDeniedProvider.notifier).state = true;
          }
        } else {
          // Đã từ chối → hiện banner hướng dẫn vào Settings
          if (mounted) ref.read(notifDeniedProvider.notifier).state = true;
        }
      } finally {
        final locationIssue = await _checkLocationIssue();
        if (mounted) {
          ref.read(locationIssueProvider.notifier).state = locationIssue;
        }
      }
    });
    Future.microtask(() {
      ref.read(activeOrderProvider.notifier).fetch();
      ref.read(walletProvider.notifier).fetch();
      _fetchServiceLabels();
      _startSessionGuard();
    });
  }

  Future<void> _startSessionGuard() async {
    final uid = ref.read(authProvider).user?.id;
    if (uid == null) return;

    // logout() tự dừng LocationService/OfferListenerService + dọn Firebase —
    // xem auth_provider.dart, gom về 1 chỗ cho mọi đường gọi logout.
    SessionGuardService.instance.onForceLogout = () async {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        context.go('/login');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tài khoản vừa đăng nhập trên thiết bị khác.'),
            backgroundColor: Color(0xFFE53935),
            duration: Duration(seconds: 5),
          ),
        );
      }
    };

    SessionGuardService.instance.onAccountLocked = () async {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        context.go('/login');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Tài khoản của bạn đã bị khóa. Liên hệ hỗ trợ để biết thêm.'),
            backgroundColor: Color(0xFFE53935),
            duration: Duration(seconds: 6),
          ),
        );
      }
    };

    await SessionGuardService.instance.start(uid);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(authProvider.notifier).refreshUser();
      ref.read(activeOrderProvider.notifier).fetch();
      ref.read(walletProvider.notifier).fetch();
      NotificationService.refreshPermissionState(ref).then((notGranted) {
        if (mounted) ref.read(notifDeniedProvider.notifier).state = notGranted;
      });
      _checkLocationIssue().then((issue) {
        if (mounted) ref.read(locationIssueProvider.notifier).state = issue;
      });
      // Đảm bảo location stream còn sống sau khi app về foreground
      final user = ref.read(authProvider).user;
      final isOnline = user?.isOnline ?? false;
      if (isOnline) {
        LocationService.instance.restart();
        // Listener nhận đơn có thể đã chết/treo sau thời gian dài ở nền
        // (Doze, mất mạng, iOS đóng băng socket) — trước đây chỉ GPS được
        // cứu ở đây, đúng kiểu bất đối xứng đã gây ra bug GPS "chết vĩnh
        // viễn". Đọc thẳng RTDB 1 lần, có đơn đang chờ thì mở màn hình
        // ngay thay vì để trôi trong im lặng.
        if (user != null) {
          OfferListenerService.instance.ensureOfferVisible(user.id);
        }
      }
    }
  }

  Future<void> _fetchServiceLabels() => Fmt.ensureLabelsLoaded();

  @override
  void dispose() {
    _gpsStatusSub?.cancel();
    _locationRecheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    SessionGuardService.instance.onForceLogout = null;
    SessionGuardService.instance.onAccountLocked = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(homeTabProvider);
    final pages = <Widget>[
      DashboardPage(
          onGoToWallet: () => ref.read(homeTabProvider.notifier).state = 2),
      const HistoryScreen(),
      const EarningsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      // Cho body vẽ tràn xuống phía sau bottomNavigationBar — bắt buộc để
      // hiệu ứng kính mờ (BackdropFilter) của BottomNav có nội dung thật
      // phía sau để làm mờ, thay vì chỉ mờ màu nền phẳng của Scaffold.
      extendBody: true,
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: BottomNav(
        currentIndex: tab,
        onTap: (i) => ref.read(homeTabProvider.notifier).state = i,
      ),
    );
  }
}
