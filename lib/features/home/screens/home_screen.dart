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
import '../../wallet/screens/wallet_screen.dart';
import '../../wallet/screens/debt_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../score/models/score_model.dart';
import '../../score/providers/score_provider.dart';
import '../providers/support_provider.dart';

// Provider để control tab từ bên ngoài (offer screen, etc.)
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
    final tab = ref.watch(homeTabProvider);
    final pages = <Widget>[
      _DashboardPage(onGoToWallet: () => ref.read(homeTabProvider.notifier).state = 2),
      const HistoryScreen(),
      const WalletScreen(),
      const ProfileScreen(),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F4F7),
        body: IndexedStack(index: tab, children: pages),
        bottomNavigationBar: _BottomNav(
          currentIndex: tab,
          onTap: (i) => ref.read(homeTabProvider.notifier).state = i,
        ),
      ),
    );
  }
}

// ── Flat bottom nav ───────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  static const _items = [
    (icon: Icons.home_outlined,                   activeIcon: Icons.home_rounded,                      label: 'Trang chủ'),
    (icon: Icons.receipt_long_outlined,           activeIcon: Icons.receipt_long_rounded,              label: 'Đơn hàng'),
    (icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded,    label: 'Ví tiền'),
    (icon: Icons.person_outline_rounded,          activeIcon: Icons.person_rounded,                    label: 'Tài khoản'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
      ),
      padding: EdgeInsets.only(bottom: bottom),
      child: Row(
        children: List.generate(_items.length, (i) {
          final item     = _items[i];
          final selected = i == currentIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected ? item.activeIcon : item.icon,
                      size: 24,
                      color: selected ? AppColors.primary : const Color(0xFF9CA3AF),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? AppColors.primary : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
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
    // Dùng microtask để đảm bảo authProvider đã restore xong từ SharedPreferences
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
    // Reset tab về Trang chủ khi offer hết hạn/bị dismiss
    OfferListenerService.instance.onOfferDismissed =
        () => ref.read(homeTabProvider.notifier).state = 0;
    _startLocationUpdates();
    _startOnlineTimer();
  }

  void _startOnlineTimer() {
    _onlineTimer?.cancel();
    // Tick mỗi giây chỉ để refresh UI — thời gian tính từ onlineSince
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
    if (driver?.isOnline != true || driver?.onlineSince == null) return '0s';
    // Tính trực tiếp từ onlineSince — chính xác kể cả khi app ở background
    final seconds = DateTime.now().difference(driver!.onlineSince!).inSeconds.clamp(0, 999999);
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
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
      if (mounted) { setState(() => _stats = data); }
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
    if (!mounted) { return false; }
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
        if (mounted) { setState(() => _togglingOnline = false); }
        return;
      }
    }
    setState(() => _togglingOnline = true);
    try {
      final res        = await ref.read(apiClientProvider).post('/driver/toggle-status');
      final raw        = res.data['is_online'];
      final isOnline   = raw == true || raw == 1;
      final onlineSince = res.data['online_since'] != null
          ? DateTime.tryParse(res.data['online_since'] as String) : null;
      await ref.read(authProvider.notifier).updateOnlineStatus(isOnline, onlineSince: onlineSince);
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
    if (mounted) { setState(() => _togglingOnline = false); }
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
    final user         = ref.watch(authProvider).user;
    final wallet       = ref.watch(walletProvider);
    final scoreState = ref.watch(scoreProvider);
    final isOnline   = user?.isOnline ?? false;

    final todayOrders = ((_stats['today_orders'] as num?) ?? 0).toInt();
    final rating      = (_stats['rating']        as num?)?.toDouble() ?? 0.0;
    final ratingCount = ((_stats['rating_count'] as num?) ?? 0).toInt();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadAll,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [

          // ── Header ───────────────────────────────────────────────────
          _HeroHeader(
            user:     user,
            isOnline: isOnline,
            toggling: _togglingOnline,
            onToggle: _toggleOnline,
          ),

          const SizedBox(height: 8),

          // ── Toggle online ─────────────────────────────────────────────
          _ToggleCard(
              isOnline: isOnline,
              toggling: _togglingOnline,
              onToggle: _toggleOnline,
              onlineTimeStr: _onlineTimeStr),

          const SizedBox(height: 8),

          // Active orders hiển thị ở tab Đơn hàng, không hiện ở home

          // ── Earnings + Stats ─────────────────────────────────────────
          _EarningsSection(
            todayEarnings:     _todayEarnings,
            yesterdayEarnings: _yesterdayEarnings,
            todayOrders:       todayOrders,
            onlineTimeStr:     _onlineTimeStr,
            rating:            rating,
            ratingCount:       ratingCount,
            onTap:             () => widget.onGoToWallet(),
          ),

          const SizedBox(height: 8),

          // ── Score ─────────────────────────────────────────────────────
          _ScoreCard(
            score:   scoreState.score,
            loading: scoreState.loading,
            onTap:   () => context.push('/score'),
          ),

          const SizedBox(height: 8),

          // ── Ví & Công nợ ──────────────────────────────────────────────
          _FinanceSection(
            balance:     wallet.balance,
            codPending:  _codPending,
            debtCount:   _debtCount,
            onWalletTap: widget.onGoToWallet,
            onDebtTap:   () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DebtScreen())),
          ),

          const SizedBox(height: 8),

          // ── Hỗ trợ ────────────────────────────────────────────────────
          const _QuickSection(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero header — matching history screen style
// ─────────────────────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final dynamic user;
  final bool isOnline;
  final bool toggling;
  final VoidCallback onToggle;

  const _HeroHeader({
    required this.user,
    required this.isOnline,
    required this.toggling,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16, top + 16, 16, 16),
      child: Row(children: [
        // Avatar
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: user?.profilePhotoUrl != null
              ? Image.network(user!.profilePhotoUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(user.initials ?? 'D',
                        style: const TextStyle(color: AppColors.primary,
                            fontSize: 16, fontWeight: FontWeight.w800))))
              : Center(
                  child: Text(user?.initials ?? 'D',
                      style: const TextStyle(color: AppColors.primary,
                          fontSize: 16, fontWeight: FontWeight.w800))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Xin chào',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text(user?.name ?? 'Tài xế',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary, letterSpacing: -0.3),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        // Online status dot
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: isOnline ? AppColors.success : AppColors.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(isOnline ? 'Online' : 'Offline',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isOnline ? AppColors.success : AppColors.textSecondary)),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Online toggle
// ─────────────────────────────────────────────────────────────────────────────

class _ToggleCard extends StatelessWidget {
  final bool isOnline;
  final bool toggling;
  final String onlineTimeStr;
  final VoidCallback onToggle;

  const _ToggleCard({
    required this.isOnline,
    required this.toggling,
    required this.onlineTimeStr,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: toggling ? null : onToggle,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(children: [
          // Toggle switch
          if (toggling)
            const SizedBox(
              width: 52, height: 30,
              child: Center(child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5,
                      color: AppColors.primary))))
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
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                isOnline ? 'Đang nhận đơn' : 'Bật để nhận đơn',
                style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: isOnline ? AppColors.success : AppColors.textPrimary,
                ),
              ),
              Text(
                isOnline ? 'Online ${onlineTimeStr.isNotEmpty ? "· $onlineTimeStr" : ""}' : 'Nhấn để bắt đầu',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Earnings + Stats section
// ─────────────────────────────────────────────────────────────────────────────

class _EarningsSection extends StatelessWidget {
  final int todayEarnings;
  final int yesterdayEarnings;
  final int todayOrders;
  final String onlineTimeStr;
  final double rating;
  final int ratingCount;
  final VoidCallback onTap;

  const _EarningsSection({
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
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Thu nhập hôm nay',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: Text(
                Fmt.currency(todayEarnings),
                style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800,
                  color: AppColors.primary, letterSpacing: -0.5,
                ),
              ),
            ),
            if (yesterdayEarnings > 0)
              Text('Hôm qua ${Fmt.currency(yesterdayEarnings)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
          ]),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Stats row
          Row(children: [
            _MiniStat(label: 'Đơn hôm nay', value: '$todayOrders'),
            _vDivider(),
            _MiniStat(
              label: 'Online',
              value: onlineTimeStr.isNotEmpty ? onlineTimeStr : '—',
            ),
            _vDivider(),
            _MiniStat(
              label: 'Đánh giá',
              value: rating > 0 ? rating.toStringAsFixed(1) : '—',
              sub: ratingCount > 0 ? '$ratingCount lượt' : null,
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _vDivider() => Container(
      width: 1, height: 32, margin: const EdgeInsets.symmetric(horizontal: 12),
      color: AppColors.divider);
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  const _MiniStat({required this.label, required this.value, this.sub});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          if (sub != null)
            Text(sub!,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Score card
// ─────────────────────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final DriverScoreModel? score;
  final bool loading;
  final VoidCallback onTap;
  const _ScoreCard({required this.score, required this.loading, required this.onTap});

  Color _colorFor(int s) {
    if (s >= 80) return AppColors.success;
    if (s >= 60) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: loading || score == null
            ? const SizedBox(
                height: 40,
                child: Center(child: LinearProgressIndicator(
                    color: AppColors.primary)))
            : _content(score!),
      ),
    );
  }

  Widget _content(DriverScoreModel s) {
    final color    = _colorFor(s.score);
    final progress = s.maxScore > 0 ? s.score / s.maxScore : 0.0;
    return Row(children: [
      SizedBox(
        width: 48, height: 48,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress, strokeWidth: 4,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text('${s.score}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
        ]),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Điểm tích lũy',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4)),
              child: Text(s.label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
            ),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress, minHeight: 4,
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ]),
      ),
      const SizedBox(width: 8),
      const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textSecondary),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Finance section (ví + công nợ)
// ─────────────────────────────────────────────────────────────────────────────

class _FinanceSection extends StatelessWidget {
  final int balance;
  final int codPending;
  final int debtCount;
  final VoidCallback onWalletTap;
  final VoidCallback onDebtTap;

  const _FinanceSection({
    required this.balance,
    required this.codPending,
    required this.debtCount,
    required this.onWalletTap,
    required this.onDebtTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Tài chính',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
          ),
        ),
        const Divider(height: 1),
        _FinanceTile(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Ví cá nhân',
          value: Fmt.currency(balance),
          color: AppColors.success,
          onTap: onWalletTap,
        ),
        const Divider(height: 1, indent: 56),
        _FinanceTile(
          icon: Icons.receipt_long_rounded,
          label: 'Công nợ',
          value: Fmt.currency(codPending),
          color: debtCount > 0 ? AppColors.danger : AppColors.textSecondary,
          badge: debtCount > 0 ? debtCount : null,
          onTap: onDebtTap,
        ),
      ]),
    );
  }
}

class _FinanceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final int? badge;
  final VoidCallback onTap;

  const _FinanceTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                child: Text('$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
            ],
            Text(value,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textSecondary),
          ]),
        ),
      );
}


// ─────────────────────────────────────────────────────────────────────────────
// Quick actions section (dynamic from API)
// ─────────────────────────────────────────────────────────────────────────────

class _QuickSection extends ConsumerWidget {
  const _QuickSection();

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

  void _showRules(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RulesSheet(),
    );
  }

  IconData _iconFor(String type) => switch (type) {
    'phone' => Icons.phone_rounded,
    'zalo'  => Icons.chat_rounded,
    'email' => Icons.email_rounded,
    _       => Icons.open_in_new_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(supportProvider).valueOrNull ?? [];

    return Container(
      color: Colors.white,
      child: Column(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Hỗ trợ',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
          ),
        ),
        const Divider(height: 1),
        ...items.asMap().entries.map((e) {
          final i    = e.key;
          final item = e.value;
          return Column(children: [
            _QuickBtn(
              icon:     _iconFor(item.type),
              label:    item.title,
              subtitle: item.subtitle ?? '',
              color:    item.displayColor,
              onTap:    () => _launch(context, item),
            ),
            if (i < items.length - 1)
              const Divider(height: 1, indent: 56),
          ]);
        }),
        if (items.isNotEmpty) const Divider(height: 1, indent: 56),
        _QuickBtn(
          icon:     Icons.menu_book_rounded,
          label:    'Nội quy tài xế',
          subtitle: 'Quy định & hướng dẫn',
          color:    AppColors.info,
          onTap:    () => _showRules(context),
        ),
      ]),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickBtn({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
            Text(subtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textSecondary),
        ]),
      ),
    );
  }

}

// ── Rules bottom sheet ──────────────────────────────────────────────────────

class _RulesSheet extends StatelessWidget {
  const _RulesSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(children: [
                const Expanded(
                  child: Text('Nội quy tài xế',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: const [
                  _RuleItem(num: '1', title: 'Thái độ phục vụ',
                      body: 'Luôn lịch sự, tôn trọng khách hàng. Không từ chối đơn hàng khi đã nhận mà không có lý do chính đáng.'),
                  SizedBox(height: 12),
                  _RuleItem(num: '2', title: 'Đúng giờ',
                      body: 'Nhận đơn phải đến lấy hàng đúng thời gian cam kết. Chậm trễ quá 10 phút cần thông báo cho hệ thống và khách hàng.'),
                  SizedBox(height: 12),
                  _RuleItem(num: '3', title: 'Bảo quản hàng hóa',
                      body: 'Vận chuyển hàng hóa cẩn thận, không để hàng bị hỏng, đổ vỡ. Chịu trách nhiệm đền bù nếu do lỗi của tài xế.'),
                  SizedBox(height: 12),
                  _RuleItem(num: '4', title: 'Trung thực',
                      body: 'Không gian lận, không tự ý hủy đơn giả mạo. Mọi vi phạm sẽ bị khóa tài khoản vĩnh viễn.'),
                  SizedBox(height: 12),
                  _RuleItem(num: '5', title: 'An toàn giao thông',
                      body: 'Tuân thủ luật giao thông, không phóng nhanh vượt ẩu. Bắt buộc đội mũ bảo hiểm khi tham gia giao thông.'),
                  SizedBox(height: 12),
                  _RuleItem(num: '6', title: 'Thanh toán COD',
                      body: 'Chuyển đầy đủ tiền COD về công ty theo đúng quy định. Nợ quá hạn sẽ bị tạm dừng tài khoản.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final String num;
  final String title;
  final String body;

  const _RuleItem({required this.num, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(num,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(body, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.5)),
        ]),
      ),
    ]);
  }
}
