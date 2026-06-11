import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text('Công nợ',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(walletProvider.notifier).fetch(),
        child: wallet.loading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2))
            : wallet.debts.isEmpty
                ? _EmptyState()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      // Summary card
                      _SummaryCard(
                          debts: wallet.debts, balance: wallet.balance),
                      const SizedBox(height: 16),

                      // Debt list
                      ...wallet.debts.map((d) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _DebtCard(
                              debt: d,
                              balance: wallet.balance,
                              onPay: () => _payDebt(context, ref, d),
                            ),
                          )),
                    ],
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

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final List<DriverDebt> debts;
  final int balance;
  const _SummaryCard({required this.debts, required this.balance});

  @override
  Widget build(BuildContext context) {
    final total   = debts.fold(0, (s, d) => s + d.remaining);
    final overdue = debts.where((d) => d.isOverdue).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tổng còn nợ',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(Fmt.currency(total),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.danger)),
            ],
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${debts.length} khoản',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          if (overdue > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('$overdue quá hạn',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger)),
            ),
          ],
        ]),
      ]),
    );
  }
}

// ── Debt card ─────────────────────────────────────────────────────────────────

class _DebtCard extends StatelessWidget {
  final DriverDebt debt;
  final int balance;
  final VoidCallback onPay;
  const _DebtCard(
      {required this.debt, required this.balance, required this.onPay});

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

  bool get _canPay => balance >= debt.remaining;

  @override
  Widget build(BuildContext context) {
    final isOverdue   = debt.isOverdue;
    final statusColor = isOverdue ? AppColors.danger : AppColors.warning;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isOverdue
            ? Border.all(color: AppColors.danger.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top accent
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 11, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(_periodLabel,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                  ]),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isOverdue ? 'QUÁ HẠN' : 'CHƯA TT',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        letterSpacing: 0.5),
                  ),
                ),
              ]),

              if (debt.note != null) ...[
                const SizedBox(height: 8),
                Text(debt.note!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],

              const SizedBox(height: 14),

              Row(children: [
                Expanded(
                    child: _AmountItem(
                        label: 'Tổng phí',
                        value: Fmt.currency(debt.amount),
                        color: AppColors.textPrimary)),
                Container(
                    width: 1,
                    height: 30,
                    color: AppColors.divider,
                    margin: const EdgeInsets.symmetric(horizontal: 14)),
                Expanded(
                    child: _AmountItem(
                        label: 'Đã thanh toán',
                        value: Fmt.currency(debt.paidAmount),
                        color: AppColors.success)),
              ]),

              const SizedBox(height: 12),

              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 6,
                  backgroundColor: AppColors.divider.withValues(alpha: 0.8),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.success),
                ),
              ),

              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Còn lại',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                    Text(Fmt.currency(debt.remaining),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: statusColor)),
                  ]),
                  SizedBox(
                    height: 38,
                    width: 120,
                    child: FilledButton(
                      onPressed: onPay,
                      style: FilledButton.styleFrom(
                        backgroundColor: _canPay
                            ? AppColors.primary
                            : AppColors.textSecondary.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text('Thanh toán',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('Không có công nợ',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Bạn đã thanh toán đầy đủ',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ]),
      );
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _AmountItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _AmountItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      );
}

