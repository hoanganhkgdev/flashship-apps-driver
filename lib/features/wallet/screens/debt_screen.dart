import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';
import '../widgets/payment_qr_sheet.dart';

class DebtScreen extends ConsumerWidget {
  const DebtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final total = wallet.debts.fold(0, (s, d) => s + d.remaining);
    final overdue = wallet.debts.where((d) => d.isOverdue).length;
    final urgentCount = wallet.debts.where((d) => d.isScorePenalty).length;

    // Sắp theo mức khẩn cấp — không sort thẳng wallet.debts để tránh mutate
    // in-place list gốc trong provider state (nhiều widget khác cũng đọc nó).
    final debts = [...wallet.debts]..sort((a, b) {
        if (a.isScorePenalty != b.isScorePenalty) {
          return a.isScorePenalty ? -1 : 1;
        }
        if (a.isScorePenalty) {
          // Cùng là phạt điểm — sắp gần hết hạn 24h nhất lên trước.
          return a.timeUntilDue.compareTo(b.timeUntilDue);
        }
        // Cùng là phí tuần — quá hạn trước, rồi tới gần week_end nhất.
        if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
        return (a.weekEnd ?? '').compareTo(b.weekEnd ?? '');
      });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const AppScreenHeader(title: 'Công nợ'),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => ref.read(walletProvider.notifier).fetch(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Gradient header ────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
                sliver: SliverToBoxAdapter(
                  child: _Header(
                    total: total,
                    count: debts.length,
                    overdue: overdue,
                    urgent: urgentCount,
                    loading: wallet.loading,
                  ),
                ),
              ),

              // ── Body ───────────────────────────────────────────────────
              if (wallet.loading)
                const SliverFillRemaining(
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2)),
                )
              else if (debts.isEmpty)
                SliverFillRemaining(
                  child: EmptyState(
                    icon: Icons.check_circle_rounded,
                    iconColor: AppColors.success,
                    iconBgColor: AppColors.success.withValues(alpha: 0.08),
                    title: 'Không có công nợ',
                    subtitle: 'Bạn đã thanh toán đầy đủ 🎉',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl4),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DebtCard(
                          debt: debts[i],
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

  Future<void> _payDebt(
      BuildContext context, WidgetRef ref, DriverDebt debt) async {
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
  final int total, count, overdue, urgent;
  final bool loading;

  const _Header({
    required this.total,
    required this.count,
    required this.overdue,
    required this.urgent,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC92A32), Color(0xFFE5483F), Color(0xFFF06A45)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.raised,
      ),
      child: loading
          ? Container(
              height: 42,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Text(
                    'Tổng công nợ',
                    style: TextStyle(
                      fontSize: AppFontSize.base,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  Fmt.currency(total),
                  style: const TextStyle(
                    fontSize: AppFontSize.xl5,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _HeroChip(
                      icon: Icons.receipt_long_rounded,
                      label: '$count khoản',
                    ),
                    if (overdue > 0)
                      _HeroChip(
                        icon: Icons.error_outline_rounded,
                        label: '$overdue quá hạn',
                      ),
                    if (urgent > 0)
                      _HeroChip(
                        icon: Icons.bolt_rounded,
                        label: '$urgent khẩn cấp',
                        emphasized: true,
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool emphasized;

  const _HeroChip(
      {required this.icon, required this.label, this.emphasized = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: emphasized
              ? const Color(0xFFFFFEFD)
              : Colors.white.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 13,
              color: emphasized
                  ? const Color(0xFFD52E36)
                  : const Color(0xFF1B1411)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: emphasized ? const Color(0xFFD52E36) : Colors.white,
              )),
        ]),
      );
}

// ── Debt card ─────────────────────────────────────────────────────────────────

class _DebtCard extends StatelessWidget {
  final DriverDebt debt;
  final VoidCallback onPay;
  const _DebtCard({required this.debt, required this.onPay});

  static String _fmtDate(String d) {
    final parts = d.split('-');
    return parts.length < 3 ? d : '${parts[2]}/${parts[1]}';
  }

  String get _periodLabel {
    if (debt.weekStart == null || debt.weekEnd == null) return 'Chưa xác định';
    return '${_fmtDate(debt.weekStart!)} – ${_fmtDate(debt.weekEnd!)}';
  }

  double get _progress =>
      debt.amount == 0 ? 0 : (debt.paidAmount / debt.amount).clamp(0.0, 1.0);

  String _statusLabel(bool isPenalty, bool isOverdue) {
    if (isOverdue) return 'Quá hạn';
    if (isPenalty) {
      final d = debt.timeUntilDue;
      if (d.inHours < 1) return 'Còn ${d.inMinutes} phút';
      return 'Còn ${d.inHours} giờ';
    }
    return debt.weekEnd != null ? 'Hạn ${_fmtDate(debt.weekEnd!)}' : 'Chưa TT';
  }

  @override
  Widget build(BuildContext context) {
    final isPenalty = debt.isScorePenalty;
    final isOverdue = debt.isOverdue;
    final statusColor = isOverdue ? const Color(0xFFD52E36) : AppColors.warning;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFD),
        borderRadius: BorderRadius.circular(16),
        // Nợ phạt điểm luôn cần xử lý gấp hơn — border đỏ đậm bất kể đã quá
        // hạn hay chưa, để nổi bật hơn hẳn card phí tuần thường.
        border: isPenalty
            ? Border.all(color: AppColors.danger, width: 2)
            : (isOverdue
                ? Border.all(
                    color: AppColors.danger.withValues(alpha: 0.25), width: 1.5)
                : null),
        boxShadow: AppShadows.soft,
      ),
      child: Column(children: [
        // Card header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                // Type tag
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: isPenalty ? AppColors.danger : AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      isPenalty
                          ? Icons.bolt_rounded
                          : Icons.receipt_long_rounded,
                      size: 11,
                      color: isPenalty ? Colors.white : AppColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isPenalty ? 'Phạt điểm tuần' : 'Phí tuần',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isPenalty ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ]),
                ),
                // Period chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        )),
                  ]),
                ),
              ]),
            ),
            const SizedBox(width: 8),
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
                  size: 11,
                  color: statusColor,
                ),
                const SizedBox(width: 5),
                Text(
                  _statusLabel(isPenalty, isOverdue),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6A605C),
                    height: 1.4)),
          ),

        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFF5F5F5)),

        // 3-col amounts
        IntrinsicHeight(
          child: Row(children: [
            _AmountCol(
                label: 'Tổng phí',
                value: Fmt.currency(debt.amount),
                color: AppColors.textPrimary),
            Container(width: 1, color: const Color(0xFFF5F5F5)),
            _AmountCol(
                label: 'Đã thanh toán',
                value: Fmt.currency(debt.paidAmount),
                color: AppColors.success),
            Container(width: 1, color: const Color(0xFFF5F5F5)),
            _AmountCol(
                label: 'Còn lại',
                value: Fmt.currency(debt.remaining),
                color: statusColor),
          ]),
        ),

        const Divider(height: 1, color: Color(0xFFF5F5F5)),

        // Progress bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Tiến độ thanh toán',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6A605C))),
              Text('${(_progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _progress >= 1
                        ? AppColors.success
                        : AppColors.textSecondary,
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
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              // Phòng trường hợp amount_paid đã cập nhật nhưng status chưa kịp
              // đổi thành 'paid' — không cho tạo QR thanh toán 0đ.
              onPressed: debt.remaining > 0 ? onPay : null,
              icon: const Icon(Icons.qr_code_rounded,
                  size: 18, color: Colors.white),
              label: const Text(
                'Thanh toán qua PayOS',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00B956),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
  const _AmountCol(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6A605C),
                )),
            const SizedBox(height: 5),
            Text(value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                )),
          ]),
        ),
      );
}

// ── Empty state ───────────────────────────────────────────────────────────────
