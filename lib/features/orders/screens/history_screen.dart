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
    final allOrders = historyState.orders;
    final activeOrders = activeState.orders;

    final now = DateTime.now();
    final allCompleted = allOrders.where((o) => o.isCompleted);
    final todayOrders = allCompleted.where((o) {
      final dt = (o.completedAt ?? o.createdAt).toLocal();
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }).toList();
    final todayEarnings =
        todayOrders.fold<int>(0, (s, o) => s + o.driverEarning);

    final completedOrders = allOrders.where((o) => o.isCompleted).toList();
    final items = _buildItems(completedOrders);

    final isActiveTab = _tabIndex == 0;
    final isLoading = isActiveTab ? activeState.loading : historyState.loading;
    final isEmpty =
        isActiveTab ? activeOrders.isEmpty : completedOrders.isEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
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
                  todayCount: todayOrders.length,
                  todayEarnings: todayEarnings,
                  walletBalance: walletBalance,
                  tabIndex: _tabIndex,
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
              if (isActiveTab) ...[
                if (activeOrders.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ActiveOrderCard(
                            order: activeOrders[i],
                            orderIndex: i,
                          ),
                        ),
                        childCount: activeOrders.length,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: AppColors.infoSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 14, color: AppColors.info),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            activeOrders.isEmpty
                                ? 'Chưa có đơn. Bạn có thể nhận tối đa 2 đơn cùng lúc.'
                                : 'Bạn có thể nhận tối đa 2 đơn cùng lúc.',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.info,
                                height: 1.4),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ],

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
