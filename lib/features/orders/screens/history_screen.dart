import 'package:flutter/material.dart';
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
    ('active',    'Đã nhận'),
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
    final now = DateTime.now();
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
    final keys = <String>[];
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
        : <OrderModel>[]; // tab "Đã nhận" không dùng history list

    // Stats tính từ tất cả đơn hoàn thành hôm nay (không phụ thuộc tab đang chọn)
    final now = DateTime.now();
    final allCompleted = allOrders.where((o) => o.isCompleted);
    final todayOrders = allCompleted.where((o) {
      final dt = (o.completedAt ?? o.createdAt).toLocal();
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }).toList();
    final todayEarnings = todayOrders.fold<int>(0, (s, o) => s + o.shippingFee + o.bonusFee);

    final items      = _buildItems(orders);
    final isActiveTab = _filterStatus == 'active';
    // Loading và empty tách riêng theo tab để tránh spinner sai
    final isLoading  = isActiveTab
        ? activeState.loading
        : historyState.loading;
    final isEmpty    = isActiveTab
        ? activeOrders.isEmpty
        : orders.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await ref.read(orderHistoryProvider.notifier).fetch(refresh: true);
          await ref.read(activeOrderProvider.notifier).fetch();
        },
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [

            // ── Header ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _Header(
                todayCount:    todayOrders.length,
                todayEarnings: todayEarnings,
                tabController: _tabCtrl,
                filters:       _filters,
              ),
            ),

            // ── Loading ───────────────────────────────────────────────
            if (isLoading && isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2)),
              ),

            // ── Empty state (chỉ cho tab Hoàn thành) ─────────────────
            if (!isLoading && isEmpty && !isActiveTab)
              SliverFillRemaining(
                child: _EmptyState(onRefresh: () {
                  ref.read(orderHistoryProvider.notifier).fetch(refresh: true);
                  ref.read(activeOrderProvider.notifier).fetch();
                }),
              ),

            // ── Tab "Đã nhận": đơn đang thực hiện + ghi chú max 2 ───
            if (isActiveTab) ...[
              if (activeOrders.isNotEmpty) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        const Divider(height: 1),
                        ...activeOrders.asMap().entries.map((e) => _ActiveOrderTile(
                              order: e.value,
                              orderIndex: e.key,
                              showDivider: e.key < activeOrders.length - 1,
                            )),
                      ],
                    ),
                  ),
                ),
              ],
              // Ghi chú tối đa 2 đơn
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      activeOrders.isEmpty
                          ? 'Chưa có đơn. Tài xế chỉ nhận tối đa 2 đơn cùng lúc.'
                          : 'Tài xế chỉ nhận tối đa 2 đơn cùng lúc.',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ]),
                ),
              ),
            ],

            // ── Tab "Hoàn thành": phân ngày ──────────────────────────
            if (!isActiveTab && orders.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    if (i < items.length) {
                      final item = items[i];
                      if (item is String) return _DateHeader(label: item);
                      final order = item as OrderModel;
                      final idx   = items.indexOf(order);
                      final next  = idx + 1 < items.length ? items[idx + 1] : null;
                      return _OrderTile(order: order, showDivider: next is OrderModel);
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
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],

          ],
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
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16, top + 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text('Đơn hàng',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),

          const SizedBox(height: 16),

          // Stats row
          Row(children: [
            Expanded(
              child: _StatTile(
                label: 'Hôm nay',
                value: '$todayCount đơn',
                color: AppColors.primary,
              ),
            ),
            Container(width: 1, height: 36, color: AppColors.divider),
            Expanded(
              child: _StatTile(
                label: 'Thu nhập',
                value: Fmt.currency(todayEarnings),
                color: AppColors.success,
              ),
            ),
          ]),

          const SizedBox(height: 14),
          const Divider(height: 1),

          // Filter tabs
          SizedBox(
            height: 44,
            child: TabBar(
              controller: tabController,
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              dividerColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: filters.map((f) => Tab(text: f.$2)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}

// ── Active order tile (đang thực hiện) ───────────────────────────────────────

class _ActiveOrderTile extends StatelessWidget {
  final OrderModel order;
  final int orderIndex;
  final bool showDivider;
  const _ActiveOrderTile({
    required this.order,
    required this.orderIndex,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final color   = Fmt.serviceColor(order.serviceType);
    final earning = order.shippingFee + order.bonusFee;
    return Column(children: [
      InkWell(
        onTap: () => context.go('/order/active', extra: orderIndex),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(Fmt.serviceIcon(order.serviceType), color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      order.isShopOrder
                          ? switch (order.shopServiceType) {
                              'shop_batch'  => 'Đơn gộp',
                              'shop_pickup' => 'Lấy hộ',
                              _             => 'Giao đơn',
                            }
                          : Fmt.serviceLabel(order.serviceType),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
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
                        order.isBatch ? 'SHOP•${order.stopsCount}đ' : 'SHOP',
                        style: const TextStyle(
                            fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ],
                ]),
                Text(Fmt.orderStatus(order.status),
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(Fmt.currency(earning),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                        color: AppColors.success)),
                const Text('thu nhập',
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ]),
            ]),
            const SizedBox(height: 10),
            // Route
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(width: 7, height: 7,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                Container(width: 1, height: 16, color: AppColors.divider,
                    margin: const EdgeInsets.symmetric(vertical: 2)),
                Container(width: 7, height: 7,
                    decoration: BoxDecoration(color: AppColors.success,
                        borderRadius: BorderRadius.circular(2))),
              ]),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(order.pickupAddress, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                Text(order.deliveryAddress, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ])),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 18),
            ]),
          ]),
        ),
      ),
      if (showDivider) const Divider(height: 1, indent: 16, endIndent: 16),
    ]);
  }
}

// ── Date header ───────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  final String label;
  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFF5F5F5),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary)),
      );
}

// ── Order tile — flat list item ───────────────────────────────────────────────

class _OrderTile extends StatelessWidget {
  final OrderModel order;
  final bool showDivider;
  const _OrderTile({required this.order, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    final color         = Fmt.serviceColor(order.serviceType);
    final totalEarnings = order.shippingFee + order.bonusFee;
    final isCompleted   = order.isCompleted;
    final local         = (order.completedAt ?? order.createdAt).toLocal();
    final timeStr       = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    return Container(
      color: Colors.white,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Header: icon + dịch vụ + thu nhập + giờ
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Fmt.serviceIcon(order.serviceType),
                    color: color, size: 18),
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
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                  Text(timeStr,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(Fmt.currency(totalEarnings),
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800,
                        color: totalEarnings > 0
                            ? AppColors.success
                            : AppColors.textSecondary)),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isCompleted ? AppColors.success : AppColors.danger)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isCompleted ? 'Hoàn thành' : 'Đã hủy',
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: isCompleted ? AppColors.success : AppColors.danger),
                  ),
                ),
              ]),
            ]),

            const SizedBox(height: 10),

            // Route: pickup → delivery
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(width: 7, height: 7,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle)),
                Container(width: 1, height: 16, color: AppColors.divider,
                    margin: const EdgeInsets.symmetric(vertical: 2)),
                Container(width: 7, height: 7,
                    decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(2))),
              ]),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(order.pickupAddress,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  Text(order.deliveryAddress,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ),
            ]),
          ]),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 16, endIndent: 16),
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
          const Icon(Icons.receipt_long_outlined,
              size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          const Text('Chưa có đơn nào',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Các đơn đã hoàn thành sẽ hiện ở đây',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: onRefresh,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Tải lại'),
          ),
        ]),
      );
}
