import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/location_push_service.dart';
import '../../../core/services/offer_listener_service.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/home_providers.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/dashboard_banners.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/earnings_card.dart';
import '../widgets/finance_card.dart';
import '../widgets/score_card.dart';
import '../widgets/shift_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/order_provider.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../wallet/screens/debt_screen.dart';
import '../../profile/screens/kyc_screen.dart';
import '../../score/providers/score_provider.dart';
import '../../shifts/providers/shift_provider.dart';
import '../../shifts/screens/shift_registration_screen.dart';

class DashboardPage extends ConsumerStatefulWidget {
  final VoidCallback onGoToWallet;
  const DashboardPage({super.key, required this.onGoToWallet});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with WidgetsBindingObserver {
  bool _togglingOnline = false;
  Map<String, dynamic> _stats = {};
  int _todayEarnings = 0;
  int _yesterdayEarnings = 0;
  // 7 giá trị của tuần này (Thứ Hai → Chủ Nhật), lấy trực tiếp từ
  // earnings/weekly — thu nhập đơn hàng thật theo ngày, không còn xấp xỉ từ
  // giao dịch ví.
  List<int> _last7Days = const [];
  // Tăng mỗi lần backend tự đổi is_online mà KHÔNG qua yêu cầu của chính app
  // (chỉ _handleForceOffline — RTDB báo GPS chết). Lệnh gọi /driver/toggle-
  // status với ý định tắt online chụp lại giá trị này lúc bắt đầu; nếu lệch
  // đi sau khi có phản hồi, biết mình vừa trúng race: is_online phía backend
  // đã đổi âm thầm ngay trước lúc request tới, khiến "toggle" bị đảo ngược
  // thành online — ngược hẳn ý định ban đầu.
  int _externalOfflineEpoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAll();
    // Gán 1 lần, không điều kiện — 2 service này không tự đụng vào field
    // callback trong start()/stop(), nên nếu chỉ gán lúc đang online tại thời
    // điểm mount thì tài xế bật online sau đó (qua nút) sẽ không có callback
    // nào được wire, khiến force-offline từ backend không cập nhật được UI.
    OfferListenerService.instance.onOfferDismissed =
        () => ref.read(homeTabProvider.notifier).state = 0;
    LocationPushService.instance.onForceOffline = _handleForceOffline;
    Future.microtask(() {
      _syncOnlineServices();
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

  void _syncOnlineServices() {
    final driver = ref.read(authProvider).user;
    if (driver?.isOnline != true) return;
    OfferListenerService.instance.start(driver!.id);
    LocationPushService.instance.start(driver.id);
  }

  /// Backend tự chuyển tài xế offline (GPS chết quá 10 phút) — RTDB bắn
  /// is_online=false → LocationPushService nhận, gọi callback này.
  /// Dừng mọi thứ và cập nhật UI giống hệt tắt online bình thường.
  void _handleForceOffline() {
    debugPrint('[HomeScreen] Nhận force-offline từ backend → dừng mọi thứ');
    _externalOfflineEpoch++;
    OfferListenerService.instance.stop();
    // LocationPushService đã tự stop() trước khi gọi callback
    ref.read(authProvider.notifier).updateOnlineStatus(false);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Bạn đã bị tự động tắt online do mất tín hiệu GPS quá lâu. Bật lại GPS rồi bấm Online nhé!'),
        backgroundColor: Color(0xFFE65100),
        duration: Duration(seconds: 6),
      ));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    OfferListenerService.instance.onOfferDismissed = null;
    LocationPushService.instance.onForceOffline = null;
    super.dispose();
  }

  Future<void> _loadAll() => Future.wait([
        _loadStats(),
        _loadEarnings(),
        _loadWeeklyEarnings(),
        Future.microtask(() => ref.read(scoreProvider.notifier).fetch()),
        Future.microtask(() => ref.read(shiftProvider.notifier).fetch()),
      ]);

  Future<void> _loadStats() async {
    try {
      final res = await ref.read(apiClientProvider).get('/orders/dashboard');
      final data = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      if (mounted) setState(() => _stats = data);
    } catch (_) {}
  }

  Future<void> _loadEarnings() async {
    try {
      final res = await ref.read(apiClientProvider).get('/earnings/summary');
      final data = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _todayEarnings = (data['today']?['total'] as num?)?.toInt() ?? 0;
          _yesterdayEarnings =
              (data['yesterday']?['total'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadWeeklyEarnings() async {
    try {
      final res = await ref.read(apiClientProvider).get('/earnings/weekly');
      final list = (res.data['data'] ?? res.data) as List? ?? [];
      final byDate = <String, int>{
        for (final e in list)
          (e as Map<String, dynamic>)['date'] as String:
              ((e['total'] as num?) ?? 0).round(),
      };
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final monday = today.subtract(Duration(days: today.weekday - 1));
      final values = List.generate(7, (i) {
        final day = monday.add(Duration(days: i));
        final key = '${day.year.toString().padLeft(4, '0')}-'
            '${day.month.toString().padLeft(2, '0')}-'
            '${day.day.toString().padLeft(2, '0')}';
        return byDate[key] ?? 0;
      });
      if (mounted) setState(() => _last7Days = values);
    } catch (_) {}
  }

  Future<bool> _ensureLocationPermission() async {
    // GPS service phải bật — nếu không tài xế online nhưng không push được
    // vị trí → ghost driver (dispatch không thấy toạ độ). Không hiện snackbar
    // ở đây nữa — banner "GPS đang tắt" trên dashboard (locationIssueProvider)
    // đã tự phản ánh đúng trạng thái này rồi (kèm nút "Bật GPS").
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    // Chưa từng hỏi hoặc mới bị từ chối 1 lần (chưa khoá hẳn) → gọi thẳng
    // requestPermission() để HỆ ĐIỀU HÀNH tự hiện dialog gốc "Cho phép khi
    // dùng ứng dụng / Luôn luôn / Không cho phép" — không cần popup tự vẽ.
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse) {
      // Vừa cấp quyền xong ngay tại đây — banner "Chưa cấp quyền vị trí" trên
      // dashboard (locationIssueProvider) chỉ tự làm mới lúc app resume hoặc
      // GPS service đổi trạng thái, KHÔNG có sự kiện nào bắn khi permission
      // vừa được cấp qua chính dialog này → tự xoá ngay để banner không bị
      // đứng lại dù đã cấp quyền và đang online bình thường.
      if (mounted) ref.read(locationIssueProvider.notifier).state = null;
      return true;
    }
    if (!mounted) return false;
    // Bị từ chối vĩnh viễn (deniedForever) → dialog gốc không hiện lại được
    // nữa, bắt buộc phải qua Cài đặt nên mới cần popup hướng dẫn riêng.
    // Còn lại (denied thường, vừa bị từ chối ở request phía trên) không hiện
    // gì thêm ở đây — banner "Chưa cấp quyền vị trí" trên dashboard
    // (locationIssueProvider) đã tự phản ánh đúng trạng thái này rồi.
    if (perm == LocationPermission.deniedForever) {
      await showLocationPermissionGuide(context);
    }
    return false;
  }

  /// Bắt buộc CCCD đã được duyệt mới cho bật online. `cccdStatus` cục bộ có
  /// thể chưa từng được nạp (response /auth/login, /auth/verify-otp-register
  /// không có field này) hoặc đã cũ — làm mới 1 lần qua /driver/profile
  /// trước khi kết luận, tránh chặn nhầm tài xế đã thực sự được duyệt.
  Future<bool> _ensureCccdApproved() async {
    var status = ref.read(authProvider).user?.cccdStatus;
    if (status != 'approved') {
      await ref.read(authProvider.notifier).refreshUser();
      if (!mounted) return false;
      status = ref.read(authProvider).user?.cccdStatus;
    }
    if (status == 'approved') return true;
    if (mounted) {
      final goToKyc = await showCccdRequiredDialog(context);
      if (goToKyc == true && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const KycScreen()),
        );
      }
    }
    return false;
  }

  /// Bắt buộc đã đăng ký ca làm việc mới cho bật online.
  Future<bool> _ensureHasShift() async {
    if (!ref.read(shiftProvider).isRegistered) {
      await ref.read(shiftProvider.notifier).fetch();
      if (!mounted) return false;
    }
    if (ref.read(shiftProvider).isRegistered) return true;
    if (mounted) {
      final goToShift = await showNoShiftRequiredDialog(context);
      if (goToShift == true && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ShiftRegistrationScreen()),
        );
      }
    }
    return false;
  }

  /// Gọi /driver/toggle-status với Ý ĐỊNH tắt online, tự phát hiện và sửa nếu
  /// trúng race với _handleForceOffline() (RTDB báo GPS chết) đúng lúc request
  /// đang bay — lúc đó backend đã tự set is_online=false NGAY TRƯỚC khi
  /// request này tới, "toggle" liền đảo ngược lại thành true, ngược hẳn ý
  /// định tắt online. Gọi lại 1 lần nữa để đưa về đúng trạng thái mong muốn.
  Future<(bool, DateTime?)> _postToggleOffline() async {
    final epochAtStart = _externalOfflineEpoch;
    var res = await ref.read(apiClientProvider).post('/driver/toggle-status');
    var isOnline = res.data['is_online'] == true || res.data['is_online'] == 1;
    var onlineSince = res.data['online_since'] != null
        ? DateTime.tryParse(res.data['online_since'] as String)
        : null;
    if (isOnline && _externalOfflineEpoch != epochAtStart) {
      debugPrint(
          '[HomeScreen] toggle-status trúng race với force-offline (GPS chết) → gọi lại để đưa về đúng ý định tắt online');
      res = await ref.read(apiClientProvider).post('/driver/toggle-status');
      isOnline = res.data['is_online'] == true || res.data['is_online'] == 1;
      onlineSince = res.data['online_since'] != null
          ? DateTime.tryParse(res.data['online_since'] as String)
          : null;
    }
    return (isOnline, onlineSince);
  }

  Future<void> _forceOffline() async {
    final isOnline = ref.read(authProvider).user?.isOnline ?? false;
    if (!isOnline || _togglingOnline) return;
    if (mounted) setState(() => _togglingOnline = true);
    // Dừng gửi vị trí NGAY trước khi gọi API — cùng lý do với _toggleOnline():
    // chờ tới lúc có phản hồi mới dừng thì stream vẫn kịp bắn 1 lần trong lúc
    // chờ mạng, ghi đè lên ngay sau lệnh xoá Firebase.
    LocationPushService.instance.stop();
    OfferListenerService.instance.stop();
    try {
      final (nowOnline, onlineSince) = await _postToggleOffline();
      await ref.read(authProvider.notifier).updateOnlineStatus(
            nowOnline,
            onlineSince: onlineSince,
          );
      final uid = ref.read(authProvider).user?.id;
      if (uid != null) {
        FirebaseDatabase.instance
            .ref('locations/driver_$uid')
            .remove()
            .ignore();
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
      // Thứ tự chặn: CCCD → vị trí (GPS + quyền) → ca làm việc.
      setState(() => _togglingOnline = true);
      final cccdOk = await _ensureCccdApproved();
      if (!cccdOk) {
        if (mounted) setState(() => _togglingOnline = false);
        return;
      }
      final granted = await _ensureLocationPermission();
      if (!granted) {
        if (mounted) setState(() => _togglingOnline = false);
        return;
      }
      final hasShift = await _ensureHasShift();
      if (!hasShift) {
        if (mounted) setState(() => _togglingOnline = false);
        return;
      }
    } else {
      // Dừng gửi vị trí NGAY (trước khi gọi API) — nếu chờ tới lúc có phản
      // hồi mới dừng, stream vẫn kịp bắn 1 lần trong lúc chờ mạng, rồi ghi
      // đè lên đúng lúc lệnh xoá Firebase vừa chạy xong (thứ tự 2 request
      // mạng không đảm bảo) — marker "chớp lại" thay vì biến mất hẳn.
      LocationPushService.instance.stop();
      OfferListenerService.instance.stop();
    }
    setState(() => _togglingOnline = true);
    try {
      bool isOnline;
      DateTime? onlineSince;
      if (currentlyOnline) {
        // Ý định tắt online — dùng bản tự phát hiện/sửa race với
        // _handleForceOffline() (xem doc của _postToggleOffline()).
        (isOnline, onlineSince) = await _postToggleOffline();
      } else {
        final res =
            await ref.read(apiClientProvider).post('/driver/toggle-status');
        isOnline = res.data['is_online'] == true || res.data['is_online'] == 1;
        onlineSince = res.data['online_since'] != null
            ? DateTime.tryParse(res.data['online_since'] as String)
            : null;
      }
      await ref.read(authProvider.notifier).updateOnlineStatus(
            isOnline,
            onlineSince: onlineSince,
          );
      if (isOnline) {
        final uid = ref.read(authProvider).user?.id;
        if (uid != null) {
          LocationPushService.instance.start(uid);
          OfferListenerService.instance.start(uid);
        }
      } else {
        // Đã dừng LocationPushService ở trên (trước khi gọi API) rồi — ở
        // đây chỉ còn dọn Firebase.
        final uid = ref.read(authProvider).user?.id;
        if (uid != null) {
          FirebaseDatabase.instance
              .ref('locations/driver_$uid')
              .remove()
              .ignore();
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        // Body có thể không phải Map (HTML 500, string...) → cast an toàn
        final data = e.response?.data;
        final code = data is Map ? data['code'] as String? : null;
        if (code == 'debt_overdue') {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text(
                'Bạn có công nợ quá hạn. Vui lòng thanh toán trước khi hoạt động.'),
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
    // Scaffold dùng extendBody: true (cho hiệu ứng kính mờ ở BottomNav) nên
    // nội dung cuộn tới đâu cũng phải tự chừa khoảng trống che bởi thanh
    // nav nổi — không còn được Scaffold tự trừ chiều cao body như trước.
    final navClearance = BottomNav.reservedHeight(context);
    final user = ref.watch(authProvider).user;
    final wallet = ref.watch(walletProvider);
    final scoreState = ref.watch(scoreProvider);
    final isOnline = user?.isOnline ?? false;
    final notifDenied = ref.watch(notifDeniedProvider);
    final locationIssue = ref.watch(locationIssueProvider);
    final shiftState = ref.watch(shiftProvider);

    ref.listen<WalletState>(walletProvider, (prev, next) {
      final hadOverdue = prev?.debts.any((d) => d.isOverdue) ?? false;
      final hasOverdue = next.debts.any((d) => d.isOverdue);
      if (!hadOverdue && hasOverdue) _forceOffline();
    });

    // GPS bị tắt hoặc quyền vị trí bị thu hồi giữa lúc đang online (tắt GPS
    // service bắt được ngay qua stream ở _HomeScreenState; thu hồi quyền chỉ
    // phát hiện được lúc app resume — cả 2 đều đổ về locationIssueProvider)
    // → tự tắt online ngay, không đợi backend phát hiện sau 10 phút, tránh
    // tài xế "treo online" bằng cách tắt định vị để né nhận đơn.
    ref.listen<String?>(locationIssueProvider, (prev, next) {
      if (prev == null && next != null) _forceOffline();
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
    final debtCount = wallet.debts.length;

    final todayOrders = ((_stats['today_orders'] as num?) ?? 0).toInt();
    final rating = (_stats['rating'] as num?)?.toDouble() ?? 0.0;
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
              DashboardHeader(
                user: user,
                isOnline: isOnline,
                toggling: _togglingOnline,
                locked: hasOverdueDebt,
                onToggle: _toggleOnline,
                shifts: shiftState.shifts,
                currentShiftIds: shiftState.currentShiftIds,
                onShiftTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ShiftRegistrationScreen())),
              ),

              // ── Location / GPS banner ─────────────────────────────────
              if (locationIssue != null)
                LocationIssueBanner(issue: locationIssue),

              // ── Notification permission banner ────────────────────────
              if (notifDenied) const NotifDeniedBanner(),

              // ── Overdue debt banner ───────────────────────────────────
              if (wallet.debts.any((d) => d.isOverdue))
                OverdueBanner(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DebtScreen()),
                  ),
                ),

              // ── Content cards ────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, navClearance),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Earnings
                    EarningsCard(
                      todayEarnings: _todayEarnings,
                      yesterdayEarnings: _yesterdayEarnings,
                      todayOrders: todayOrders,
                      rating: rating,
                      ratingCount: ratingCount,
                      onTap: widget.onGoToWallet,
                      last7Days: _last7Days,
                    ),

                    const SizedBox(height: 16),

                    // Score
                    DashboardScoreCard(
                      score: scoreState.score,
                      onTap: () => context.push('/score'),
                    ),

                    const SizedBox(height: 16),

                    // Finance
                    FinanceCard(
                      balance: wallet.balance,
                      codPending: codPending,
                      debtCount: debtCount,
                      onWalletTap: () => context.push('/wallet'),
                      onDebtTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const DebtScreen())),
                    ),

                    const SizedBox(height: 16),

                    // Shift
                    ShiftCard(
                      shifts: shiftState.shifts,
                      currentShiftIds: shiftState.currentShiftIds,
                      hasLoadedOnce: shiftState.hasLoadedOnce,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const ShiftRegistrationScreen())),
                    ),
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
