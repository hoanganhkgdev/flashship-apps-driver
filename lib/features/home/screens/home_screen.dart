import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/offer_listener_service.dart';
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
import '../providers/support_provider.dart';

final homeTabProvider = StateProvider<int>((ref) => 0);

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => NotificationService.init(ref));
    Future.microtask(() {
      ref.read(activeOrderProvider.notifier).fetch();
      ref.read(walletProvider.notifier).fetch();
      _fetchServiceLabels();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(authProvider.notifier).refreshUser();
      ref.read(activeOrderProvider.notifier).fetch();
      ref.read(walletProvider.notifier).fetch();
    }
  }

  Future<void> _fetchServiceLabels() => Fmt.ensureLabelsLoaded();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

class _DashboardPageState extends ConsumerState<_DashboardPage> {
  bool _togglingOnline   = false;
  Map<String, dynamic> _stats = {};
  int _todayEarnings     = 0;
  int _yesterdayEarnings = 0;
  int _codPending        = 0;
  int _debtCount         = 0;
  Timer? _onlineTimer;

  @override
  void initState() {
    super.initState();
    _loadAll();
    Future.microtask(() {
      _syncOnlineTimer();
      final uid = ref.read(authProvider).user?.id;
      if (uid != null) ref.read(scoreProvider.notifier).subscribeRTDB(uid);
    });
  }

  void _syncOnlineTimer() {
    final driver = ref.read(authProvider).user;
    if (driver?.isOnline != true) return;
    OfferListenerService.instance.start(driver!.id);
    OfferListenerService.instance.onOfferDismissed =
        () => ref.read(homeTabProvider.notifier).state = 0;
    _startLocationUpdates();
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

  String get _onlineTimeStr {
    final driver = ref.read(authProvider).user;
    if (driver == null) return '';

    // Giây tích lũy từ các session trước trong ngày
    final accumulated = driver.dailyOnlineSeconds;

    // Giây của session hiện tại (chỉ khi đang online)
    final currentSession = (driver.isOnline && driver.onlineSince != null)
        ? DateTime.now().difference(driver.onlineSince!).inSeconds.clamp(0, 86400)
        : 0;

    final total = (accumulated + currentSession).clamp(0, 86400);
    if (total == 0 && !driver.isOnline) return '';

    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) return '${h}g ${m.toString().padLeft(2, '0')}p';
    if (m > 0) return '${m}p ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  @override
  void dispose() {
    _onlineTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() => Future.wait([
        _loadStats(),
        _loadEarnings(),
        _loadCodPending(),
        Future.microtask(() => ref.read(scoreProvider.notifier).fetch()),
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

  Future<void> _loadCodPending() async {
    try {
      final res    = await ref.read(apiClientProvider).get('/debts/');
      final list   = (res.data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final unpaid = list.where((d) => d['status'] != 'paid').toList();
      final total  = unpaid.fold<int>(0, (s, d) => s + num.parse((d['amount_due'] ?? 0).toString()).toInt());
      if (mounted) setState(() { _codPending = total; _debtCount = unpaid.length; });
    } catch (_) {}
  }

  Future<bool> _ensureLocationPermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) return true;
    if (!mounted) return false;
    if (perm == LocationPermission.deniedForever) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cần quyền vị trí', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          content: const Text('Ứng dụng cần quyền truy cập vị trí để hoạt động khi bạn online.\n\nVào Cài đặt → Ứng dụng → FlashShip → Quyền → Vị trí để cấp quyền.', style: TextStyle(fontSize: 14, height: 1.5)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bỏ qua')),
            FilledButton(onPressed: () async { Navigator.pop(context); await Geolocator.openAppSettings(); }, child: const Text('Mở cài đặt')),
          ],
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cần quyền vị trí để bật online')));
    }
    return false;
  }

  Future<void> _toggleOnline() async {
    final currentlyOnline = ref.read(authProvider).user?.isOnline ?? false;
    if (!currentlyOnline) {
      setState(() => _togglingOnline = true);
      final granted = await _ensureLocationPermission();
      if (!granted) {
        if (mounted) setState(() => _togglingOnline = false);
        return;
      }
    }
    setState(() => _togglingOnline = true);
    try {
      final res              = await ref.read(apiClientProvider).post('/driver/toggle-status');
      final raw              = res.data['is_online'];
      final isOnline         = raw == true || raw == 1;
      final onlineSince      = res.data['online_since'] != null
          ? DateTime.tryParse(res.data['online_since'] as String) : null;
      final dailyOnlineSecs  = (res.data['daily_online_seconds'] as num?)?.toInt();
      await ref.read(authProvider.notifier).updateOnlineStatus(
        isOnline,
        onlineSince: onlineSince,
        dailyOnlineSeconds: dailyOnlineSecs,
      );
      if (isOnline) {
        _startOnlineTimer();
        _startLocationUpdates();
        final uid = ref.read(authProvider).user?.id;
        if (uid != null) OfferListenerService.instance.start(uid);
      } else {
        _stopOnlineTimer();
        LocationService.instance.stop();
        OfferListenerService.instance.stop();
        final uid = ref.read(authProvider).user?.id;
        if (uid != null) {
          FirebaseDatabase.instance.ref('flashship_main/locations/driver_$uid').remove().ignore();
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.response?.data?['message'] as String? ?? 'Không thể đổi trạng thái'),
          backgroundColor: AppColors.danger,
        ));
      }
    } catch (_) {}
    if (mounted) setState(() => _togglingOnline = false);
  }

  Future<void> _startLocationUpdates() async {
    final driverId  = ref.read(authProvider).user?.id;
    final apiClient = ref.read(apiClientProvider);
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.best));
      await _pushLocation(driverId, pos.latitude, pos.longitude, apiClient);
    } catch (_) {}
    LocationService.instance.start((lat, lng) => _pushLocation(driverId, lat, lng, apiClient));
  }

  Future<void> _pushLocation(int? driverId, double lat, double lng, dynamic apiClient) async {
    if (driverId != null) {
      try {
        await FirebaseDatabase.instance.ref('flashship_main/locations/driver_$driverId')
            .set({'lat': lat, 'lng': lng, 'updated_at': ServerValue.timestamp});
      } catch (_) {}
    }
    try { await apiClient.post('/driver/update-location', data: {'latitude': lat, 'longitude': lng}); }
    catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user       = ref.watch(authProvider).user;
    final wallet     = ref.watch(walletProvider);
    final scoreState = ref.watch(scoreProvider);
    final isOnline   = user?.isOnline ?? false;

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
                onlineTimeStr: _onlineTimeStr,
                onToggle:      _toggleOnline,
              ),

              // ── Content cards ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // Earnings
                    _EarningsCard(
                      todayEarnings:     _todayEarnings,
                      yesterdayEarnings: _yesterdayEarnings,
                      todayOrders:       todayOrders,
                      onlineTimeStr:     _onlineTimeStr,
                      rating:            rating,
                      ratingCount:       ratingCount,
                      onTap:             widget.onGoToWallet,
                    ),

                    const SizedBox(height: 12),

                    // Score
                    _ScoreCard(
                      score:   scoreState.score,
                      loading: scoreState.loading,
                      onTap:   () => context.push('/score'),
                    ),

                    const SizedBox(height: 12),

                    // Finance
                    _FinanceCard(
                      balance:     wallet.balance,
                      codPending:  _codPending,
                      debtCount:   _debtCount,
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
  final String onlineTimeStr;
  final VoidCallback onToggle;

  const _GradientHeader({
    required this.user,
    required this.isOnline,
    required this.toggling,
    required this.onlineTimeStr,
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
                  onTap: toggling ? null : onToggle,
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
                            color: isOnline ? AppColors.success : const Color(0xFFDDDDDD),
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
                            isOnline ? 'Đang nhận đơn' : 'Bật để nhận đơn',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isOnline ? AppColors.success : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isOnline && onlineTimeStr.isNotEmpty
                                ? 'Đã online $onlineTimeStr'
                                : isOnline ? 'Đang hoạt động' : 'Nhấn để bắt đầu',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ]),
                      ),

                      // Time badge (online only)
                      if (isOnline && onlineTimeStr.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.successSoft,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            onlineTimeStr,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
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
  final String onlineTimeStr;
  final double rating;
  final int ratingCount;
  final VoidCallback onTap;

  const _EarningsCard({
    required this.todayEarnings,
    required this.yesterdayEarnings,
    required this.todayOrders,
    required this.onlineTimeStr,
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
              onlineTimeStr.isNotEmpty ? onlineTimeStr : '—',
              'Online',
              Icons.access_time_rounded,
            ),
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
  final bool loading;
  final VoidCallback onTap;
  const _ScoreCard({required this.score, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _surfaceCard(
        child: loading || score == null
            ? const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2)))
            : _content(score!),
      ),
    );
  }

  Widget _content(DriverScoreModel s) {
    final progress = s.maxScore > 0 ? s.score / s.maxScore : 0.0;

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
    final uri = item.uri;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể mở liên kết này')),
        );
      }
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
