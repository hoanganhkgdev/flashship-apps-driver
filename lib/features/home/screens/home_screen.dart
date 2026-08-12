import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart' hide ServiceStatus;
import '../../../core/services/notification_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/location_push_service.dart';
import '../../../core/services/offer_listener_service.dart';
import '../../../core/services/session_guard_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/order_provider.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../orders/screens/history_screen.dart';
import '../../wallet/screens/debt_screen.dart';
import '../../wallet/screens/earnings_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../score/models/score_model.dart';
import '../../score/providers/score_provider.dart';
import '../../shifts/providers/shift_provider.dart';
import '../../shifts/screens/shift_registration_screen.dart';
import '../providers/support_provider.dart';

final homeTabProvider = StateProvider<int>((ref) => 0);
final _notifDeniedProvider = StateProvider<bool>((ref) => false);
// 'service' = GPS tắt, 'permission' = quyền bị từ chối, null = ổn
final _locationIssueProvider = StateProvider<String?>((ref) => null);

Future<String?> _checkLocationIssue() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return 'service';
  final perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Theo dõi realtime khi GPS bị bật/tắt ngay lúc app đang mở (kéo thanh
    // notification tắt GPS mà không rời app → resume không kích hoạt).
    _gpsStatusSub = Geolocator.getServiceStatusStream().listen((_) async {
      final issue = await _checkLocationIssue();
      if (mounted) ref.read(_locationIssueProvider.notifier).state = issue;
    }, onError: (_) {});
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // try/finally đảm bảo location check luôn chạy dù có return sớm
      try {
        final status = await NotificationService.init(ref);
        if (status == true) {
          if (mounted) ref.read(_notifDeniedProvider.notifier).state = false;
          return;
        }
        if (status == null) {
          // Chưa hỏi lần nào → hiện priming dialog trước
          if (!mounted) return;
          final confirmed = await _showNotifPrimingDialog(context);
          if (!mounted) return;
          if (confirmed == true) {
            final granted = await NotificationService.requestPermission(ref);
            if (mounted) ref.read(_notifDeniedProvider.notifier).state = !granted;
          } else {
            if (mounted) ref.read(_notifDeniedProvider.notifier).state = true;
          }
        } else {
          // Đã từ chối → hiện banner hướng dẫn vào Settings
          if (mounted) ref.read(_notifDeniedProvider.notifier).state = true;
        }
      } finally {
        final locationIssue = await _checkLocationIssue();
        if (mounted) ref.read(_locationIssueProvider.notifier).state = locationIssue;
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
            content: Text('Tài khoản của bạn đã bị khóa. Liên hệ hỗ trợ để biết thêm.'),
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
        if (mounted) ref.read(_notifDeniedProvider.notifier).state = notGranted;
      });
      _checkLocationIssue().then((issue) {
        if (mounted) ref.read(_locationIssueProvider.notifier).state = issue;
      });
      // Đảm bảo location stream còn sống sau khi app về foreground
      final isOnline = ref.read(authProvider).user?.isOnline ?? false;
      if (isOnline) LocationService.instance.restart();
    }
  }

  Future<void> _fetchServiceLabels() => Fmt.ensureLabelsLoaded();

  @override
  void dispose() {
    _gpsStatusSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    SessionGuardService.instance.onForceLogout   = null;
    SessionGuardService.instance.onAccountLocked = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab   = ref.watch(homeTabProvider);
    final pages = <Widget>[
      _DashboardPage(onGoToWallet: () => ref.read(homeTabProvider.notifier).state = 2),
      const HistoryScreen(),
      const EarningsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: _BottomNav(
        currentIndex: tab,
        onTap: (i) => ref.read(homeTabProvider.notifier).state = i,
      ),
    );
  }
}

// ── Bottom nav ────────────────────────────────────────────────────────────────

class _NavItem {
  final IconData on;
  final IconData off;
  final String label;
  const _NavItem(this.on, this.off, this.label);
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  static const _tabs = [
    _NavItem(Icons.home_rounded,           Icons.home_outlined,           'Trang chủ'),
    _NavItem(Icons.receipt_long_rounded,   Icons.receipt_long_outlined,   'Đơn hàng'),
    _NavItem(Icons.bar_chart_rounded,      Icons.bar_chart_outlined,      'Thu nhập'),
    _NavItem(Icons.person_rounded,         Icons.person_outline_rounded,  'Tài khoản'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: EdgeInsets.fromLTRB(12, 0, 12, bottom + 8),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final tab      = _tabs[i];
          final selected = i == currentIndex;
          final color    = selected ? AppColors.primary : const Color(0xFF9E9E9E);
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(selected ? tab.on : tab.off, size: 22, color: color),
                ),
                const SizedBox(height: 3),
                Text(
                  tab.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: color,
                  ),
                ),
              ]),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard page
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardPage extends ConsumerStatefulWidget {
  final VoidCallback onGoToWallet;
  const _DashboardPage({required this.onGoToWallet});

  @override
  ConsumerState<_DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<_DashboardPage>
    with WidgetsBindingObserver {
  bool _togglingOnline   = false;
  Map<String, dynamic> _stats = {};
  int _todayEarnings     = 0;
  int _yesterdayEarnings = 0;
  Timer? _onlineTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAll();
    Future.microtask(() {
      _syncOnlineTimer();
      final uid = ref.read(authProvider).user?.id;
      if (uid != null) ref.read(scoreProvider.notifier).subscribeRTDB(uid);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Card thu nhập/số đơn/rating + COD không tự refresh trên resume như ví
    // → làm mới để tránh hiển thị số liệu cũ khi mở lại app.
    if (state == AppLifecycleState.resumed) _loadAll();
  }

  void _syncOnlineTimer() {
    final driver = ref.read(authProvider).user;
    if (driver?.isOnline != true) return;
    OfferListenerService.instance.start(driver!.id);
    OfferListenerService.instance.onOfferDismissed =
        () => ref.read(homeTabProvider.notifier).state = 0;
    LocationPushService.instance.start(driver.id);
    _startOnlineTimer();
  }

  void _startOnlineTimer() {
    _onlineTimer?.cancel();
    _onlineTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopOnlineTimer() {
    _onlineTimer?.cancel();
    _onlineTimer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _onlineTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() => Future.wait([
        _loadStats(),
        _loadEarnings(),
        Future.microtask(() => ref.read(scoreProvider.notifier).fetch()),
        Future.microtask(() => ref.read(shiftProvider.notifier).fetch()),
      ]);

  Future<void> _loadStats() async {
    try {
      final res  = await ref.read(apiClientProvider).get('/orders/dashboard');
      final data = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      if (mounted) setState(() => _stats = data);
    } catch (_) {}
  }

  Future<void> _loadEarnings() async {
    try {
      final res  = await ref.read(apiClientProvider).get('/earnings/summary');
      final data = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _todayEarnings     = (data['today']?['total']     as num?)?.toInt() ?? 0;
          _yesterdayEarnings = (data['yesterday']?['total'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<bool> _ensureLocationPermission() async {
    // GPS service phải bật — nếu không tài xế online nhưng không push được
    // vị trí → ghost driver (dispatch không thấy toạ độ).
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('GPS đang tắt. Vui lòng bật vị trí để có thể nhận đơn.'),
        backgroundColor: AppColors.danger,
        action: SnackBarAction(
          label: 'Bật GPS',
          textColor: Colors.white,
          onPressed: () => Geolocator.openLocationSettings(),
        ),
      ));
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) return true;
    if (!mounted) return false;
    if (perm == LocationPermission.deniedForever) {
      await _showLocationPermissionGuide(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cần quyền vị trí để bật online')));
    }
    return false;
  }

  Future<void> _forceOffline() async {
    final isOnline = ref.read(authProvider).user?.isOnline ?? false;
    if (!isOnline || _togglingOnline) return;
    if (mounted) setState(() => _togglingOnline = true);
    // Dừng gửi vị trí NGAY trước khi gọi API — cùng lý do với _toggleOnline():
    // chờ tới lúc có phản hồi mới dừng thì stream/timer vẫn kịp bắn 1 lần
    // trong lúc chờ mạng, ghi đè lên ngay sau lệnh xoá Firebase.
    _stopOnlineTimer();
    LocationPushService.instance.stop();
    OfferListenerService.instance.stop();
    try {
      final res             = await ref.read(apiClientProvider).post('/driver/toggle-status');
      final raw             = res.data['is_online'];
      final nowOnline       = raw == true || raw == 1;
      final onlineSince     = res.data['online_since'] != null
          ? DateTime.tryParse(res.data['online_since'] as String) : null;
      await ref.read(authProvider.notifier).updateOnlineStatus(
        nowOnline,
        onlineSince: onlineSince,
      );
      final uid = ref.read(authProvider).user?.id;
      if (uid != null) {
        FirebaseDatabase.instance.ref('locations/driver_$uid').remove().ignore();
      }
    } catch (_) {}
    if (mounted) setState(() => _togglingOnline = false);
  }

  Future<void> _toggleOnline() async {
    // Chặn gọi chồng — nếu không, có thể race với _forceOffline() (nợ vừa
    // quá hạn) hoặc 1 tap bị xử lý trễ, gây tắt/bật liên tiếp trong 1 giây.
    if (_togglingOnline) return;
    final currentlyOnline = ref.read(authProvider).user?.isOnline ?? false;
    if (!currentlyOnline) {
      setState(() => _togglingOnline = true);
      final granted = await _ensureLocationPermission();
      if (!granted) {
        if (mounted) setState(() => _togglingOnline = false);
        return;
      }
    } else {
      // Dừng gửi vị trí NGAY (trước khi gọi API) — nếu chờ tới lúc có phản
      // hồi mới dừng, stream/timer vẫn kịp bắn 1 lần trong lúc chờ mạng, rồi
      // ghi đè lên đúng lúc lệnh xoá Firebase vừa chạy xong (thứ tự 2 request
      // mạng không đảm bảo) — marker "chớp lại" thay vì biến mất hẳn.
      _stopOnlineTimer();
      LocationPushService.instance.stop();
      OfferListenerService.instance.stop();
    }
    setState(() => _togglingOnline = true);
    try {
      final res              = await ref.read(apiClientProvider).post('/driver/toggle-status');
      final raw              = res.data['is_online'];
      final isOnline         = raw == true || raw == 1;
      final onlineSince      = res.data['online_since'] != null
          ? DateTime.tryParse(res.data['online_since'] as String) : null;
      await ref.read(authProvider.notifier).updateOnlineStatus(
        isOnline,
        onlineSince: onlineSince,
      );
      if (isOnline) {
        _startOnlineTimer();
        final uid = ref.read(authProvider).user?.id;
        if (uid != null) {
          LocationPushService.instance.start(uid);
          OfferListenerService.instance.start(uid);
        }
      } else {
        // Đã dừng LocationPushService/timer ở trên (trước khi gọi API) rồi —
        // ở đây chỉ còn dọn Firebase.
        final uid = ref.read(authProvider).user?.id;
        if (uid != null) {
          FirebaseDatabase.instance.ref('locations/driver_$uid').remove().ignore();
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        // Body có thể không phải Map (HTML 500, string...) → cast an toàn
        final data = e.response?.data;
        final code = data is Map ? data['code'] as String? : null;
        if (code == 'debt_overdue') {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Bạn có công nợ quá hạn. Vui lòng thanh toán trước khi hoạt động.'),
            backgroundColor: AppColors.danger,
            action: SnackBarAction(
              label: 'Xem công nợ',
              textColor: Colors.white,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DebtScreen()),
              ),
            ),
          ));
        } else {
          final msg = data is Map ? data['message'] as String? : null;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg ?? 'Không thể đổi trạng thái'),
            backgroundColor: AppColors.danger,
          ));
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _togglingOnline = false);
  }

  @override
  Widget build(BuildContext context) {
    final user        = ref.watch(authProvider).user;
    final wallet      = ref.watch(walletProvider);
    final scoreState  = ref.watch(scoreProvider);
    final isOnline    = user?.isOnline ?? false;
    final notifDenied   = ref.watch(_notifDeniedProvider);
    final locationIssue = ref.watch(_locationIssueProvider);
    final shiftState    = ref.watch(shiftProvider);
    final hasNoShift     = shiftState.hasLoadedOnce &&
        !shiftState.loading &&
        shiftState.currentShiftIds.isEmpty;

    ref.listen<WalletState>(walletProvider, (prev, next) {
      final hadOverdue = prev?.debts.any((d) => d.isOverdue) ?? false;
      final hasOverdue = next.debts.any((d) => d.isOverdue);
      if (!hadOverdue && hasOverdue) _forceOffline();
    });

    // Đơn active giảm (hoàn tất / huỷ) → làm mới thu nhập, số đơn + ví/công nợ
    ref.listen<ActiveOrderState>(activeOrderProvider, (prev, next) {
      if ((prev?.orders.length ?? 0) > next.orders.length) {
        _loadAll();
        ref.read(walletProvider.notifier).fetch();
      }
    });

    final hasOverdueDebt = wallet.debts.any((d) => d.isOverdue);
    // Công nợ = tổng còn lại (amount - đã trả) của các khoản chưa tất toán,
    // lấy từ walletProvider (cùng nguồn với banner & màn công nợ).
    final codPending = wallet.debts.fold<int>(0, (s, d) => s + d.remaining);
    final debtCount  = wallet.debts.length;

    final todayOrders = ((_stats['today_orders'] as num?) ?? 0).toInt();
    final rating      = (_stats['rating']        as num?)?.toDouble() ?? 0.0;
    final ratingCount = ((_stats['rating_count'] as num?) ?? 0).toInt();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Gradient header + toggle ─────────────────────────────
              _GradientHeader(
                user:          user,
                isOnline:      isOnline,
                toggling:      _togglingOnline,
                locked:        hasOverdueDebt,
                onToggle:      _toggleOnline,
              ),

              // ── Location / GPS banner ─────────────────────────────────
              if (locationIssue != null) _LocationIssueBanner(issue: locationIssue),

              // ── Notification permission banner ────────────────────────
              if (notifDenied) const _NotifDeniedBanner(),

              // ── No shift registered banner ────────────────────────────
              if (hasNoShift)
                _NoShiftBanner(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ShiftRegistrationScreen()),
                  ),
                ),

              // ── Overdue debt banner ───────────────────────────────────
              if (wallet.debts.any((d) => d.isOverdue)) ...[
                _OverdueBanner(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DebtScreen()),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Content cards ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // Earnings
                    _EarningsCard(
                      todayEarnings:     _todayEarnings,
                      yesterdayEarnings: _yesterdayEarnings,
                      todayOrders:       todayOrders,
                      rating:            rating,
                      ratingCount:       ratingCount,
                      onTap:             widget.onGoToWallet,
                    ),

                    const SizedBox(height: 12),

                    // Score
                    _ScoreCard(
                      score:   scoreState.score,
                      onTap:   () => context.push('/score'),
                    ),

                    const SizedBox(height: 12),

                    // Finance
                    _FinanceCard(
                      balance:     wallet.balance,
                      codPending:  codPending,
                      debtCount:   debtCount,
                      onWalletTap: () => context.push('/wallet'),
                      onDebtTap:   () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DebtScreen())),
                    ),

                    const SizedBox(height: 12),

                    // Support
                    _SupportCard(),

                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Gradient header ───────────────────────────────────────────────────────────

class _GradientHeader extends StatelessWidget {
  final dynamic user;
  final bool isOnline;
  final bool toggling;
  final bool locked;
  final VoidCallback onToggle;

  const _GradientHeader({
    required this.user,
    required this.isOnline,
    required this.toggling,
    required this.locked,
    required this.onToggle,
  });

  Widget _avatarInitials(String? initials) => Center(
        child: Text(initials ?? 'D',
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      );

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFCC5A08), Color(0xFFE8720C), Color(0xFFF59E30)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(top: -50, right: -50, child: _Bubble(180, 0.07)),
          Positioned(top: 90,  left: -30,  child: _Bubble(90,  0.05)),
          Positioned(bottom: 40, right: 30, child: _Bubble(55, 0.04)),

          Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Avatar row
                Row(children: [
                  // Avatar
                  Stack(children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: user?.profilePhotoUrl != null
                          ? Image.network(
                              user!.profilePhotoUrl!,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              loadingBuilder: (_, child, progress) =>
                                  progress == null ? child : _avatarInitials(user?.initials),
                              errorBuilder: (_, __, ___) => _avatarInitials(user?.initials),
                            )
                          : _avatarInitials(user?.initials),
                    ),
                    // Online dot
                    Positioned(
                      bottom: 2, right: 2,
                      child: Container(
                        width: 13, height: 13,
                        decoration: BoxDecoration(
                          color: isOnline ? AppColors.success : const Color(0xFF9CA3AF),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(width: 12),

                  // Name
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        'Xin chào 👋',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.name ?? 'Tài xế',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]),
                  ),
                ]),

                const SizedBox(height: 16),

                // Toggle card (white, floating on gradient)
                GestureDetector(
                  onTap: (toggling || locked) ? null : onToggle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(children: [

                      // Toggle switch
                      if (toggling)
                        const SizedBox(
                          width: 52, height: 30,
                          child: Center(child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                          )),
                        )
                      else
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 52, height: 30,
                          decoration: BoxDecoration(
                            color: locked
                                ? const Color(0xFFDDDDDD)
                                : isOnline ? AppColors.success : const Color(0xFFDDDDDD),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            alignment: isOnline ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              width: 24, height: 24,
                              margin: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                  color: Colors.white, shape: BoxShape.circle),
                            ),
                          ),
                        ),

                      const SizedBox(width: 14),

                      // Label
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            locked
                                ? 'Bị khóa do công nợ'
                                : isOnline ? 'Đang nhận đơn' : 'Bật để nhận đơn',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: locked
                                  ? AppColors.danger
                                  : isOnline ? AppColors.success : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            locked
                                ? 'Thanh toán công nợ để tiếp tục'
                                : isOnline ? 'Đang hoạt động' : 'Nhấn để bắt đầu',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),

          Container(height: 20, color: AppColors.background),
        ],
      ),          // Column
      ],          // Stack.children
    ),            // Stack
    );
  }
}

class _Bubble extends StatelessWidget {
  final double size, opacity;
  const _Bubble(this.size, this.opacity);
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );
}

// ── Earnings card ─────────────────────────────────────────────────────────────

class _EarningsCard extends StatelessWidget {
  final int todayEarnings;
  final int yesterdayEarnings;
  final int todayOrders;
  final double rating;
  final int ratingCount;
  final VoidCallback onTap;

  const _EarningsCard({
    required this.todayEarnings,
    required this.yesterdayEarnings,
    required this.todayOrders,
    required this.rating,
    required this.ratingCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _surfaceCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Header
          Row(children: [
            const Text('Thu nhập hôm nay',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                )),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary),
          ]),

          const SizedBox(height: 12),

          // Amount + yesterday
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Text(
                Fmt.currency(todayEarnings),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: AppColors.success,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            if (yesterdayEarnings > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Hôm qua ${Fmt.currency(yesterdayEarnings)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
              ),
          ]),

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),

          // Stats row
          Row(children: [
            _miniStat('$todayOrders', 'Đơn hôm nay', Icons.inventory_2_rounded),
            _vDivider(),
            _miniStat(
              rating > 0 ? rating.toStringAsFixed(1) : '—',
              ratingCount > 0 ? '$ratingCount đánh giá' : 'Đánh giá',
              Icons.star_rounded,
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _vDivider() => Container(
      width: 1, height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: AppColors.divider);

  Widget _miniStat(String value, String label, IconData icon) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 11, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
          ]),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ]),
      );
}

// ── Score card ────────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final DriverScoreModel? score;
  final VoidCallback onTap;
  const _ScoreCard({required this.score, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _surfaceCard(
        // Chỉ hiện spinner lần đầu (chưa có điểm). Khi đã có điểm thì giữ hiển
        // thị trong lúc refresh (RTDB ping / resume) để tránh nháy sang spinner.
        child: score == null
            ? const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2)))
            : _content(score!),
      ),
    );
  }

  Widget _content(DriverScoreModel s) {
    final progress =
        (s.maxScore > 0 ? s.score / s.maxScore : 0.0).clamp(0.0, 1.0);

    return Row(children: [

      // Mini ring
      SizedBox(
        width: 60, height: 60,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: 1, strokeWidth: 6,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress, strokeWidth: 6,
              strokeCap: StrokeCap.round,
              color: AppColors.primary,
            ),
          ),
          Text('${s.score}',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
        ]),
      ),

      const SizedBox(width: 14),

      // Info
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Điểm tích lũy',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                )),
            const SizedBox(width: 8),
            Text('${s.score} / ${s.maxScore}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 5),
          Row(children: [
            Text(s.label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${s.score} điểm',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress, minHeight: 4,
              backgroundColor: AppColors.divider,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ]),
      ),

      const SizedBox(width: 8),
      const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary),
    ]);
  }
}

// ── Finance card ──────────────────────────────────────────────────────────────

class _FinanceCard extends StatelessWidget {
  final int balance;
  final int codPending;
  final int debtCount;
  final VoidCallback onWalletTap;
  final VoidCallback onDebtTap;

  const _FinanceCard({
    required this.balance,
    required this.codPending,
    required this.debtCount,
    required this.onWalletTap,
    required this.onDebtTap,
  });

  @override
  Widget build(BuildContext context) {
    final debtColor = debtCount > 0 ? AppColors.danger : AppColors.textSecondary;

    return _surfaceCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        const Text('Tài chính',
            style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            )),

        const SizedBox(height: 14),

        Row(children: [

          // ── Wallet ──────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: onWalletTap,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.18)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.13),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded,
                          size: 17, color: AppColors.success),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppColors.success),
                  ]),
                  const SizedBox(height: 10),
                  const Text('Ví cá nhân',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      )),
                  const SizedBox(height: 4),
                  Text(Fmt.currency(balance),
                      style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900,
                        color: AppColors.success,
                      )),
                ]),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ── Debt ────────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: onDebtTap,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: debtColor.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: debtColor.withValues(alpha: 0.18)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: debtColor.withValues(alpha: 0.13),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.receipt_long_rounded,
                          size: 17, color: debtColor),
                    ),
                    const Spacer(),
                    if (debtCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('$debtCount',
                            style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w800,
                              color: Colors.white,
                            )),
                      )
                    else
                      Icon(Icons.chevron_right_rounded,
                          size: 16, color: debtColor),
                  ]),
                  const SizedBox(height: 10),
                  const Text('Công nợ',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      )),
                  const SizedBox(height: 4),
                  Text(Fmt.currency(codPending),
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900,
                        color: debtColor,
                      )),
                ]),
              ),
            ),
          ),

        ]),
      ]),
    );
  }
}

// ── Support card ──────────────────────────────────────────────────────────────

class _SupportCard extends ConsumerWidget {
  const _SupportCard();

  Future<void> _launch(BuildContext context, SupportItem item) async {
    // URI xấu (admin nhập sai) có thể ném exception → bọc try/catch để hiện
    // thông báo thay vì crash.
    bool ok = false;
    try {
      ok = await launchUrl(item.uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở liên kết này')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(supportProvider);
    final items = async.valueOrNull ?? [];

    final chips = items.map((item) => _SupportChipData(
      icon: item.materialIcon,
      label: item.title,
      cta: item.ctaLabel,
      color: item.displayColor,
      onTap: () => _launch(context, item),
    )).toList();

    return _surfaceCard(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Hỗ trợ',
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              )),
        ),

        const SizedBox(height: 14),

        if (async.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            )),
          )
        else
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _SupportChip(data: chips[i]),
            ),
          ),

      ]),
    );
  }
}

class _SupportChipData {
  final IconData? icon;
  final String label;
  final String cta;
  final Color color;
  final VoidCallback onTap;

  const _SupportChipData({
    this.icon,
    required this.label,
    required this.cta,
    required this.color,
    required this.onTap,
  });
}

class _SupportChip extends StatelessWidget {
  final _SupportChipData data;
  const _SupportChip({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: data.onTap,
      child: Container(
        width: 108,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: data.color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: data.color.withValues(alpha: 0.18)),
        ),
        child: Stack(children: [

          // Watermark
          Positioned(
            right: -10, bottom: -10,
            child: Icon(data.icon ?? Icons.link_rounded,
                size: 64, color: data.color.withValues(alpha: 0.10)),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(data.icon ?? Icons.link_rounded, size: 18, color: data.color),
              ),

              const SizedBox(height: 10),

              Text(data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: data.color,
                  )),

              const SizedBox(height: 3),
              Text(data.cta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w500,
                    color: data.color.withValues(alpha: 0.7),
                  )),

            ]),
          ),

        ]),
      ),
    );
  }
}


// ── Overdue debt banner ────────────────────────────────────────────────────────

class _OverdueBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _OverdueBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        color: const Color(0xFFCC2222),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Bạn có công nợ quá hạn. Vui lòng thanh toán để tiếp tục nhận đơn.',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Thanh toán',
                style: TextStyle(
                  color: Color(0xFFCC2222),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ]),
      ),
    );
  }
}

// ── No shift registered banner ─────────────────────────────────────────────────

class _NoShiftBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _NoShiftBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        color: const Color(0xFFE65100),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Row(children: [
          const Icon(Icons.schedule_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Bạn chưa đăng ký ca làm việc. Đăng ký ngay để được xếp lịch.',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Đăng ký',
                style: TextStyle(
                  color: Color(0xFFE65100),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ]),
      ),
    );
  }
}

// ── Notification priming dialog (Apple compliance) ───────────────────────────

Future<bool?> _showNotifPrimingDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Icon(Icons.notifications_active_rounded, color: Color(0xFFE65100), size: 22),
        SizedBox(width: 10),
        Text('Bật thông báo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ]),
      content: const Text(
        'Flash Driver cần gửi thông báo để báo khi có đơn hàng mới.\n\nKhông có thông báo, bạn sẽ không nhận được đơn.',
        style: TextStyle(fontSize: 14, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Bỏ qua', style: TextStyle(color: Color(0xFF9E9E9E))),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
          child: const Text('Cho phép'),
        ),
      ],
    ),
  );
}

// ── Location permission guide dialog ─────────────────────────────────────────

Future<void> _showLocationPermissionGuide(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Icon(Icons.location_on_rounded, color: Color(0xFF1565C0), size: 22),
        SizedBox(width: 10),
        Text('Cấp quyền vị trí', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ]),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Làm theo 4 bước sau:', style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
          SizedBox(height: 12),
          _GuideStep(number: '1', text: 'Bấm "Mở cài đặt" bên dưới'),
          SizedBox(height: 8),
          _GuideStep(number: '2', text: 'Chọn ứng dụng Flash Driver'),
          SizedBox(height: 8),
          _GuideStep(number: '3', text: 'Chọn Vị trí'),
          SizedBox(height: 8),
          _GuideStep(number: '4', text: 'Chọn "Luôn luôn"'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Để sau', style: TextStyle(color: Color(0xFF9E9E9E))),
        ),
        FilledButton(
          onPressed: () { Navigator.pop(context); Geolocator.openAppSettings(); },
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
          child: const Text('Mở cài đặt'),
        ),
      ],
    ),
  );
}

// ── Location / GPS banner ─────────────────────────────────────────────────────

class _LocationIssueBanner extends StatelessWidget {
  final String issue;
  const _LocationIssueBanner({required this.issue});

  @override
  Widget build(BuildContext context) {
    final isServiceOff = issue == 'service';
    return _AlertCard(
      color: const Color(0xFF1565C0),
      icon: isServiceOff ? Icons.location_off_rounded : Icons.location_disabled_rounded,
      title: isServiceOff ? 'GPS đang tắt' : 'Chưa cấp quyền vị trí',
      subtitle: 'Hãy bật để nhận đơn',
      buttonLabel: isServiceOff ? 'Bật GPS' : 'Mở cài đặt',
      onTap: () => isServiceOff
          ? Geolocator.openLocationSettings()
          : _showLocationPermissionGuide(context),
    );
  }
}

// ── Notification denied banner ────────────────────────────────────────────────

class _NotifDeniedBanner extends StatelessWidget {
  const _NotifDeniedBanner();

  void _showGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.notifications_active_rounded, color: Color(0xFFE65100), size: 22),
          SizedBox(width: 10),
          Text('Bật thông báo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Làm theo 4 bước sau:', style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
            SizedBox(height: 12),
            _GuideStep(number: '1', text: 'Bấm "Mở cài đặt" bên dưới'),
            SizedBox(height: 8),
            _GuideStep(number: '2', text: 'Chọn ứng dụng Flash Driver'),
            SizedBox(height: 8),
            _GuideStep(number: '3', text: 'Chọn Thông báo'),
            SizedBox(height: 8),
            _GuideStep(number: '4', text: 'Bật "Cho phép thông báo"'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Để sau', style: TextStyle(color: Color(0xFF9E9E9E))),
          ),
          FilledButton(
            onPressed: () { Navigator.pop(context); openAppSettings(); },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
            child: const Text('Mở cài đặt'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AlertCard(
      color: const Color(0xFFE65100),
      icon: Icons.notifications_off_rounded,
      title: 'Thông báo bị tắt',
      subtitle: 'Bạn sẽ không nhận được đơn mới',
      buttonLabel: 'Bật thông báo',
      onTap: () => _showGuideDialog(context),
    );
  }
}

// ── Shared alert card ─────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;

  const _AlertCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.2)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.2)),
          ]),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              buttonLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final String number;
  final String text;
  const _GuideStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Color(0xFFE65100),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(number,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4)),
        ),
      ),
    ]);
  }
}

// ── Shared helper ─────────────────────────────────────────────────────────────

Widget _surfaceCard({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) {
  return Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      boxShadow: AppColors.cardShadow,
    ),
    child: child,
  );
}
