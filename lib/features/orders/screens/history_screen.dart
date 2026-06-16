import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  final _scrollCtrl = ScrollController();
  late final TabController _tabCtrl;
  String _filterStatus = 'active';

  static const _filters = [
    ('active',    'Đang nhận'),
    ('completed', 'Hoàn thành'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _filters.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() => _filterStatus = _filters[_tabCtrl.index].$1);
      }
    });
    Future.microtask(
        () => ref.read(orderHistoryProvider.notifier).fetch(refresh: true));
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 150) {
      ref.read(orderHistoryProvider.notifier).fetch();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  String _dateLabel(DateTime dt) {
    final now  = DateTime.now();
    final local = dt.toLocal();
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      return 'Hôm nay';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (local.year == yesterday.year && local.month == yesterday.month && local.day == yesterday.day) {
      return 'Hôm qua';
    }
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  List<Object> _buildItems(List<OrderModel> orders) {
    final groups = <String, List<OrderModel>>{};
    final keys   = <String>[];
    for (final o in orders) {
      final key = _dateLabel(o.completedAt ?? o.createdAt);
      if (!groups.containsKey(key)) { groups[key] = []; keys.add(key); }
      groups[key]!.add(o);
    }
    final items = <Object>[];
    for (final key in keys) { items.add(key); items.addAll(groups[key]!); }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(orderHistoryProvider);
    final activeState  = ref.watch(activeOrderProvider);
    final allOrders    = historyState.orders;
    final activeOrders = activeState.orders;

    final orders = _filterStatus == 'completed'
        ? allOrders.where((o) => o.isCompleted).toList()
        : <OrderModel>[];

    final now          = DateTime.now();
    final allCompleted = allOrders.where((o) => o.isCompleted);
    final todayOrders  = allCompleted.where((o) {
      final dt = (o.completedAt ?? o.createdAt).toLocal();
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }).toList();
    final todayEarnings = todayOrders.fold<int>(0, (s, o) => s + o.shippingFee + o.bonusFee);

    final items       = _buildItems(orders);
    final isActiveTab = _filterStatus == 'active';
    final isLoading   = isActiveTab ? activeState.loading : historyState.loading;
    final isEmpty     = isActiveTab ? activeOrders.isEmpty : orders.isEmpty;

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
            await ref.read(orderHistoryProvider.notifier).fetch(refresh: true);
            await ref.read(activeOrderProvider.notifier).fetch();
          },
          child: CustomScrollView(
            controller: _scrollCtrl,
            slivers: [

              // ── Gradient header ────────────────────────────────────
              SliverToBoxAdapter(
                child: _Header(
                  todayCount:    todayOrders.length,
                  todayEarnings: todayEarnings,
                  tabController: _tabCtrl,
                  filters:       _filters,
                ),
              ),

              // ── Loading ────────────────────────────────────────────
              if (isLoading && isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2)),
                ),

              // ── Empty (completed tab) ──────────────────────────────
              if (!isLoading && isEmpty && !isActiveTab)
                SliverFillRemaining(
                  child: _EmptyState(onRefresh: () {
                    ref.read(orderHistoryProvider.notifier).fetch(refresh: true);
                    ref.read(activeOrderProvider.notifier).fetch();
                  }),
                ),

              // ── Active tab ─────────────────────────────────────────
              if (isActiveTab) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                if (activeOrders.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _ActiveOrderCard(
                          order:      activeOrders[i],
                          orderIndex: i,
                        ),
                      ),
                      childCount: activeOrders.length,
                    ),
                  ),

                // Info note
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.infoSoft,
                        borderRadius: BorderRadius.circular(10),
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
                            style: const TextStyle(fontSize: 12, color: AppColors.info),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ],

              // ── Completed tab ──────────────────────────────────────
              if (!isActiveTab && orders.isNotEmpty) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      if (i < items.length) {
                        final item = items[i];
                        if (item is String) return _DateHeader(label: item);
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: _OrderCard(order: item as OrderModel),
                        );
                      }
                      return historyState.loading
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: CircularProgressIndicator(
                                  color: AppColors.primary, strokeWidth: 2)),
                            )
                          : const SizedBox.shrink();
                    },
                    childCount: items.length + (historyState.hasMore ? 1 : 0),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],

            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int todayCount;
  final int todayEarnings;
  final TabController tabController;
  final List<(String, String)> filters;

  const _Header({
    required this.todayCount,
    required this.todayEarnings,
    required this.tabController,
    required this.filters,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEF7C1A), AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Title
                const Text(
                  'Đơn hàng',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),

                const SizedBox(height: 16),

                // Stats chips
                Row(children: [
                  _StatChip(
                    icon: Icons.inventory_2_rounded,
                    label: '$todayCount đơn hôm nay',
                  ),
                  const SizedBox(width: 10),
                  _StatChip(
                    icon: Icons.payments_outlined,
                    label: Fmt.currency(todayEarnings),
                  ),
                ]),

                const SizedBox(height: 16),

                // Tab bar
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: TabBar(
                    controller: tabController,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    padding: const EdgeInsets.all(3),
                    labelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Colors.white,
                    tabs: filters.map((f) => Tab(text: f.$2, height: 32)).toList(),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),

          // Curved bottom
          Container(
            height: 20,
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ]),
      );
}

// ── Active order card ─────────────────────────────────────────────────────────

class _ActiveOrderCard extends StatelessWidget {
  final OrderModel order;
  final int orderIndex;
  const _ActiveOrderCard({required this.order, required this.orderIndex});

  @override
  Widget build(BuildContext context) {
    final color   = Fmt.serviceColor(order.serviceType);
    final earning = order.shippingFee + order.bonusFee;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppColors.cardShadow,
      ),
      child: InkWell(
        onTap: () => context.go('/order/active', extra: orderIndex),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Top row: icon + label + status + earning
            Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Fmt.serviceIcon(order.serviceType), color: color, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(
                      order.isShopOrder
                          ? switch (order.shopServiceType) {
                              'shop_batch'  => 'Đơn gộp',
                              'shop_pickup' => 'Lấy hộ',
                              _             => 'Giao đơn',
                            }
                          : Fmt.serviceLabel(order.serviceType),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    if (order.isShopOrder) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          order.isBatch ? 'SHOP·${order.stopsCount}đ' : 'SHOP',
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(Fmt.orderStatus(order.status),
                        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                  ]),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  Fmt.currency(earning),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.success),
                ),
                const Text('thu nhập',
                    style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
              ]),
            ]),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),

            // Route
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                ),
                Container(width: 1.5, height: 16, color: AppColors.divider,
                    margin: const EdgeInsets.symmetric(vertical: 3)),
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: AppColors.success, borderRadius: BorderRadius.circular(2)),
                ),
              ]),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(order.pickupAddress,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 14),
                  Text(order.deliveryAddress,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                ]),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 18),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Date header ───────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  final String label;
  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 16, 6),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 0.5,
          ),
        ),
      );
}

// ── Completed order card ──────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final color         = Fmt.serviceColor(order.serviceType);
    final totalEarnings = order.shippingFee + order.bonusFee;
    final isCompleted   = order.isCompleted;
    final local         = (order.completedAt ?? order.createdAt).toLocal();
    final timeStr       = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Top row
        Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Fmt.serviceIcon(order.serviceType), color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                order.isShopOrder
                    ? switch (order.shopServiceType) {
                        'shop_batch'  => 'Đơn gộp',
                        'shop_pickup' => 'Lấy hộ',
                        _             => 'Giao đơn',
                      }
                    : Fmt.serviceLabel(order.serviceType),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.access_time_rounded, size: 10, color: AppColors.textTertiary),
                const SizedBox(width: 3),
                Text(timeStr, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              ]),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              Fmt.currency(totalEarnings),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: totalEarnings > 0 ? AppColors.success : AppColors.textSecondary),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: (isCompleted ? AppColors.success : AppColors.danger)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isCompleted ? 'Hoàn thành' : 'Đã hủy',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? AppColors.success : AppColors.danger),
              ),
            ),
          ]),
        ]),

        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 12),

        // Route
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            ),
            Container(width: 1.5, height: 16, color: AppColors.divider,
                margin: const EdgeInsets.symmetric(vertical: 3)),
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                  color: AppColors.success, borderRadius: BorderRadius.circular(2)),
            ),
          ]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order.pickupAddress,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 14),
              Text(order.deliveryAddress,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ]),
          ),
        ]),
      ]),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 34, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 16),
          const Text('Chưa có đơn nào',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Các đơn đã hoàn thành sẽ hiện ở đây',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: onRefresh,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Tải lại'),
          ),
        ]),
      );
}
