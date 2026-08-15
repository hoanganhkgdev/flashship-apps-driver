import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';
import '../../orders/models/order_model.dart';
import '../../orders/providers/order_provider.dart';
import '../../home/widgets/bottom_nav.dart';

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  int _period = 0; // 0=hôm nay, 1=tuần này, 2=tháng này

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(orderHistoryProvider.notifier).fetch(refresh: true));
  }

  EarningsSummary _summary(WalletState w) => switch (_period) {
        0 => w.earningsToday,
        1 => w.earningsWeekly,
        _ => w.earningsMonthly,
      };

  // Lọc danh sách theo đúng kỳ đang chọn — trước đây danh sách luôn hiện toàn
  // bộ lịch sử bất kể tab, khiến tổng tiền đổi theo tab nhưng danh sách bên
  // dưới thì không, gây hiểu nhầm số liệu sai lệch.
  List<OrderModel> _filterByPeriod(List<OrderModel> orders) {
    final now = DateTime.now();
    DateTime start;
    switch (_period) {
      case 0:
        start = DateTime(now.year, now.month, now.day);
        break;
      case 1:
        final weekday = now.weekday; // 1=Mon..7=Sun
        start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: weekday - 1));
        break;
      default:
        start = DateTime(now.year, now.month, 1);
    }
    return orders.where((o) {
      final dt = o.completedAt ?? o.createdAt;
      return !dt.isBefore(start);
    }).toList();
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(walletProvider.notifier).fetch(),
      ref.read(orderHistoryProvider.notifier).fetch(refresh: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final history = ref.watch(orderHistoryProvider);
    final summary = _summary(wallet);
    final filteredOrders = _filterByPeriod(history.orders);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        // Header giờ nền trắng (trước là gradient cam) — icon status bar
        // phải đổi sang màu đen mới nhìn thấy được.
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  period: _period,
                  onPeriod: (p) => setState(() => _period = p),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: _TotalEarningsCard(
                    summary: summary,
                    loading: wallet.loading,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: _StatsRow(
                  summary: summary,
                  balance: wallet.balance,
                ),
              ),

              SliverToBoxAdapter(
                child: _OrderEarningsSection(
                  orders: filteredOrders,
                  loading: history.loading,
                  hasMore: history.hasMore,
                  onLoadMore: () =>
                      ref.read(orderHistoryProvider.notifier).fetch(),
                ),
              ),

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

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int period;
  final ValueChanged<int> onPeriod;

  const _Header({required this.period, required this.onPeriod});

  static const _labels = ['Hôm nay', 'Tuần này', 'Tháng này'];

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Container(
      color: AppColors.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: top),

        // Topbar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            const Text('Thu nhập',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                )),
            const Spacer(),
            GestureDetector(
              onTap: () => context.push('/wallet'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  const Text('Xem ví',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      )),
                ]),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 14),

        // Period tabs — gạch chân cam thay vì pill nổi trên nền cam
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: List.generate(_labels.length, (i) {
              final active = i == period;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onPeriod(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: active ? AppColors.primary : AppColors.divider,
                          width: active ? 2 : 1,
                        ),
                      ),
                    ),
                    child: Text(
                      _labels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                        color: active
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }
}

// ── Total earnings card ──────────────────────────────────────────────────────

class _TotalEarningsCard extends StatelessWidget {
  final EarningsSummary summary;
  final bool loading;
  const _TotalEarningsCard({required this.summary, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: loading
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                height: 14,
                width: 90,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 36,
                width: 180,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tổng thu nhập',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  )),
              const SizedBox(height: 6),
              Text(
                Fmt.currency(summary.total),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${summary.orders} đơn hoàn thành',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    )),
              ),
            ]),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final EarningsSummary summary;
  final int balance;
  const _StatsRow({required this.summary, required this.balance});

  int get _avgPerOrder =>
      summary.orders == 0 ? 0 : (summary.total / summary.orders).round();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: IntrinsicHeight(
        child: Row(children: [
          Expanded(
            child: _StatCard(
              icon: Icons.trending_up_rounded,
              label: 'Trung bình/đơn',
              value: Fmt.currency(_avgPerOrder),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Số dư ví',
              value: Fmt.currency(balance),
            ),
          ),
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(height: 12),
          Text(label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              )),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              )),
        ]),
      );
}

// ── Order earnings section ────────────────────────────────────────────────────

class _OrderEarningsSection extends StatelessWidget {
  final List<OrderModel> orders;
  final bool loading;
  final bool hasMore;
  final VoidCallback onLoadMore;

  const _OrderEarningsSection({
    required this.orders,
    required this.loading,
    required this.hasMore,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(children: [
              const Text('Lịch sử thu nhập',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  )),
              const Spacer(),
              if (orders.isNotEmpty)
                Text('${orders.length} đơn',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    )),
            ]),
          ),
          if (loading && orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2)),
            )
          else if (orders.isEmpty)
            const _EmptyEarnings()
          else ...[
            ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const Divider(
                  height: 1, indent: 76, color: Color(0xFFF5F5F5)),
              itemBuilder: (_, i) => _OrderEarningsItem(order: orders[i]),
            ),
            if (hasMore)
              Padding(
                padding: const EdgeInsets.all(12),
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 2),
                      )
                    : GestureDetector(
                        onTap: onLoadMore,
                        child: const Text('Xem thêm',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            )),
                      ),
              ),
          ],
        ]),
      ),
    );
  }
}

class _OrderEarningsItem extends StatelessWidget {
  final OrderModel order;
  const _OrderEarningsItem({required this.order});

  String get _serviceLabel => Fmt.serviceLabel(order.serviceType);

  String _timeLabel() {
    final dt = order.completedAt ?? order.createdAt;
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: Color(0xFFECFDF5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.north_rounded,
              color: AppColors.success, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '$_serviceLabel #${order.code}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(_timeLabel(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                )),
          ]),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            '+${Fmt.currency(order.driverEarning)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.success,
            ),
          ),
          if (order.bonusFee > 0)
            Text(
              '+${Fmt.currency(order.bonusFee)} thưởng',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.primary,
              ),
            ),
        ]),
      ]),
    );
  }
}

class _EmptyEarnings extends StatelessWidget {
  const _EmptyEarnings();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bar_chart_rounded,
                  color: AppColors.primary.withValues(alpha: 0.5), size: 22),
            ),
            const SizedBox(height: 10),
            const Text('Chưa có thu nhập',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                )),
            const SizedBox(height: 3),
            const Text('Hoàn thành đơn để tích lũy thu nhập',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          ]),
        ),
      );
}
