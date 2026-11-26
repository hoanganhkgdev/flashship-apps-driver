import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/utils/formatters.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';
import 'debt_screen.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(walletProvider.notifier).fetch());
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppScreenHeader(
          title: 'Số dư ví',
          backgroundColor: AppColors.primary,
          subtitle: 'Ví tài xế · Quản lý thu chi',
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: IconButton(
                  tooltip: 'Làm mới số dư ví',
                  onPressed: wallet.loading
                      ? null
                      : () => ref.read(walletProvider.notifier).fetch(),
                  style: IconButton.styleFrom(
                    foregroundColor: AppBrand.ink,
                    padding: EdgeInsets.zero,
                  ),
                  icon: Container(
                    width: MediaQuery.textScalerOf(context).scale(18) * 1.25 +
                        3 +
                        MediaQuery.textScalerOf(context).scale(12) * 1.35,
                    height: MediaQuery.textScalerOf(context).scale(18) * 1.25 +
                        3 +
                        MediaQuery.textScalerOf(context).scale(12) * 1.35,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: wallet.loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppBrand.ink),
                          )
                        : const Icon(Icons.refresh_rounded, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => ref.read(walletProvider.notifier).fetch(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, 32 + MediaQuery.paddingOf(context).bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BalanceCard(
                    balance: wallet.balance,
                    loading: wallet.loading,
                    balanceError: wallet.balanceError,
                    onWithdraw: () => _showWithdraw(context),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DebtWarningBanner(debts: wallet.debts),
                  _BankAccountCard(
                    bankAccount: wallet.bankAccount,
                    onTap: () => context.push('/bank-account'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (wallet.withdrawRequests.isNotEmpty) ...[
                    _WithdrawRequestsCard(requests: wallet.withdrawRequests),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _TransactionCard(
                    transactions: wallet.transactions,
                    loading: wallet.loading,
                    hasMore: wallet.txHasMore,
                    loadingMore: wallet.txLoadingMore,
                    onLoadMore: () => ref
                        .read(walletProvider.notifier)
                        .loadMoreTransactions(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Sheets ─────────────────────────────────────────────────────────────────

  Future<void> _showWithdraw(BuildContext context) async {
    final wallet = ref.read(walletProvider);
    final messenger = ScaffoldMessenger.of(context);
    await showAppBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WithdrawSheet(
        bankAccount: wallet.bankAccount,
        onSubmit: (amount) async {
          final error =
              await ref.read(walletProvider.notifier).withdraw(amount);
          final ok = error == null;
          if (ok) await ref.read(walletProvider.notifier).fetch();
          messenger.showSnackBar(SnackBar(
            content: Text(ok ? 'Yêu cầu rút tiền đã được gửi' : error),
            backgroundColor: ok ? AppColors.success : AppColors.danger,
          ));
          return error;
        },
      ),
    );
  }
}

// ── Wallet header ─────────────────────────────────────────────────────────────

class _WalletCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const _WalletCard({
    required this.child,
    this.color = AppColors.surface,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.divider, width: 1.25),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      );
}

class _BalanceCard extends StatelessWidget {
  final int balance;
  final bool loading;
  final bool balanceError;
  final VoidCallback onWithdraw;

  const _BalanceCard({
    required this.balance,
    required this.loading,
    this.balanceError = false,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primarySoft, AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primary, width: 1.25),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: AppBrand.gradient,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: AppBrand.ink, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text('Số dư khả dụng',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppFontSize.base,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        if (loading)
          Container(
            height: 38,
            width: 180,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          )
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(Fmt.currency(balance),
                style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 36,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6)),
          ),
        if (balanceError && !loading) ...[
          const SizedBox(height: AppSpacing.sm),
          Text('Chưa tải được số dư mới nhất · Kéo xuống để thử lại',
              style:
                  TextStyle(fontSize: AppFontSize.sm, color: AppColors.danger)),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text('Số tiền hiện có trong ví của bạn',
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppBrand.gradient,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: FilledButton.icon(
              onPressed: onWithdraw,
              icon: const Icon(Icons.north_east_rounded, size: 20),
              label: const Text('Rút tiền'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: AppBrand.ink,
                shadowColor: Colors.transparent,
                elevation: 0,
                textStyle: AppTextStyles.bodyStrong,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Debt warning banner ───────────────────────────────────────────────────────

class _DebtWarningBanner extends StatelessWidget {
  final List<DriverDebt> debts;
  const _DebtWarningBanner({required this.debts});

  String get _subtitle {
    final count = debts.length;
    final penalty = debts.where((d) => d.isPenalty).toList();
    // Nợ phạt điểm luôn có hạn 24h cố định — ưu tiên hiện countdown của
    // khoản gấp nhất. Nợ phí tuần quá hạn thì chỉ "Quá hạn", không có mốc
    // giờ cụ thể để đếm ngược.
    if (penalty.isNotEmpty) {
      final soonest =
          penalty.reduce((a, b) => a.timeUntilDue < b.timeUntilDue ? a : b);
      final d = soonest.timeUntilDue;
      if (d.isNegative) return '$count khoản · Quá hạn thanh toán';
      if (d.inHours < 1) {
        return '$count khoản · còn ${d.inMinutes} phút để thanh toán';
      }
      return '$count khoản · còn ${d.inHours} giờ để thanh toán';
    }
    if (debts.any((d) => d.isOverdue)) {
      return '$count khoản · Quá hạn thanh toán';
    }
    return '$count khoản chưa thanh toán';
  }

  @override
  Widget build(BuildContext context) {
    if (debts.isEmpty) return const SizedBox.shrink();

    final total = debts.fold<int>(0, (s, d) => s + d.remaining);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: _WalletCard(
        color: AppColors.dangerSoft,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.sm + 2),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppColors.danger, size: 19),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text('Bạn đang có công nợ chưa thanh toán',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  )),
            ),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Fmt.currency(total),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(_subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.danger)),
                  ]),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const DebtScreen())),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Xem công nợ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded,
                      size: 16, color: Colors.white),
                ]),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _BankAccountCard extends StatelessWidget {
  final BankAccount bankAccount;
  final VoidCallback onTap;

  const _BankAccountCard({required this.bankAccount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasBank = !bankAccount.isEmpty;
    final account = bankAccount.accountNumber;
    final lastDigits = account == null || account.isEmpty
        ? null
        : (account.length > 4
            ? account.substring(account.length - 4)
            : account);
    return _WalletCard(
      onTap: onTap,
      color: AppColors.surface,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            Icons.account_balance_rounded,
            size: 20,
            color: AppBrand.ink,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Tài khoản nhận tiền',
              style: AppTextStyles.bodyStrong.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              hasBank
                  ? bankAccount.bankName ?? 'Ngân hàng'
                  : 'Chưa liên kết tài khoản ngân hàng',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(
                color: hasBank ? AppColors.textSecondary : AppColors.warning,
              ),
            ),
            if (hasBank && lastDigits != null) ...[
              const SizedBox(height: 6),
              Text('•••• $lastDigits',
                  style: AppTextStyles.bodyStrong
                      .copyWith(color: AppBrand.ink, letterSpacing: 1.5)),
            ],
          ]),
        ),
        const Icon(Icons.chevron_right_rounded,
            size: 20, color: AppColors.textTertiary),
      ]),
    );
  }
}

// ── Transaction card ──────────────────────────────────────────────────────────

/// Các yêu cầu rút tiền gần đây và trạng thái xử lý — trước đây tài xế chỉ
/// thấy dòng trừ tiền, không biết đang chờ, đã chuyển hay bị từ chối vì sao.
class _WithdrawRequestsCard extends StatelessWidget {
  final List<WithdrawRequestItem> requests;
  const _WithdrawRequestsCard({required this.requests});

  @override
  Widget build(BuildContext context) {
    final shown = requests.take(5).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider, width: 1.25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Yêu cầu rút tiền',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          for (final r in shown) _WithdrawRequestRow(request: r),
        ],
      ),
    );
  }
}

class _WithdrawRequestRow extends StatelessWidget {
  final WithdrawRequestItem request;
  const _WithdrawRequestRow({required this.request});

  @override
  Widget build(BuildContext context) {
    final r = request;
    final color = r.isApproved
        ? AppColors.success
        : r.isRejected
            ? AppColors.danger
            : AppColors.warning;
    final d = r.createdAt;
    String two(int v) => v.toString().padLeft(2, '0');
    final when =
        '${two(d.hour)}:${two(d.minute)} ${two(d.day)}/${two(d.month)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(Fmt.currency(r.amount),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(
                [
                  when,
                  if (r.bankName?.isNotEmpty == true) r.bankName!,
                  if (r.accountNumber?.isNotEmpty == true) r.accountNumber!,
                ].join(' · '),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            if (r.isRejected && r.rejectReason?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text('Lý do: ${r.rejectReason}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.danger, height: 1.35)),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: color.withValues(alpha: .65)),
          ),
          child: Text(r.statusLabel,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ),
      ]),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final List<WalletTransaction> transactions;
  final bool loading;
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback onLoadMore;

  const _TransactionCard({
    required this.transactions,
    required this.loading,
    this.hasMore = false,
    this.loadingMore = false,
    required this.onLoadMore,
  });

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(local.year, local.month, local.day);
    if (d == today) return 'Hôm nay';
    if (d == yesterday) return 'Hôm qua';
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  List<Object> _grouped() {
    final groups = <String, List<WalletTransaction>>{};
    final keys = <String>[];
    for (final tx in transactions) {
      final key = _dateLabel(tx.createdAt);
      if (!groups.containsKey(key)) {
        groups[key] = [];
        keys.add(key);
      }
      groups[key]!.add(tx);
    }
    final items = <Object>[];
    for (final k in keys) {
      items.add(k);
      items.addAll(groups[k]!);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return _WalletCard(
      color: AppColors.surface,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lịch sử giao dịch',
                      style: AppTextStyles.sectionTitle.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppBrand.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Theo dõi các khoản cộng và trừ trong ví',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),

          const Divider(height: 1, color: AppColors.divider),

          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2)),
            )
          else if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_outlined,
                        size: 28, color: AppBrand.ink),
                  ),
                  const SizedBox(height: 12),
                  const Text('Chưa có giao dịch nào',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  const Text('Các giao dịch sẽ hiển thị ở đây',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textTertiary)),
                ]),
              ),
            )
          else
            ...() {
              final grouped = _grouped();
              final widgets = <Widget>[];
              for (var i = 0; i < grouped.length; i++) {
                final item = grouped[i];
                if (item is String) {
                  widgets.add(Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
                    color: AppColors.primarySoft,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ));
                } else {
                  final tx = item as WalletTransaction;
                  final next = i + 1 < grouped.length ? grouped[i + 1] : null;
                  widgets.add(_TxItem(tx: tx));
                  if (next is WalletTransaction) {
                    widgets.add(const Divider(
                        height: 1,
                        indent: 76,
                        endIndent: 0,
                        color: AppColors.divider));
                  }
                }
              }
              return widgets;
            }(),

          if (!loading && hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Center(
                child: loadingMore
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                              color: AppColors.primary, strokeWidth: 2),
                        ),
                      )
                    : TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppBrand.ink,
                        ),
                        onPressed: onLoadMore,
                        icon: const Icon(Icons.expand_more_rounded),
                        label: const Text('Xem thêm giao dịch'),
                      ),
              ),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TxItem extends StatelessWidget {
  final WalletTransaction tx;
  const _TxItem({required this.tx});

  Color get _color => tx.isCredit ? AppColors.success : AppColors.danger;
  Color get _bgColor =>
      tx.isCredit ? AppColors.successSoft : AppColors.dangerSoft;
  IconData get _icon => tx.isCredit ? Icons.south_rounded : Icons.north_rounded;

  @override
  Widget build(BuildContext context) {
    final local = tx.createdAt.toLocal();
    final timeStr =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final sign = tx.isCredit ? '+' : '-';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          ),
          child: Icon(_icon, color: _color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tx.description ?? (tx.isCredit ? 'Nhận tiền' : 'Trừ tiền'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Text(timeStr,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textTertiary)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text('$sign${Fmt.currency(tx.amount)}',
                        style:
                            AppTextStyles.sectionTitle.copyWith(color: _color)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Withdraw sheet ────────────────────────────────────────────────────────────

class _WithdrawSheet extends ConsumerStatefulWidget {
  final BankAccount bankAccount;
  final Future<String?> Function(int amount) onSubmit;

  const _WithdrawSheet({
    required this.bankAccount,
    required this.onSubmit,
  });

  @override
  ConsumerState<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends ConsumerState<_WithdrawSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  static const _quickAmounts = [50000, 100000, 200000, 500000];

  void _setAmount(int amount) {
    _ctrl.text = Fmt.currency(amount).replaceAll(' đ', '');
    setState(() => _error = null);
  }

  int get _parsedAmount {
    final raw = _ctrl.text.replaceAll('.', '').replaceAll(',', '').trim();
    return int.tryParse(raw) ?? 0;
  }

  Future<void> _submit() async {
    final amount = _parsedAmount;
    // Đọc số liệu mới nhất tại thời điểm bấm — không dùng snapshot lúc mở
    // sheet, tránh validate sai nếu số dư đổi trong lúc sheet đang mở.
    final w = ref.read(walletProvider);
    if (amount < w.minWithdraw) {
      setState(
          () => _error = 'Số tiền tối thiểu là ${Fmt.currency(w.minWithdraw)}');
      return;
    }
    if (amount > w.maxWithdraw) {
      setState(
          () => _error = 'Mỗi lần rút tối đa ${Fmt.currency(w.maxWithdraw)}');
      return;
    }
    if (amount > w.withdrawable) {
      setState(() => _error = w.overdueDebt > 0
          ? 'Chỉ rút được ${Fmt.currency(w.withdrawable)} vì còn nợ quá hạn ${Fmt.currency(w.overdueDebt)}'
          : 'Số tiền vượt quá số dư khả dụng');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await widget.onSubmit(amount);
    if (mounted) {
      if (error == null) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasBank = !widget.bankAccount.isEmpty;
    // Watch trực tiếp — số dư luôn tươi kể cả khi thay đổi trong lúc sheet mở.
    final wallet = ref.watch(walletProvider);
    final balance = wallet.balance;
    // Mức rút được ngay: trừ nợ quá hạn, không quá giới hạn mỗi lần.
    final limit = wallet.withdrawLimit;

    return AppBottomSheetBody(
      topPadding: 0,
      bottomPadding: 24,
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: AppBottomSheetHeader(
                title: 'Rút tiền',
                subtitle: wallet.overdueDebt > 0
                    ? 'Số dư: ${Fmt.currency(balance)} · Rút được: ${Fmt.currency(wallet.withdrawable)}'
                    : 'Số dư: ${Fmt.currency(balance)}',
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),

            const SizedBox(height: 20),

            // Bank account info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: hasBank
                    ? const Color(0xFFDBF5E1)
                    : AppColors.warning.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasBank
                      ? const Color(0xFFAEDDBA)
                      : AppColors.warning.withValues(alpha: 0.25),
                ),
              ),
              child: hasBank
                  ? Row(children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC5EBD0),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance_rounded,
                            size: 18, color: Color(0xFF1B1411)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(widget.bankAccount.bankName ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1B1411),
                                )),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.bankAccount.accountNumber} · ${widget.bankAccount.accountHolder}',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF6A605C)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ])),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          GoRouter.of(context).push('/bank-account');
                        },
                        child: const Icon(Icons.edit_rounded,
                            size: 16, color: Color(0xFF1B1411)),
                      ),
                    ])
                  : Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.warning, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                            'Chưa liên kết tài khoản ngân hàng.\nVào Tài khoản → Ngân hàng để thiết lập.',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.warning,
                                height: 1.4)),
                      ),
                    ]),
            ),

            if (hasBank) ...[
              const SizedBox(height: 20),

              // Amount input
              const Text('Số tiền rút',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() => _error = null),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1411)),
                decoration: appSheetInputDecoration(
                  hint: '0',
                  suffixText: 'VND',
                  errorText: _error,
                ),
              ),

              const SizedBox(height: 12),

              // Quick amount chips
              Wrap(spacing: 8, runSpacing: 8, children: [
                ..._quickAmounts
                    .where((a) => a >= wallet.minWithdraw && a <= limit)
                    .map((a) => GestureDetector(
                          onTap: () => _setAmount(a),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: _parsedAmount == a
                                  ? AppColors.primarySoft
                                  : AppColors.surfaceAlt,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                              border: Border.all(
                                  color: _parsedAmount == a
                                      ? AppColors.primary
                                      : AppColors.divider),
                            ),
                            child: Text(Fmt.currency(a).replaceAll(' đ', ''),
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _parsedAmount == a
                                        ? AppBrand.ink
                                        : const Color(0xFF1B1411))),
                          ),
                        )),
                if (limit >= wallet.minWithdraw)
                  GestureDetector(
                    onTap: () => _setAmount(limit),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: _parsedAmount == limit
                            ? AppColors.primarySoft
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: Text(limit < balance ? 'Tối đa' : 'Tất cả',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppBrand.ink)),
                    ),
                  ),
              ]),

              if (wallet.overdueDebt > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Còn nợ quá hạn ${Fmt.currency(wallet.overdueDebt)}: số này được giữ lại trong ví, bạn rút được tối đa ${Fmt.currency(wallet.withdrawable)}. Thanh toán nợ để rút toàn bộ.',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.warning, height: 1.4),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Notice
              Row(children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: Color(0xFF1B1411)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                      'Số dư bị trừ ngay · Hoàn lại nếu bị từ chối · Xử lý 1–2 ngày',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6A605C))),
                ),
              ]),

              const SizedBox(height: 20),

              // Submit
              AppSheetButton(
                brandStyle: true,
                label: 'Gửi yêu cầu rút tiền',
                loading: _loading,
                onPressed: _submit,
              ),
            ] else ...[
              const SizedBox(height: 16),
              AppSheetButton(
                brandStyle: true,
                label: 'Thêm tài khoản ngân hàng',
                onPressed: () {
                  Navigator.pop(context);
                  GoRouter.of(context).push('/bank-account');
                },
              ),
            ],
          ]),
    );
  }
}
