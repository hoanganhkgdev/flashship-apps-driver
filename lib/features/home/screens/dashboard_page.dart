import 'dart:async';
import 'dart:io';
import 'package:offer_overlay/offer_overlay.dart';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/location_push_service.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/home_providers.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/dashboard_banners.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/orders_tab_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/models/order_model.dart';
import '../../orders/providers/order_provider.dart';
import '../../order_market/providers/order_market_provider.dart';
import '../../order_market/widgets/new_orders_section.dart';
import '../../orders/widgets/completed_orders_sliver.dart';
import '../../orders/widgets/history_active_order_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../wallet/screens/debt_screen.dart';
import '../../profile/screens/kyc_screen.dart';
import '../../shifts/providers/shift_provider.dart';
import '../../shifts/screens/shift_registration_screen.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with WidgetsBindingObserver {
  static const _onlineToggleCooldown = Duration(seconds: 5);

  bool _togglingOnline = false;
  int _onlineToggleCooldownSeconds = 0;
  final _scroll = ScrollController();
  Timer? _forceOfflineRetryTimer;
  Timer? _onlineToggleCooldownTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _loadAll();
    Future.microtask(_syncOnlineServices);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Card thu nhập/số đơn/rating + COD không tự refresh trên resume như ví
    // → làm mới để tránh hiển thị số liệu cũ khi mở lại app.
    if (state == AppLifecycleState.resumed) _loadAll();
  }

  Future<void> _syncOnlineServices() async {
    final driver = ref.read(authProvider).user;
    if (driver?.isOnline != true) return;
    await LocationPushService.instance.start(driver!.id);
  }

  void _onScroll() {
    // Tab Hoàn thành tải thêm khi cuộn gần cuối danh sách.
    if (ref.read(homeOrdersTabProvider) == 2 &&
        _scroll.hasClients &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 150) {
      ref.read(orderHistoryProvider.notifier).fetch();
    }
  }

  void _selectOrdersTab(int i) {
    ref.read(homeOrdersTabProvider.notifier).state = i;
    if (i == 2) {
      ref.read(orderHistoryProvider.notifier).fetch(refresh: true);
    }
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _refreshCurrentTab() {
    switch (ref.read(homeOrdersTabProvider)) {
      case 1:
        return Future.wait([
          _loadAll(),
          ref.read(activeOrderProvider.notifier).fetch(),
        ]);
      case 2:
        return ref.read(orderHistoryProvider.notifier).fetch(refresh: true);
      default:
        return Future.wait([
          _loadAll(),
          ref.read(orderMarketProvider.notifier).fetch(),
        ]);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _forceOfflineRetryTimer?.cancel();
    _onlineToggleCooldownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startOnlineToggleCooldown() {
    _onlineToggleCooldownTimer?.cancel();
    if (mounted) {
      setState(() {
        _onlineToggleCooldownSeconds = _onlineToggleCooldown.inSeconds;
      });
    }
    _onlineToggleCooldownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _onlineToggleCooldownSeconds--;
          if (_onlineToggleCooldownSeconds <= 0) {
            _onlineToggleCooldownSeconds = 0;
            timer.cancel();
          }
        });
      },
    );
  }

  /// Ca đăng ký cần có sẵn để kiểm tra điều kiện Online.
  Future<void> _loadAll() =>
      Future.microtask(() => ref.read(shiftProvider.notifier).fetch());

  Future<bool> _ensureLocationPermission() async {
    // GPS service phải bật — nếu không tài xế online nhưng không push được
    // vị trí → ghost driver (dispatch không thấy toạ độ). Không hiện snackbar
    // ở đây nữa — banner "GPS đang tắt" trên dashboard (locationIssueProvider)
    // đã tự phản ánh đúng trạng thái này rồi (kèm nút "Bật GPS").
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    // Bước 1: xin quyền foreground. Từ Android 11, dialog hệ thống KHÔNG còn
    // lựa chọn "Luôn cho phép"; người dùng chỉ có thể cấp quyền đó trong
    // trang Cài đặt của ứng dụng sau khi đã cấp "Khi dùng ứng dụng".
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (Platform.isAndroid && perm == LocationPermission.whileInUse) {
      if (mounted) {
        ref.read(locationIssueProvider.notifier).state =
            'background_permission';
        await showLocationPermissionGuide(
          context,
          backgroundPermission: true,
        );
      }
      return false;
    }
    if (perm == LocationPermission.always ||
        (!Platform.isAndroid && perm == LocationPermission.whileInUse)) {
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

  Future<(bool, DateTime?)> _setOnlineStatus(bool desiredOnline) async {
    final res = await ref.read(apiClientProvider).post(
      '/driver/toggle-status',
      data: {'is_online': desiredOnline},
    );
    final isOnline =
        res.data['is_online'] == true || res.data['is_online'] == 1;
    final onlineSince = res.data['online_since'] != null
        ? DateTime.tryParse(res.data['online_since'] as String)
        : null;
    return (isOnline, onlineSince);
  }

  Future<void> _forceOffline({bool isRetry = false}) async {
    final isOnline = ref.read(authProvider).user?.isOnline ?? false;
    if (!isOnline || _togglingOnline) return;
    if (mounted) setState(() => _togglingOnline = true);
    // Dừng gửi vị trí NGAY trước khi gọi API — cùng lý do với _toggleOnline():
    // chờ tới lúc có phản hồi mới dừng thì stream vẫn kịp bắn 1 lần trong lúc
    // chờ mạng, ghi đè lên ngay sau lệnh xoá Firebase.
    LocationPushService.instance.stop();
    try {
      final (nowOnline, onlineSince) = await _setOnlineStatus(false);
      await ref.read(authProvider.notifier).updateOnlineStatus(
            nowOnline,
            onlineSince: onlineSince,
          );
      if (nowOnline) {
        await _restoreOnlineServicesAndRetry();
        return;
      }
      _forceOfflineRetryTimer?.cancel();
      _forceOfflineRetryTimer = null;
      await ref.read(shiftProvider.notifier).fetch();
      final uid = ref.read(authProvider).user?.id;
      if (uid != null) {
        FirebaseDatabase.instance
            .ref('locations/driver_$uid')
            .remove()
            .ignore();
      }
    } catch (_) {
      // Request có thể chưa tới server, hoặc server đã xử lý nhưng response
      // bị mất. Đọc lại nguồn sự thật trước khi quyết định giữ dịch vụ dừng.
      // Nếu vẫn online, phải khôi phục GPS + listener đơn ngay; nếu không app
      // sẽ rơi vào trạng thái "online giả" và tài xế âm thầm mất đơn.
      await ref.read(authProvider.notifier).refreshUser();
      final serverOnline = ref.read(authProvider).user?.isOnline ?? true;
      if (serverOnline) {
        await _restoreOnlineServicesAndRetry();
        if (mounted && !isRetry) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Kết nối không ổn định. Hệ thống đang thử tắt online lại.'),
            backgroundColor: AppColors.warning,
          ));
        }
      } else {
        _forceOfflineRetryTimer?.cancel();
        _forceOfflineRetryTimer = null;
      }
    } finally {
      if (mounted) setState(() => _togglingOnline = false);
    }
  }

  Future<void> _restoreOnlineServicesAndRetry() async {
    final driver = ref.read(authProvider).user;
    if (driver?.isOnline == true) {
      await LocationPushService.instance.start(driver!.id);
    }
    _forceOfflineRetryTimer?.cancel();
    _forceOfflineRetryTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) _forceOffline(isRetry: true);
    });
  }

  Future<void> _toggleOnline() async {
    // Chặn gọi chồng — nếu không, có thể race với _forceOffline() (nợ vừa
    // quá hạn) hoặc 1 tap bị xử lý trễ, gây tắt/bật liên tiếp trong 1 giây.
    if (_togglingOnline || _onlineToggleCooldownSeconds > 0) return;
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
      if (await OfferOverlay.isXiaomi()) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Nhận đơn khi chạy nền'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Trên Xiaomi, hãy bật hai cài đặt sau cho Flash Driver để hạn chế bỏ lỡ đơn khi tắt màn hình. Chạy nền có thể dùng thêm pin.'),
                  const SizedBox(height: 12),
                  const Text(
                      '1. Tự khởi động nền: bật Flash Driver trong danh sách.'),
                  TextButton(
                      onPressed: () async {
                        final opened = await OfferOverlay.autostartSettings();
                        if (!opened && dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Vào Cài đặt → Ứng dụng → Quyền → Tự khởi động nền.')));
                        }
                      },
                      child: const Text('Mở tự khởi động nền')),
                  const Text(
                      '2. Tiết kiệm pin: chọn Không hạn chế. Nếu mở trang thông tin ứng dụng, vào mục Pin hoặc Tiết kiệm pin.'),
                  TextButton(
                      onPressed: () async {
                        final opened = await OfferOverlay.batterySettings();
                        if (!opened && dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Vào Cài đặt → Pin → Flash Driver → Không hạn chế.')));
                        }
                      },
                      child: const Text('Mở cài đặt pin')),
                  const Text(
                      'Sau khi cài đặt, quay lại đây để tiếp tục Online.'),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Để sau')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Tiếp tục Online')),
            ],
          ),
        );
        if (!mounted) return;
      }
    } else {
      // Dừng gửi vị trí NGAY (trước khi gọi API) — nếu chờ tới lúc có phản
      // hồi mới dừng, stream vẫn kịp bắn 1 lần trong lúc chờ mạng, rồi ghi
      // đè lên đúng lúc lệnh xoá Firebase vừa chạy xong (thứ tự 2 request
      // mạng không đảm bảo) — marker "chớp lại" thay vì biến mất hẳn.
      LocationPushService.instance.stop();
    }
    setState(() => _togglingOnline = true);
    _startOnlineToggleCooldown();
    try {
      bool isOnline;
      DateTime? onlineSince;
      if (currentlyOnline) {
        (isOnline, onlineSince) = await _setOnlineStatus(false);
      } else {
        (isOnline, onlineSince) = await _setOnlineStatus(true);
      }
      await ref.read(authProvider.notifier).updateOnlineStatus(
            isOnline,
            onlineSince: onlineSince,
          );
      await ref.read(shiftProvider.notifier).fetch();
      if (isOnline) {
        final uid = ref.read(authProvider).user?.id;
        if (uid != null) {
          LocationPushService.instance.start(uid);
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
      // Request có thể đã được backend xử lý nhưng response bị mất giữa
      // đường (timeout/mạng chập chờn). Đối chiếu lại trạng thái thật trước
      // khi báo thất bại, tránh server đã online nhưng app vẫn báo lỗi.
      await ref.read(authProvider.notifier).refreshUser();
      if (!mounted) return;
      final desiredOnline = !currentlyOnline;
      final serverOnline = ref.read(authProvider).user?.isOnline;
      if (serverOnline == desiredOnline) {
        final uid = ref.read(authProvider).user?.id;
        if (uid != null) {
          if (serverOnline == true) {
            LocationPushService.instance.start(uid);
          } else {
            LocationPushService.instance.stop();
            FirebaseDatabase.instance
                .ref('locations/driver_$uid')
                .remove()
                .ignore();
          }
        }
        setState(() => _togglingOnline = false);
        return;
      }
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

  Widget _receivedSliver(List<OrderModel> orders) {
    if (orders.isEmpty) {
      return SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.inventory_2_outlined,
          iconColor: AppColors.primary.withValues(alpha: 0.45),
          iconBgColor: AppColors.primary.withValues(alpha: 0.08),
          circleSize: 76,
          iconSize: 36,
          title: 'Chưa nhận đơn nào',
          titleFontSize: 16,
          subtitle: 'Đơn bạn đã nhận và đang thực hiện sẽ hiện ở đây',
        ),
      );
    }
    return SliverList.separated(
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, index) {
        final card = ActiveOrderCard(
          key: ValueKey(orders[index].id),
          order: orders[index],
          orderIndex: index,
          totalCount: orders.length,
          isPriority: index == 0,
        );
        if (index != 0) return card;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReceivedOrdersSummary(count: orders.length),
            const SizedBox(height: AppSpacing.md),
            card,
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold dùng extendBody: true (cho hiệu ứng kính mờ ở BottomNav) nên
    // nội dung cuộn tới đâu cũng phải tự chừa khoảng trống che bởi thanh
    // nav nổi — không còn được Scaffold tự trừ chiều cao body như trước.
    final navClearance = BottomNav.reservedHeight(context);
    final user = ref.watch(authProvider).user;
    final wallet = ref.watch(walletProvider);
    final isOnline = user?.isOnline ?? false;
    final notifDenied = ref.watch(notifDeniedProvider);
    final locationIssue = ref.watch(locationIssueProvider);
    final activeOrders = ref.watch(activeOrderProvider).orders;
    final ordersTab = ref.watch(homeOrdersTabProvider);
    final newOrderCount =
        ref.watch(orderMarketProvider.select((s) => s.orders.length));

    ref.listen<WalletState>(walletProvider, (prev, next) {
      final hadOverdue = prev?.debts.any((d) => d.isOverdue) ?? false;
      final hasOverdue = next.debts.any((d) => d.isOverdue);
      if (!hadOverdue && hasOverdue) _forceOffline();
    });

    // GPS bị tắt/thu hồi quyền không còn đổi "ý định Online" thành
    // Offline. Dispatch tự loại vị trí cũ và backend chỉ cộng giờ cho
    // các khoảng GPS hợp lệ. Banner từ locationIssueProvider vẫn cảnh báo
    // để tài xế bật lại GPS; khi có fix mới, nhận đơn/tính giờ tự phục hồi.

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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Column(
        children: [
          // Cố định thông tin tài xế và nút Online; chỉ phần nội dung bên
          // dưới cuộn để tài xế luôn nhìn thấy và đổi trạng thái nhanh.
          DashboardHeader(
            user: user,
            isOnline: isOnline,
            toggling: _togglingOnline,
            toggleCooldownSeconds: _onlineToggleCooldownSeconds,
            locked: hasOverdueDebt,
            locationIssue: locationIssue,
            todayEarnings: wallet.earningsToday.total,
            todayOrders: wallet.earningsToday.orders,
            onToggle: _toggleOnline,
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refreshCurrentTab,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Banner cảnh báo (GPS, thông báo, công nợ) ─────────
                  SliverToBoxAdapter(
                    child: Column(children: [
                      if (locationIssue != null)
                        LocationIssueBanner(issue: locationIssue),
                      if (notifDenied) const NotifDeniedBanner(),
                      if (hasOverdueDebt)
                        OverdueBanner(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const DebtScreen()),
                          ),
                        ),
                    ]),
                  ),

                  // ── 3 tab con, ghim ở đầu vùng cuộn ──────────────────
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: PinnedHeaderDelegate(
                      height: 62,
                      child: OrdersTabBar(
                        index: ordersTab,
                        onChanged: _selectOrdersTab,
                        newCount: isOnline ? newOrderCount : 0,
                        receivedCount: activeOrders.length,
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    sliver: switch (ordersTab) {
                      1 => _receivedSliver(activeOrders),
                      2 => const CompletedOrdersSliver(),
                      _ => SliverToBoxAdapter(
                          child: NewOrdersSection(
                            isOnline: isOnline,
                            locked: hasOverdueDebt,
                            togglingOnline: _togglingOnline,
                            onGoOnline: _toggleOnline,
                          ),
                        ),
                    },
                  ),

                  SliverToBoxAdapter(
                      child: SizedBox(height: navClearance + AppSpacing.xl)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceivedOrdersSummary extends StatelessWidget {
  final int count;

  const _ReceivedOrdersSummary({required this.count});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.infoSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.info.withValues(alpha: .12)),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AppColors.info,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.route_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count đơn đang chạy',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Ưu tiên hoàn thành đơn đầu tiên trong danh sách',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
