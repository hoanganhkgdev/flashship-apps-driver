import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/wallet_model.dart';
import '../providers/earnings_orders_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/payment_qr_sheet.dart';
import 'debt_screen.dart';
import '../../orders/models/order_model.dart';
import '../../orders/providers/order_provider.dart' show OrderHistoryState;
import '../../orders/widgets/order_card_parts.dart';
import '../../home/widgets/bottom_nav.dart';
import '../../home/widgets/finance_card.dart';

/// Màn Thu nhập: tổng theo kỳ (hôm nay / tuần / tháng), biểu đồ theo ngày,
/// công nợ, và danh sách đơn hoàn thành TRONG KỲ (lọc ở server).
class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  EarningsPeriod _period = EarningsPeriod.week;
  // "Hôm nay" và "Tuần này" dùng chung dữ liệu tuần; chỉ "Tháng này" gọi
  // earnings/monthly — tránh tải lại thừa khi chuyển qua lại 2 tab đầu.
  bool _chartMonthly = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        ref.read(walletProvider.notifier).fetchDailyEarnings(monthly: false));
  }

  void _onPeriod(EarningsPeriod p) {
    setState(() => _period = p);
    final monthly = p == EarningsPeriod.month;
    if (monthly != _chartMonthly) {
      _chartMonthly = monthly;
      ref.read(walletProvider.notifier).fetchDailyEarnings(monthly: monthly);
    }
  }

  EarningsSummary _summary(WalletState w) => switch (_period) {
        EarningsPeriod.today => w.earningsToday,
        EarningsPeriod.week => w.earningsWeekly,
        EarningsPeriod.month => w.earningsMonthly,
      };

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(walletProvider.notifier).fetch(),
      ref
          .read(walletProvider.notifier)
          .fetchDailyEarnings(monthly: _period == EarningsPeriod.month),
      ref.read(earningsOrdersProvider(_period).notifier).fetch(refresh: true),
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

  void _openDebts() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const DebtScreen()));

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final orders = ref.watch(earningsOrdersProvider(_period));
    final summary = _summary(wallet);
    // Khoản phạt hạn 24h — khẩn nhất, hiện tối đa 1 khối. Các khoản khác đã
    // nằm trong thẻ tài chính (bấm vào để xem công nợ).
    final urgent = wallet.debts.where((d) => d.isPenalty).firstOrNull;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(children: [
          _EarningsHeader(onWalletTap: () => context.push('/wallet')),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
                    AppSpacing.lg, BottomNav.reservedHeight(context)),
                children: [
                  _PeriodTabs(period: _period, onPeriod: _onPeriod),
                  const SizedBox(height: AppSpacing.md),
                  _HeroCard(
                    summary: summary,
                    loading: wallet.earningsSummaryLoading,
                    period: _period,
                  ),
                  if (urgent != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _UrgentDebtCard(
                        debt: urgent, onPay: () => _payDebt(urgent)),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  FinanceCard(
                    balance: wallet.balance,
                    debtPending:
                        wallet.debts.fold<int>(0, (s, d) => s + d.remaining),
                    debtCount: wallet.debts.length,
                    onWalletTap: () => context.push('/wallet'),
                    onDebtTap: _openDebts,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DailyChart(
                    data: wallet.dailyEarnings,
                    loading: wallet.dailyEarningsLoading,
                    monthly: _period == EarningsPeriod.month,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _PeriodOrders(
                    state: orders,
                    period: _period,
                    totalOrders: summary.orders,
                    onLoadMore: () => ref
                        .read(earningsOrdersProvider(_period).notifier)
                        .fetch(),
                    onOpenWallet: () => context.push('/wallet'),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _EarningsHeader extends StatelessWidget {
  final VoidCallback onWalletTap;

  const _EarningsHeader({required this.onWalletTap});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          MediaQuery.paddingOf(context).top + 10,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        decoration: BoxDecoration(
          gradient: AppBrand.gradient,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppRadius.lg),
          ),
          border: const Border(bottom: BorderSide(color: AppColors.primary)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  const TextSpan(children: [
                    TextSpan(text: 'Thu '),
                    TextSpan(
                      text: 'nhập',
                      style: TextStyle(color: AppBrand.ink),
                    ),
                  ]),
                  style: AppTextStyles.screenTitle.copyWith(
                    fontSize: AppFontSize.xl2,
                    color: AppBrand.ink,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(children: [
                  const Icon(Icons.insights_rounded,
                      size: 14, color: AppBrand.ink),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Theo dõi hiệu quả và dòng tiền của bạn',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppBrand.ink,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Material(
            color: Colors.white.withValues(alpha: .82),
            elevation: 1,
            shadowColor: AppColors.primary.withValues(alpha: .16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(
                color: AppBrand.ink.withValues(alpha: .35),
              ),
            ),
            child: InkWell(
              onTap: onWalletTap,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      size: 18, color: AppBrand.ink),
                  const SizedBox(width: 5),
                  Text('Ví',
                      style: AppTextStyles.label.copyWith(
                        color: AppBrand.ink,
                        fontWeight: FontWeight.w700,
                      )),
                ]),
              ),
            ),
          ),
        ]),
      );
}

// ── Chọn kỳ ──────────────────────────────────────────────────────────────────

class _PeriodTabs extends StatelessWidget {
  final EarningsPeriod period;
  final ValueChanged<EarningsPeriod> onPeriod;

  const _PeriodTabs({required this.period, required this.onPeriod});

  static const _labels = {
    EarningsPeriod.today: 'Hôm nay',
    EarningsPeriod.week: 'Tuần này',
    EarningsPeriod.month: 'Tháng này',
  };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.divider, width: 1.25),
        ),
        child: Row(children: [
          for (final p in EarningsPeriod.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onPeriod(p),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: AppDuration.fast,
                  constraints: const BoxConstraints(minHeight: 40),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: p == period ? AppBrand.gradient : null,
                    color: p == period ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    boxShadow: p == period
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: .2),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    _labels[p]!,
                    style: AppTextStyles.label.copyWith(
                      color:
                          p == period ? AppBrand.ink : AppColors.textSecondary,
                      fontWeight:
                          p == period ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ]),
      );
}

// ── Tổng thu nhập ─────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final EarningsSummary summary;
  final bool loading;
  final EarningsPeriod period;

  const _HeroCard({
    required this.summary,
    required this.loading,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    final average =
        summary.orders == 0 ? 0 : (summary.total / summary.orders).round();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider, width: 1.25),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'THU NHẬP ${period.label.toUpperCase()}',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
            letterSpacing: .8,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        if (loading)
          Container(
            height: 36,
            width: 170,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
          )
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Fmt.currency(summary.total),
              style: AppTextStyles.metricLarge.copyWith(
                color: AppColors.success,
                fontSize: 34,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          Expanded(
            child: _HeroStat(
              label: 'Đơn hoàn thành',
              value: loading ? '—' : '${summary.orders}',
            ),
          ),
          Container(width: 1, height: 30, color: AppColors.divider),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _HeroStat(
              label: 'Trung bình / đơn',
              value: loading ? '—' : Fmt.currency(average),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTextStyles.bodyStrong.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
}

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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.danger, width: 1.25),
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
              Text(debt.penaltyTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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
        LayoutBuilder(builder: (context, constraints) {
          final amount = Text(
            Fmt.currency(debt.remaining),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
              letterSpacing: -0.3,
            ),
          );
          final button = SizedBox(
            height: 42,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppBrand.gradient,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: FilledButton.icon(
                onPressed: onPay,
                icon: const Icon(Icons.qr_code_rounded,
                    size: 16, color: AppBrand.ink),
                label: const Text('Thanh toán',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppBrand.ink,
                    )),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppBrand.ink,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          );
          if (constraints.maxWidth < 340) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                amount,
                const SizedBox(height: AppSpacing.sm),
                button,
              ],
            );
          }
          return Row(children: [amount, const Spacer(), button]);
        }),
      ]),
    );
  }
}

// ── Weekly fee row (phí tuần thường, hạn cuối tuần) ─────────────────────────

// ── Biểu đồ theo ngày ─────────────────────────────────────────────────────────

/// Cột theo ngày; bấm một cột để xem số tiền ngày đó (mặc định là hôm nay).
/// Biểu đồ tháng tự cuộn tới hôm nay.
class _DailyChart extends StatefulWidget {
  final List<DailyEarning> data;
  final bool loading;
  final bool monthly;

  const _DailyChart({
    required this.data,
    required this.loading,
    required this.monthly,
  });

  @override
  State<_DailyChart> createState() => _DailyChartState();
}

class _DailyChartState extends State<_DailyChart> {
  static const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const _weekdayNames = [
    'Thứ 2',
    'Thứ 3',
    'Thứ 4',
    'Thứ 5',
    'Thứ 6',
    'Thứ 7',
    'Chủ nhật'
  ];
  static const _barArea = 84.0;

  final _scroll = ScrollController();
  DateTime? _selected;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void didUpdateWidget(covariant _DailyChart old) {
    super.didUpdateWidget(old);
    if (old.monthly != widget.monthly) _selected = null;
    _scrollToToday();
  }

  @override
  void initState() {
    super.initState();
    _scrollToToday();
  }

  void _scrollToToday() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final i = widget.data.indexWhere((d) => _sameDay(d.date, DateTime.now()));
      if (i < 0) return;
      final target = (i * 34.0) - 120;
      _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final card = BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.divider, width: 1.25),
    );
    if (widget.loading && data.isEmpty) {
      return Container(
        height: 170,
        decoration: card,
        child: const Center(
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2)),
      );
    }
    if (data.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final selected = data.firstWhere(
      (d) => _sameDay(d.date, _selected ?? now),
      orElse: () => data.last,
    );
    final maxTotal = data.fold<int>(0, (m, d) => d.total > m ? d.total : m);
    final d = selected.date;
    final dayLabel = _sameDay(d, now)
        ? 'Hôm nay'
        : '${_weekdayNames[d.weekday - 1]}, ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

    Widget bar(DailyEarning e, double width) {
      final isSel = _sameDay(e.date, selected.date);
      final isFuture = e.date.isAfter(now);
      final frac = maxTotal == 0 ? 0.0 : (e.total / maxTotal).clamp(0.0, 1.0);
      return GestureDetector(
        onTap: () => setState(() => _selected = e.date),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: width,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              height: _barArea,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: AppDuration.normal,
                  height:
                      e.total == 0 ? 4 : (_barArea * frac).clamp(6.0, _barArea),
                  width: widget.monthly ? 14 : 22,
                  decoration: BoxDecoration(
                    color: isSel
                        ? AppColors.success
                        : isFuture
                            ? AppColors.divider
                            : const Color(0xFF729B80),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: AppColors.success.withValues(alpha: .2),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.monthly ? '${e.date.day}' : _weekdays[e.date.weekday - 1],
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                color: isSel ? AppColors.success : AppColors.textTertiary,
              ),
            ),
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: card,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.monthly
                      ? 'Theo ngày · tháng này'
                      : 'Theo ngày · tuần này',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dayLabel,
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Text(
            Fmt.currency(selected.total),
            style: AppTextStyles.metric.copyWith(
              color: AppColors.success,
              fontSize: AppFontSize.xl,
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(builder: (_, c) {
          // Đo bề rộng thật thay vì tin cờ `monthly`: lúc đổi kỳ, dữ liệu kỳ
          // cũ có thể còn 1 nhịp — Row cố định nhận 30 cột sẽ tràn.
          final perBar = c.maxWidth / data.length;
          if (perBar >= 34) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [for (final e in data) bar(e, perBar - 2)],
            );
          }
          return SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: Row(children: [for (final e in data) bar(e, 34)]),
          );
        }),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Bấm vào cột để xem từng ngày',
          style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
        ),
      ]),
    );
  }
}

// ── Đơn hoàn thành trong kỳ ───────────────────────────────────────────────────

class _PeriodOrders extends StatelessWidget {
  final OrderHistoryState state;
  final EarningsPeriod period;
  final int totalOrders;
  final VoidCallback onLoadMore;
  final VoidCallback onOpenWallet;

  const _PeriodOrders({
    required this.state,
    required this.period,
    required this.totalOrders,
    required this.onLoadMore,
    required this.onOpenWallet,
  });

  @override
  Widget build(BuildContext context) {
    final orders = state.orders;
    final loading = state.loading;
    final hasMore = state.hasMore;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider, width: 1.25),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
          child: Row(children: [
            Expanded(
              child: Text(
                'Đơn hoàn thành ${period.label}',
                style: AppTextStyles.sectionTitle.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (orders.isNotEmpty)
              Text(
                hasMore && totalOrders > orders.length
                    ? '${orders.length}/$totalOrders đơn'
                    : '${orders.length} đơn',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
          for (var i = 0; i < orders.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 68, color: AppColors.divider),
            _OrderRow(order: orders[i]),
          ],
          if (hasMore)
            Center(
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 2),
                      ),
                    )
                  : TextButton.icon(
                      style:
                          TextButton.styleFrom(foregroundColor: AppBrand.ink),
                      onPressed: onLoadMore,
                      icon: const Icon(Icons.expand_more_rounded),
                      label: const Text('Xem thêm đơn'),
                    ),
            ),
        ],
        const Divider(height: 1, color: AppColors.divider),
        // Giao dịch ví đầy đủ ở màn Ví — không lặp một bản rút gọn ở đây.
        InkWell(
          onTap: onOpenWallet,
          borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppRadius.card)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: AppBrand.gradient,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    size: 17, color: AppBrand.ink),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Xem giao dịch ví (tiền vào/ra, rút tiền)',
                  style: AppTextStyles.label.copyWith(
                    color: AppBrand.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppBrand.ink),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final OrderModel order;
  const _OrderRow({required this.order});

  Color get _accent => order.isShopOrder
      ? AppColors.secondary
      : order.isCallCenter
          ? AppColors.primary
          : Fmt.serviceColor(order.serviceType);

  IconData get _icon => order.isShopOrder
      ? Icons.storefront_rounded
      : order.isCallCenter
          ? Icons.support_agent_rounded
          : Fmt.serviceIcon(order.serviceType);

  /// Diễn giải "Bạn nhận" — cùng cách với thẻ đơn (phụ phí đêm đã nằm trong
  /// phí ship nên không cộng thêm; có phần công ty bù voucher).
  String get _earnNote {
    final fee = feeWord(order.serviceType);
    return <String>[
      order.platformFreeship
          ? 'cty trả $fee ${moneyShort(order.shippingFee)}'
          : '$fee ${moneyShort(order.shippingFee)}',
      if (order.discountAmount > 0)
        'bù voucher ${moneyShort(order.discountAmount)}',
      if (order.bonusFee > 0) 'thưởng ${moneyShort(order.bonusFee)}',
      if (order.rainBonusEligible && order.rainBonusConfirmedAmount > 0)
        'mưa ${moneyShort(order.rainBonusConfirmedAmount)}',
    ].join(' + ');
  }

  String get _when {
    final d = (order.completedAt ?? order.createdAt).toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    final now = DateTime.now();
    final sameDay =
        d.year == now.year && d.month == now.month && d.day == now.day;
    return sameDay
        ? '${two(d.hour)}:${two(d.minute)}'
        : '${two(d.hour)}:${two(d.minute)} · ${two(d.day)}/${two(d.month)}';
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: AppBrand.gradient,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: .18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(_icon, size: 20, color: AppBrand.ink),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order.isShopOrder ? order.displayTitle : Fmt.serviceLabel(order.serviceType)} #${order.code}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_when · $_earnNote',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 116),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: .65),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '+${Fmt.currency(order.driverEarning)}',
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ]),
      );
}

class _EmptyEarnings extends StatelessWidget {
  const _EmptyEarnings();

  static const icon = Icons.bar_chart_rounded;
  static const title = 'Chưa có đơn hoàn thành trong kỳ';
  static const subtitle = 'Hoàn thành đơn để tích lũy thu nhập';

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
              child: Icon(icon, color: AppColors.primaryDark, size: 22),
            ),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                  fontSize: 14,
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
