import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/location_push_service.dart';
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
  if (Platform.isAndroid && perm != LocationPermission.always) {
    return 'background_permission';
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
  bool _exitDialogOpen = false;

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
      _resumeOnlineServices();
      ref.read(activeOrderProvider.notifier).fetch();
      ref.read(walletProvider.notifier).fetch();
      NotificationService.refreshPermissionState(ref).then((notGranted) {
        if (mounted) ref.read(notifDeniedProvider.notifier).state = notGranted;
      });
      _checkLocationIssue().then((issue) {
        if (mounted) ref.read(locationIssueProvider.notifier).state = issue;
      });
    }
  }

  Future<void> _resumeOnlineServices() async {
    // Chờ profile server trước khi quyết định khởi động dịch vụ. Dùng cache
    // ngay lập tức từng làm app resume GPS/listener dù backend đã offline,
    // hoặc ngược lại vẫn không phục hồi dù backend đang online.
    await ref.read(authProvider.notifier).refreshUser();
    if (!mounted) return;
    final user = ref.read(authProvider).user;
    if (user?.isOnline != true) {
      LocationPushService.instance.stop();
      OfferListenerService.instance.stop();
      return;
    }

    // refreshUser là request mạng; trong lúc chờ tài xế có thể đã bấm Home
    // hoặc khóa màn hình. Android 14+ không cho mở location foreground
    // service trễ từ background, nên đợi lần resume kế tiếp thay vì cố mở.
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    // Giữ nguyên foreground service nếu nó vẫn sống; chỉ phục hồi phần nào đã
    // chết. Việc stop/start toàn bộ mỗi lần resume tạo ra khe hở mất GPS.
    await LocationPushService.instance.resume(user!.id);
    if (!mounted || ref.read(authProvider).user?.isOnline != true) return;
    OfferListenerService.instance.start(user.id);
    await OfferListenerService.instance.ensureOfferVisible(user.id);
  }

  Future<void> _fetchServiceLabels() => Fmt.ensureLabelsLoaded();

  Future<void> _handleRootBack() async {
    // Ở tab phụ, Back đầu tiên đưa tài xế về Trang chủ thay vì hỏi thoát.
    if (ref.read(homeTabProvider) != 0) {
      ref.read(homeTabProvider.notifier).state = 0;
      return;
    }
    if (_exitDialogOpen || !mounted) return;
    _exitDialogOpen = true;
    final shouldExit = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Thoát Flash Driver?'),
            content: Text(
              ref.read(authProvider).user?.isOnline == true
                  ? 'Bạn đang Online. Thoát ứng dụng có thể làm gián đoạn vị trí và thông báo đơn trên một số điện thoại.'
                  : 'Bạn có chắc chắn muốn thoát ứng dụng?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Ở lại'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Thoát ứng dụng'),
              ),
            ],
          ),
        ) ??
        false;
    _exitDialogOpen = false;
    if (shouldExit && mounted) {
      await SystemNavigator.pop();
    }
  }

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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleRootBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(index: tab, children: pages),
        bottomNavigationBar: BottomNav(
          currentIndex: tab,
          onTap: (i) => ref.read(homeTabProvider.notifier).state = i,
        ),
      ),
    );
  }
}
