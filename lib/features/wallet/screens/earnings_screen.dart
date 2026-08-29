import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';
import '../widgets/payment_qr_sheet.dart';
import 'debt_screen.dart';
import '../../orders/models/order_model.dart';
import '../../orders/providers/order_provider.dart';
import '../../home/widgets/bottom_nav.dart';

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  int _period = 1; // 0=hôm nay, 1=tuần này, 2=tháng này
  int _historyTab = 0; // 0=Đơn hàng, 1=Giao dịch ví
  // Theo dõi loại biểu đồ đã fetch gần nhất — "Hôm nay" và "Tuần này" dùng
  // chung dữ liệu tuần (earnings/weekly), chỉ "Tháng này" mới cần gọi lại
  // earnings/monthly, tránh refetch thừa khi chuyển qua lại 2 tab đầu.
  bool _chartMonthly = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(orderHistoryProvider.notifier).fetch(refresh: true);
      ref.read(walletProvider.notifier).fetchDailyEarnings(monthly: false);
    });
  }

  void _onPeriod(int p) {
    setState(() => _period = p);
    final monthly = p == 2;
    if (monthly != _chartMonthly) {
      _chartMonthly = monthly;
      ref.read(walletProvider.notifier).fetchDailyEarnings(monthly: monthly);
    }
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

  Future<void> _payDebt(DriverDebt debt) async {
    final paid = await PaymentQrSheet.show(
      context,
      type: 'debt_payment',
      amount: debt.remaining,
      debtId: debt.id,
      label: 'Thanh toán công nợ',
    );
    if (mounted && paid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Thanh toán thành công!'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final history = ref.watch(orderHistoryProvider);
    final summary = _summary(wallet);
    final filteredOrders = _filterByPeriod(history.orders);

    // Nợ phạt điểm tuần — khẩn cấp nhất (hạn 24h), luôn hiện tối đa 1 khối dù
    // có nhiều khoản (trường hợp hiếm) để tránh chồng nhiều cảnh báo đỏ.
    final urgentDebts = wallet.debts.where((d) => d.isScorePenalty).toList();
    final urgentDebt = urgentDebts.isEmpty ? null : urgentDebts.first;

    // Nợ phí tuần thường — ít khẩn cấp hơn (hạn cuối tuần), gộp thành 1 dòng.
    final weeklyFeeDebts = wallet.debts.where((d) => d.isWeeklyFee).toList();
    final weeklyFeeTotal =
        weeklyFeeDebts.fold<int>(0, (s, d) => s + d.remaining);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        // Header giờ nền trắng (trước là gradient cam) — icon status bar
        // phải đổi sang màu đen mới nhìn thấy được.
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8F5),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: _Header()),

              SliverToBoxAdapter(
                child: _PeriodTabs(period: _period, onPeriod: _onPeriod),
              ),

              if (urgentDebt != null)
                SliverToBoxAdapter(
                  child: _UrgentDebtCard(
                    debt: urgentDebt,
                    onPay: () => _payDebt(urgentDebt),
                  ),
                ),

              if (weeklyFeeDebts.isNotEmpty)
                SliverToBoxAdapter(
                  child: _WeeklyFeeRow(
                    amount: weeklyFeeTotal,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const DebtScreen())),
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                child: _EarningsChart(
                  data: wallet.dailyEarnings,
                  loading: wallet.dailyEarningsLoading,
                  monthly: _period == 2,
                ),
              ),

              SliverToBoxAdapter(
                child: _OrderEarningsSection(
                  orders: filteredOrders,
                  loading: history.loading,
                  hasMore: history.hasMore,
                  onLoadMore: () =>
                      ref.read(orderHistoryProvider.notifier).fetch(),
                  transactions: wallet.transactions,
                  transactionsLoading: wallet.loading,
                  tab: _historyTab,
                  onTab: (t) => setState(() => _historyTab = t),
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
  const _Header();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Container(
      color: const Color(0xFFFFF8F5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: top + 16),

        // Topbar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Row(children: [
            const Text('Thu nhập',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1411),
                  letterSpacing: -0.7,
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
                      size: 16, color: Color(0xFF17110F)),
                  const SizedBox(width: 6),
                  const Text('Xem ví',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6A605C),
                      )),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Period tabs — đặt ngay trên khối "Tổng thu nhập", sau các khối cố định
// theo tuần (Phí tuần, Điểm số tuần) để phạm vi ảnh hưởng của tab rõ ràng.

class _PeriodTabs extends StatelessWidget {
  final int period;
  final ValueChanged<int> onPeriod;

  const _PeriodTabs({required this.period, required this.onPeriod});

  static const _labels = ['Hôm nay', 'Tuần này', 'Tháng này'];

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE5DDD9)))),
        child: Row(
          children: List.generate(_labels.length, (i) {
            final active = i == period;
            return Expanded(
              child: GestureDetector(
                onTap: () => onPeriod(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: active
                            ? const Color(0xFFFF6035)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      color: active
                          ? const Color(0xFFFF6035)
                          : const Color(0xFF6A605C),
                    ),
                  ),
                ),
              ),
            );
          }),
        ));
  }
}

// ── Urgent debt (phạt điểm tuần, hạn 24h) ───────────────────────────────────

class _UrgentDebtCard extends StatelessWidget {
  final DriverDebt debt;
  final VoidCallback onPay;
  const _UrgentDebtCard({required this.debt, required this.onPay});

  String get _timeLabel {
    final d = debt.timeUntilDue;
    if (d.isNegative) return 'Đã quá hạn thanh toán';
    if (d.inHours < 1) return 'Còn ${d.inMinutes} phút để thanh toán';
    return 'Còn ${d.inHours} giờ để thanh toán';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: AppColors.danger, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Phạt điểm tuần',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger,
                  )),
              const SizedBox(height: 2),
              Text(_timeLabel,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.danger)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Text(
            Fmt.currency(debt.remaining),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.danger,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 38,
            child: FilledButton.icon(
              onPressed: onPay,
              icon: const Icon(Icons.qr_code_rounded,
                  size: 16, color: Colors.white),
              label: const Text('Thanh toán qua PayOS',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  )),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── Weekly fee row (phí tuần thường, hạn cuối tuần) ─────────────────────────

class _WeeklyFeeRow extends StatelessWidget {
  final int amount;
  final VoidCallback onTap;
  const _WeeklyFeeRow({required this.amount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(children: [
          const Icon(Icons.receipt_long_rounded,
              size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Phí tuần · Hạn Chủ nhật',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                )),
          ),
          Text(Fmt.currency(amount),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              )),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right_rounded,
              size: 16, color: AppColors.textTertiary),
        ]),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFD8F4DF),
        borderRadius: BorderRadius.circular(20),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF229650),
                  )),
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                  child: Text(
                    Fmt.currency(summary.total),
                    style: const TextStyle(
                      fontSize: 31,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF229650),
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
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
                        color: Color(0xFF229650),
                      )),
                ),
              ]),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFEFD),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5DDD9)),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
      );
}

// ── Earnings chart (7 ngày gần đây / theo ngày trong tháng) ─────────────────

class _EarningsChart extends StatelessWidget {
  final List<DailyEarning> data;
  final bool loading;
  final bool monthly;
  const _EarningsChart({
    required this.data,
    required this.loading,
    required this.monthly,
  });

  static const _weekdayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const _barMaxHeight = 70.0;

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Widget _bar(DailyEarning d, int maxTotal, {required double width}) {
    final frac = maxTotal == 0 ? 0.0 : (d.total / maxTotal).clamp(0.0, 1.0);
    final isToday = _isToday(d.date);
    return SizedBox(
      width: width,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: _barMaxHeight,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: (_barMaxHeight * frac).clamp(3.0, _barMaxHeight),
              width: monthly ? 12 : 18,
              decoration: BoxDecoration(
                color: isToday
                    ? AppColors.primaryDark
                    : AppColors.primary.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          monthly ? '${d.date.day}' : _weekdayLabels[d.date.weekday - 1],
          style: TextStyle(
            fontSize: 10,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
            color: isToday ? AppColors.primaryDark : AppColors.textTertiary,
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading && data.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        height: 148,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2)),
      );
    }
    if (data.isEmpty) return const SizedBox.shrink();

    final maxTotal =
        data.map((d) => d.total).fold<int>(0, (a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5DDD9)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          monthly
              ? 'Thu nhập theo ngày trong tháng'
              : 'Thu nhập 7 ngày gần đây',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (_, constraints) {
          // Không dựa hẳn vào cờ `monthly` để quyết định có cuộn hay không —
          // khi đổi tab, `monthly` đổi ngay (setState đồng bộ) nhưng `data`
          // có thể vẫn là dữ liệu kỳ cũ trong lúc chờ API mới trả về (~1
          // frame), khiến Row cố định (spaceBetween) nhận nhầm 30 cột dữ
          // liệu tháng vào chỗ dành cho 7 cột tuần → tràn layout. Đo bề rộng
          // thực tế của nội dung so với khung để tự chọn layout phù hợp,
          // an toàn với mọi trạng thái dữ liệu tạm thời.
          const gap = 6.0;
          final barWidth = monthly ? 26.0 : 32.0;
          final contentWidth = data.length * (barWidth + gap);
          final bars = data
              .map((d) => Padding(
                    padding: const EdgeInsets.only(right: gap),
                    child: _bar(d, maxTotal, width: barWidth),
                  ))
              .toList();

          if (contentWidth > constraints.maxWidth) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(mainAxisSize: MainAxisSize.min, children: bars),
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:
                data.map((d) => _bar(d, maxTotal, width: barWidth)).toList(),
          );
        }),
      ]),
    );
  }
}

// ── Order earnings section ────────────────────────────────────────────────────

class _OrderEarningsSection extends StatelessWidget {
  final List<OrderModel> orders;
  final bool loading;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final List<WalletTransaction> transactions;
  final bool transactionsLoading;
  final int tab;
  final ValueChanged<int> onTab;

  const _OrderEarningsSection({
    required this.orders,
    required this.loading,
    required this.hasMore,
    required this.onLoadMore,
    required this.transactions,
    required this.transactionsLoading,
    required this.tab,
    required this.onTab,
  });

  static const _tabs = ['Đơn hàng', 'Giao dịch ví'];

  @override
  Widget build(BuildContext context) {
    final isOrders = tab == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFEFD),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5DDD9)),
        ),
        child: Column(children: [
          // Tab underline — chọn nguồn dữ liệu hiện phía dưới
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final active = i == tab;
                return Padding(
                  padding: const EdgeInsets.only(right: 22),
                  child: GestureDetector(
                    onTap: () => onTab(i),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 9),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color:
                                active ? AppColors.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(_tabs[i],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                active ? FontWeight.w800 : FontWeight.w600,
                            color: active
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          )),
                    ),
                  ),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (isOrders && orders.isNotEmpty)
                Text('${orders.length} đơn',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    )),
              if (!isOrders && transactions.isNotEmpty)
                Text('${transactions.length} giao dịch',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    )),
            ]),
          ),
          if (isOrders) ...[
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
          ] else ...[
            if (transactionsLoading && transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2)),
              )
            else if (transactions.isEmpty)
              const _EmptyEarnings(
                icon: Icons.receipt_long_rounded,
                title: 'Chưa có giao dịch',
                subtitle: 'Lịch sử giao dịch ví sẽ hiện ở đây',
              )
            else
              ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                separatorBuilder: (_, __) => const Divider(
                    height: 1, indent: 76, color: Color(0xFFF5F5F5)),
                itemBuilder: (_, i) =>
                    _WalletTransactionItem(tx: transactions[i]),
              ),
          ],
        ]),
      ),
    );
  }
}

class _WalletTransactionItem extends StatelessWidget {
  final WalletTransaction tx;
  const _WalletTransactionItem({required this.tx});

  String _timeLabel() {
    final dt = tx.createdAt;
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final credit = tx.isCredit;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: credit ? const Color(0xFFECFDF5) : AppColors.surfaceAlt,
            shape: BoxShape.circle,
          ),
          child: Icon(
            credit ? Icons.south_west_rounded : Icons.north_east_rounded,
            color: credit ? AppColors.success : AppColors.textSecondary,
            size: 18,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              tx.description ??
                  (credit ? 'Cộng tiền vào ví' : 'Trừ tiền từ ví'),
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
        Text(
          '${credit ? '+' : '-'}${Fmt.currency(tx.amount)}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: credit ? AppColors.success : AppColors.textSecondary,
          ),
        ),
      ]),
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
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyEarnings({
    this.icon = Icons.bar_chart_rounded,
    this.title = 'Chưa có thu nhập',
    this.subtitle = 'Hoàn thành đơn để tích lũy thu nhập',
  });

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
              child: Icon(icon,
                  color: AppColors.primary.withValues(alpha: 0.5), size: 22),
            ),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                )),
            const SizedBox(height: 3),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textTertiary)),
          ]),
        ),
      );
}
