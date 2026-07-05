import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';
import '../widgets/payment_qr_sheet.dart';

class DebtScreen extends ConsumerWidget {
  const DebtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final debts  = wallet.debts;
    final total  = debts.fold(0, (s, d) => s + d.remaining);
    final overdue = debts.where((d) => d.isOverdue).length;

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
          onRefresh: () => ref.read(walletProvider.notifier).fetch(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [

              // ── Gradient header ────────────────────────────────────────
              SliverToBoxAdapter(
                child: _Header(
                  total:   total,
                  count:   debts.length,
                  overdue: overdue,
                  loading: wallet.loading,
                ),
              ),

              // ── Body ───────────────────────────────────────────────────
              if (wallet.loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2)),
                )
              else if (debts.isEmpty)
                const SliverFillRemaining(child: _EmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DebtCard(
                          debt:  debts[i],
                          onPay: () => _payDebt(context, ref, debts[i]),
                        ),
                      ),
                      childCount: debts.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _payDebt(BuildContext context, WidgetRef ref, DriverDebt debt) async {
    final paid = await PaymentQrSheet.show(
      context,
      type: 'debt_payment',
      amount: debt.remaining,
      debtId: debt.id,
      label: 'Thanh toán công nợ',
    );
    if (context.mounted && paid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Thanh toán thành công!'),
        backgroundColor: AppColors.success,
      ));
    }
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int total, count, overdue;
  final bool loading;
  const _Header({
    required this.total, required this.count,
    required this.overdue, required this.loading,
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

          Column(children: [
            SizedBox(height: top),

            // Topbar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 48,
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Công nợ',
                      style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: -0.2,
                      )),
                ]),
              ),
            ),

            const SizedBox(height: 24),

            // Hero summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: loading
                  ? Container(
                      height: 52, width: 180,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tổng công nợ',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          Fmt.currency(total),
                          style: const TextStyle(
                            fontSize: 38, fontWeight: FontWeight.w900,
                            color: Colors.white, letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          _InfoChip(
                            icon: Icons.receipt_long_rounded,
                            label: '$count khoản',
                          ),
                          if (overdue > 0) ...[
                            const SizedBox(width: 8),
                            _InfoChip(
                              icon: Icons.warning_amber_rounded,
                              label: '$overdue quá hạn',
                              danger: true,
                            ),
                          ],
                        ]),
                      ],
                    ),
            ),

            const SizedBox(height: 24),
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  const _InfoChip({required this.icon, required this.label, this.danger = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: (danger ? Colors.red : Colors.white).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (danger ? Colors.red : Colors.white).withValues(alpha: 0.35),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
              )),
        ]),
      );
}

// ── Debt card ─────────────────────────────────────────────────────────────────

class _DebtCard extends StatelessWidget {
  final DriverDebt debt;
  final VoidCallback onPay;
  const _DebtCard({required this.debt, required this.onPay});

  String get _periodLabel {
    if (debt.weekStart == null || debt.weekEnd == null) return 'Chưa xác định';
    String fmt(String d) {
      final parts = d.split('-');
      return parts.length < 3 ? d : '${parts[2]}/${parts[1]}';
    }
    return '${fmt(debt.weekStart!)} – ${fmt(debt.weekEnd!)}';
  }

  double get _progress =>
      debt.amount == 0 ? 0 : (debt.paidAmount / debt.amount).clamp(0.0, 1.0);


  @override
  Widget build(BuildContext context) {
    final isOverdue   = debt.isOverdue;
    final statusColor = isOverdue ? AppColors.danger : AppColors.warning;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isOverdue
            ? Border.all(color: AppColors.danger.withValues(alpha: 0.25), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: [

        // Card header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            // Period chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 11, color: AppColors.textSecondary),
                const SizedBox(width: 5),
                Text(_periodLabel,
                    style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    )),
              ]),
            ),
            const Spacer(),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  isOverdue ? Icons.error_rounded : Icons.schedule_rounded,
                  size: 11, color: statusColor,
                ),
                const SizedBox(width: 5),
                Text(
                  isOverdue ? 'Quá hạn' : 'Chưa TT',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ]),
            ),
          ]),
        ),

        // Note
        if (debt.note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(debt.note!,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
          ),

        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFF5F5F5)),

        // 3-col amounts
        IntrinsicHeight(
          child: Row(children: [
            _AmountCol(label: 'Tổng phí',      value: Fmt.currency(debt.amount),     color: AppColors.textPrimary),
            Container(width: 1, color: const Color(0xFFF5F5F5)),
            _AmountCol(label: 'Đã thanh toán', value: Fmt.currency(debt.paidAmount), color: AppColors.success),
            Container(width: 1, color: const Color(0xFFF5F5F5)),
            _AmountCol(label: 'Còn lại',       value: Fmt.currency(debt.remaining),  color: statusColor),
          ]),
        ),

        const Divider(height: 1, color: Color(0xFFF5F5F5)),

        // Progress bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Tiến độ thanh toán',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text('${(_progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: _progress >= 1 ? AppColors.success : AppColors.textSecondary,
                  )),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 7,
                backgroundColor: const Color(0xFFEEEEEE),
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.success),
              ),
            ),
          ]),
        ),

        // Pay button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity, height: 46,
            child: FilledButton.icon(
              // Phòng trường hợp amount_paid đã cập nhật nhưng status chưa kịp
              // đổi thành 'paid' — không cho tạo QR thanh toán 0đ.
              onPressed: debt.remaining > 0 ? onPay : null,
              icon: const Icon(Icons.qr_code_rounded, size: 18, color: Colors.white),
              label: const Text(
                'Thanh toán qua PayOS',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00B14F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),

      ]),
    );
  }
}

class _AmountCol extends StatelessWidget {
  final String label, value;
  final Color color;
  const _AmountCol({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary,
                )),
            const SizedBox(height: 5),
            Text(value,
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: color,
                )),
          ]),
        ),
      );
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 40),
          ),
          const SizedBox(height: 16),
          const Text('Không có công nợ',
              style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              )),
          const SizedBox(height: 6),
          const Text('Bạn đã thanh toán đầy đủ 🎉',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ]),
      );
}
