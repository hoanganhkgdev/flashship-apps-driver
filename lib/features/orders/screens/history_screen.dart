import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import '../widgets/history_header.dart';
import '../widgets/order_cards.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../home/widgets/bottom_nav.dart';
import '../../shifts/models/shift_model.dart';
import '../../shifts/providers/shift_provider.dart';

// Có đang trong khung giờ của 1 ca đã đăng ký ngay lúc này không — bản rút
// gọn (chỉ trả bool) của cùng logic ở DashboardHeader._activeShift(), viết
// độc lập ở đây để không đụng vào file đó (đang hoạt động ổn định).
bool _isOnShiftNow(List<ShiftModel> shifts, List<int> currentShiftIds) {
  final now = DateTime.now();
  DateTime todayAt(String hms) {
    final parts = hms.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return DateTime(now.year, now.month, now.day, h, m);
  }

  for (final s in shifts) {
    if (!currentShiftIds.contains(s.id)) continue;
    final start = todayAt(s.startTime);
    var end = todayAt(s.endTime);
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    if (now.isAfter(start) && now.isBefore(end)) return true;
    final startYesterday = start.subtract(const Duration(days: 1));
    final endYesterday = end.subtract(const Duration(days: 1));
    if (now.isAfter(startYesterday) && now.isBefore(endYesterday)) {
      return true;
    }
  }
  return false;
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _scrollCtrl = ScrollController();
  int _tabIndex = 0; // 0=active, 1=completed

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(orderHistoryProvider.notifier).fetch(refresh: true));
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_tabIndex == 1 &&
        _scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 150) {
      ref.read(orderHistoryProvider.notifier).fetch();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return 'Hôm nay';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day) {
      return 'Hôm qua';
    }
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  List<Object> _buildItems(List<OrderModel> orders) {
    final groups = <String, List<OrderModel>>{};
    final keys = <String>[];
    for (final o in orders) {
      final key = _dateLabel(o.completedAt ?? o.createdAt);
      if (!groups.containsKey(key)) {
        groups[key] = [];
        keys.add(key);
      }
      groups[key]!.add(o);
    }
    final items = <Object>[];
    for (final key in keys) {
      items.add(key);
      items.addAll(groups[key]!);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(orderHistoryProvider);
    final activeState = ref.watch(activeOrderProvider);
    final walletBalance = ref.watch(walletProvider).balance;
    final shiftState = ref.watch(shiftProvider);
    final allOrders = historyState.orders;
    final activeOrders = activeState.orders;
    final isOnShift =
        _isOnShiftNow(shiftState.shifts, shiftState.currentShiftIds);

    final now = DateTime.now();
    final allCompleted = allOrders.where((o) => o.isCompleted);
    final todayOrders = allCompleted.where((o) {
      final dt = (o.completedAt ?? o.createdAt).toLocal();
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }).toList();
    final todayEarnings =
        todayOrders.fold<int>(0, (s, o) => s + o.driverEarning);
    // "Hôm nay" = đơn đã hoàn thành hôm nay + đơn đang xử lý (luôn tính là
    // việc của "hôm nay" vì tối đa chỉ giữ active trong ngày) — trước đây
    // chỉ đếm đơn hoàn thành, khiến hiện "0 đơn" dù đang có đơn active thật.
    final todayOrderCount = todayOrders.length + activeOrders.length;

    final completedOrders = allOrders.where((o) => o.isCompleted).toList();
    final items = _buildItems(completedOrders);

    final isActiveTab = _tabIndex == 0;
    final isLoading = isActiveTab ? activeState.loading : historyState.loading;
    final isEmpty =
        isActiveTab ? activeOrders.isEmpty : completedOrders.isEmpty;
    // Đơn ưu tiên xử lý trước: đơn đã "processing" (đã lấy hàng, đang giao)
    // luôn gấp hơn đơn còn "assigned" (chưa lấy) — nếu chưa đơn nào processing
    // thì đơn đầu danh sách (thứ tự backend trả) là đơn tới lượt kế tiếp.
    final priorityIndex = activeOrders.isEmpty
        ? -1
        : (() {
            final idx =
                activeOrders.indexWhere((o) => o.status == 'processing');
            return idx >= 0 ? idx : 0;
          })();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        // Header giờ nền trắng (trước là gradient cam) — icon status bar phải
        // đổi sang màu đen mới nhìn thấy được, không còn dùng icon trắng nữa.
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await Future.wait([
              ref.read(orderHistoryProvider.notifier).fetch(refresh: true),
              ref.read(activeOrderProvider.notifier).fetch(),
            ]);
          },
          child: CustomScrollView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: HistoryHeader(
                  todayCount: todayOrderCount,
                  todayEarnings: todayEarnings,
                  walletBalance: walletBalance,
                  tabIndex: _tabIndex,
                  isOnShift: isOnShift,
                  onTab: (i) => setState(() => _tabIndex = i),
                ),
              ),

              // Loading
              if (isLoading && isEmpty)
                const SliverFillRemaining(
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2)),
                ),

              // Empty — completed tab
              if (!isLoading && isEmpty && !isActiveTab)
                SliverFillRemaining(
                  child: EmptyState(
                    icon: Icons.receipt_long_rounded,
                    iconColor: AppColors.primary.withValues(alpha: 0.45),
                    iconBgColor: AppColors.primary.withValues(alpha: 0.08),
                    circleSize: 76,
                    iconSize: 36,
                    title: 'Chưa có đơn nào',
                    titleFontSize: 16,
                    subtitle: 'Các đơn đã hoàn thành sẽ hiện ở đây',
                    actionLabel: 'Tải lại',
                    actionColor: AppColors.primary,
                    onAction: () {
                      ref
                          .read(orderHistoryProvider.notifier)
                          .fetch(refresh: true);
                    },
                  ),
                ),

              // ── Tab: Đang nhận ─────────────────────────────────────
              // Banner giới hạn đơn gộp làm phần tử CUỐI của cùng 1 SliverList
              // với các card — nằm liền mạch trong luồng chính, không tách
              // riêng thành khối trôi nổi cách xa như trước.
              if (isActiveTab)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        if (i < activeOrders.length) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ActiveOrderCard(
                              order: activeOrders[i],
                              orderIndex: i,
                              totalCount: activeOrders.length,
                              isPriority: i == priorityIndex,
                            ),
                          );
                        }
                        return MaxOrdersBanner(
                            activeCount: activeOrders.length);
                      },
                      childCount: activeOrders.length + 1,
                    ),
                  ),
                ),

              // ── Tab: Hoàn thành ────────────────────────────────────
              if (!isActiveTab && completedOrders.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        if (i < items.length) {
                          final item = items[i];
                          if (item is String) return DateLabel(label: item);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child:
                                CompletedOrderCard(order: item as OrderModel),
                          );
                        }
                        return historyState.loading
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: AppColors.primary,
                                        strokeWidth: 2)),
                              )
                            : const SizedBox.shrink();
                      },
                      childCount: items.length + (historyState.hasMore ? 1 : 0),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],

              // Chừa chỗ cho thanh bottom nav nổi (kính mờ, extendBody: true
              // ở HomeScreen) — không thì phần cuối bị nav che mất.
              SliverToBoxAdapter(
                child: SizedBox(height: BottomNav.reservedHeight(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
