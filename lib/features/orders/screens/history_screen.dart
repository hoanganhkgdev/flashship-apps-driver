import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import '../../wallet/providers/wallet_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _scrollCtrl  = ScrollController();
  int   _tabIndex    = 0; // 0=active, 1=completed

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
    final now   = DateTime.now();
    final local = dt.toLocal();
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      return 'Hôm nay';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (local.year == yesterday.year && local.month == yesterday.month &&
        local.day == yesterday.day) {
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
    final historyState  = ref.watch(orderHistoryProvider);
    final activeState   = ref.watch(activeOrderProvider);
    final walletBalance = ref.watch(walletProvider).balance;
    final allOrders     = historyState.orders;
    final activeOrders  = activeState.orders;

    final now          = DateTime.now();
    final allCompleted = allOrders.where((o) => o.isCompleted);
    final todayOrders  = allCompleted.where((o) {
      final dt = (o.completedAt ?? o.createdAt).toLocal();
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }).toList();
    final todayEarnings = todayOrders.fold<int>(0, (s, o) => s + o.driverEarning);

    final completedOrders = allOrders.where((o) => o.isCompleted).toList();
    final items           = _buildItems(completedOrders);

    final isActiveTab = _tabIndex == 0;
    final isLoading   = isActiveTab ? activeState.loading : historyState.loading;
    final isEmpty     = isActiveTab ? activeOrders.isEmpty : completedOrders.isEmpty;

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
                child: _Header(
                  todayCount:    todayOrders.length,
                  todayEarnings: todayEarnings,
                  walletBalance: walletBalance,
                  tabIndex:      _tabIndex,
                  onTab:         (i) => setState(() => _tabIndex = i),
                ),
              ),

              // Loading
              if (isLoading && isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2)),
                ),

              // Empty — completed tab
              if (!isLoading && isEmpty && !isActiveTab)
                SliverFillRemaining(
                  child: _EmptyState(onRefresh: () {
                    ref.read(orderHistoryProvider.notifier).fetch(refresh: true);
                  }),
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
                          child: _ActiveOrderCard(
                            order:      activeOrders[i],
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                                fontSize: 12, color: AppColors.info, height: 1.4),
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
                          if (item is String) return _DateLabel(label: item);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CompletedOrderCard(order: item as OrderModel),
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
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
  final int todayCount, todayEarnings, walletBalance, tabIndex;
  final ValueChanged<int> onTab;

  const _Header({
    required this.todayCount, required this.todayEarnings,
    required this.walletBalance, required this.tabIndex,
    required this.onTab,
  });

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
          Positioned(top: -40, right: -40, child: _Bubble(150, 0.07)),
          Positioned(top: 80,  left: -30,  child: _Bubble(80,  0.05)),
          Positioned(bottom: 40, right: 30, child: _Bubble(55, 0.04)),

          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(height: top),

            // Title
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Text('Đơn hàng',
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: -0.3,
                  )),
            ),

            const SizedBox(height: 16),

            // Stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _StatChip(
                  icon:  Icons.check_circle_rounded,
                  label: 'Hôm nay',
                  value: '$todayCount đơn',
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon:  Icons.trending_up_rounded,
                  label: 'Thu nhập',
                  value: Fmt.currency(todayEarnings),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon:  Icons.account_balance_wallet_rounded,
                  label: 'Trong ví',
                  value: Fmt.currency(walletBalance),
                ),
              ]),
            ),

            const SizedBox(height: 16),

            // Tab selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _TabPill(label: 'Đang nhận',  active: tabIndex == 0, onTap: () => onTab(0)),
                    _TabPill(label: 'Hoàn thành', active: tabIndex == 1, onTap: () => onTab(1)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Container(height: 20, color: AppColors.background),
          ]),
        ],
      ),
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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _StatChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.85)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white,
                ),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.72),
                )),
          ]),
        ),
      );
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabPill({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: active
                  ? [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4, offset: const Offset(0, 1),
                    )]
                  : null,
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? AppColors.primary : Colors.white,
                )),
          ),
        ),
      );
}

// ── Active order card ─────────────────────────────────────────────────────────

class _ActiveOrderCard extends StatelessWidget {
  final OrderModel order;
  final int orderIndex;
  const _ActiveOrderCard({required this.order, required this.orderIndex});

  String get _title => order.isShopOrder
      ? switch (order.shopServiceType) {
          'shop_batch'  => 'Đơn gộp',
          'shop_pickup' => 'Lấy hộ',
          _             => Fmt.serviceLabel(order.serviceType),
        }
      : Fmt.serviceLabel(order.serviceType);

  @override
  Widget build(BuildContext context) {
    final color   = Fmt.serviceColor(order.serviceType);
    final earning = order.driverEarning;

    return GestureDetector(
      onTap: () => context.go('/order/active', extra: orderIndex),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(children: [

          // Top row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Fmt.serviceIcon(order.serviceType), color: color, size: 20),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(_title,
                        style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        )),
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
                          style: const TextStyle(
                              fontSize: 8, fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(Fmt.orderStatus(order.status),
                        style: TextStyle(
                          fontSize: 11, color: color, fontWeight: FontWeight.w600,
                        )),
                  ]),
                ]),
              ),

              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(Fmt.currency(earning),
                    style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900,
                      color: AppColors.success,
                    )),
                const Text('thu nhập',
                    style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
              ]),

            ]),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Divider(height: 24, color: Color(0xFFF5F5F5)),
          ),

          // Route
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 1.5, height: 28, color: const Color(0xFFE0E0E0),
                  margin: const EdgeInsets.symmetric(vertical: 3),
                ),
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ]),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Pickup place
                  if ((order.isShopOrder
                          ? (order.storeName?.isNotEmpty == true ? order.storeName! : order.pickupPlaceName ?? '')
                          : (order.pickupPlaceName ?? ''))
                      case final String p when p.isNotEmpty) ...[
                    Text(p,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        )),
                    const SizedBox(height: 1),
                  ],
                  Text(order.pickupAddress,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary,
                      )),
                  const SizedBox(height: 14),
                  // Delivery place / customer name
                  if ((order.deliveryPlaceName?.isNotEmpty == true
                          ? order.deliveryPlaceName!
                          : (order.customerName ?? ''))
                      case final String d when d.isNotEmpty) ...[
                    Text(d,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        )),
                    const SizedBox(height: 1),
                  ],
                  Text(order.deliveryAddress,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary,
                      )),
                ]),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary, size: 18),
            ]),
          ),

        ]),
      ),
    );
  }
}

// ── Date label ────────────────────────────────────────────────────────────────

class _DateLabel extends StatelessWidget {
  final String label;
  const _DateLabel({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
        child: Text(label,
            style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            )),
      );
}

// ── Completed order card ──────────────────────────────────────────────────────

class _CompletedOrderCard extends StatelessWidget {
  final OrderModel order;
  const _CompletedOrderCard({required this.order});

  String get _title => order.isShopOrder
      ? switch (order.shopServiceType) {
          'shop_batch'  => 'Đơn gộp',
          'shop_pickup' => 'Lấy hộ',
          _             => Fmt.serviceLabel(order.serviceType),
        }
      : Fmt.serviceLabel(order.serviceType);

  String get _pickupName => order.isShopOrder
      ? (order.storeName?.isNotEmpty == true ? order.storeName! : order.pickupPlaceName ?? '')
      : (order.pickupPlaceName ?? '');

  String get _deliveryName =>
      order.deliveryPlaceName?.isNotEmpty == true
          ? order.deliveryPlaceName!
          : (order.customerName ?? '');

  @override
  Widget build(BuildContext context) {
    final color    = Fmt.serviceColor(order.serviceType);
    final earning  = order.driverEarning;
    final local    = (order.completedAt ?? order.createdAt).toLocal();
    final timeStr  = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: [

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Service icon
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Fmt.serviceIcon(order.serviceType), color: color, size: 20),
            ),

            const SizedBox(width: 12),

            // Title + time
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_title,
                    style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.access_time_rounded,
                      size: 11, color: AppColors.textTertiary),
                  const SizedBox(width: 3),
                  Text(timeStr,
                      style: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary,
                      )),
                  const SizedBox(width: 6),
                  Text('• #${order.code}',
                      style: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary,
                      )),
                ]),
              ]),
            ),

            // Earning + status
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                Fmt.currency(earning),
                style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800,
                  color: earning > 0 ? AppColors.success : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (order.isCompleted ? AppColors.success : AppColors.danger)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  order.isCompleted ? 'Hoàn thành' : 'Đã hủy',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: order.isCompleted ? AppColors.success : AppColors.danger,
                  ),
                ),
              ),
            ]),

          ]),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Divider(height: 20, color: Color(0xFFF5F5F5)),
        ),

        // Route
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(
                width: 7, height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 1.5, height: 14, color: const Color(0xFFE0E0E0),
                margin: const EdgeInsets.symmetric(vertical: 3),
              ),
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ]),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Pickup
                if (_pickupName case final String p when p.isNotEmpty) ...[
                  Text(p,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      )),
                  const SizedBox(height: 1),
                ],
                Text(order.pickupAddress,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: _pickupName.isNotEmpty
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    )),
                const SizedBox(height: 12),
                // Delivery
                if (_deliveryName case final String d when d.isNotEmpty) ...[
                  Text(d,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      )),
                  const SizedBox(height: 1),
                ],
                Text(order.deliveryAddress,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: _deliveryName.isNotEmpty
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    )),
              ]),
            ),
          ]),
        ),

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
            width: 76, height: 76,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_rounded,
                size: 36, color: AppColors.primary.withValues(alpha: 0.45)),
          ),
          const SizedBox(height: 16),
          const Text('Chưa có đơn nào',
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              )),
          const SizedBox(height: 6),
          const Text('Các đơn đã hoàn thành sẽ hiện ở đây',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onRefresh,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Tải lại',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  )),
            ),
          ),
        ]),
      );
}
