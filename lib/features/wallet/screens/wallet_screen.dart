import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bubble.dart';
import '../../../core/utils/formatters.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';

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
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // ── Gradient header ──────────────────────────────────
                _WalletHeader(
                  balance:      wallet.balance,
                  loading:      wallet.loading,
                  balanceError: wallet.balanceError,
                  onWithdraw:   () => _showWithdraw(context),
                ),

                // ── Cards ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Column(
                    children: [

                      _TransactionCard(
                        transactions: wallet.transactions,
                        loading:      wallet.loading,
                      ),

                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Sheets ─────────────────────────────────────────────────────────────────

  Future<void> _showWithdraw(BuildContext context) async {
    final wallet    = ref.read(walletProvider);
    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WithdrawSheet(
        bankAccount: wallet.bankAccount,
        onSubmit:    (amount) async {
          final ok = await ref.read(walletProvider.notifier).withdraw(amount);
          if (ok) await ref.read(walletProvider.notifier).fetch();
          messenger.showSnackBar(SnackBar(
            content: Text(ok ? 'Yêu cầu rút tiền đã được gửi' : 'Không thể gửi yêu cầu'),
            backgroundColor: ok ? AppColors.success : AppColors.danger,
          ));
          return ok;
        },
      ),
    );
  }

}

// ── Wallet header ─────────────────────────────────────────────────────────────

class _WalletHeader extends StatelessWidget {
  final int balance;
  final bool loading;
  final bool balanceError;
  final VoidCallback onWithdraw;

  const _WalletHeader({
    required this.balance,
    required this.loading,
    this.balanceError = false,
    required this.onWithdraw,
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
          // Decorative circles
          Positioned(top: -40, right: -40, child: Bubble(150, 0.07)),
          Positioned(top: 80,  left: -30,  child: Bubble(80,  0.05)),
          Positioned(bottom: 50, right: 40, child: Bubble(50, 0.04)),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, top + 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Topbar
                    SizedBox(
                      height: 48,
                      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        if (GoRouter.of(context).canPop()) ...[
                          GestureDetector(
                            onTap: () => GoRouter.of(context).pop(),
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
                        ],
                        const Text(
                          'Ví của tôi',
                          style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700,
                            color: Colors.white, letterSpacing: -0.2,
                          ),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 20),

                    // Balance
                    Text(
                      'Số dư ví',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 6),
                    loading
                        ? Container(
                            height: 42, width: 180,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          )
                        : Text(
                            Fmt.currency(balance),
                            style: const TextStyle(
                              color: Colors.white, fontSize: 38,
                              fontWeight: FontWeight.w900, letterSpacing: -1,
                            ),
                          ),

                    if (balanceError && !loading) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.wifi_off_rounded,
                            size: 13, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          'Không tải được số dư mới nhất — kéo xuống để thử lại',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.9)),
                        ),
                      ]),
                    ],

                    const SizedBox(height: 24),

                    // Action button
                    SizedBox(
                      width: double.infinity,
                      child: _HeaderBtn(
                        icon: Icons.arrow_upward_rounded,
                        label: 'Rút tiền',
                        filled: true,
                        onTap: onWithdraw,
                      ),
                    ),
                  ],
                ),
              ),

              Container(height: 20, color: AppColors.background),
            ],
          ),
        ],
      ),
    );
  }
}


class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: filled ? Colors.white : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: filled ? null : Border.all(color: Colors.white.withValues(alpha: 0.5)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: filled ? AppColors.primary : Colors.white),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: filled ? AppColors.primary : Colors.white,
              ),
            ),
          ]),
        ),
      );
}


// ── Transaction card ──────────────────────────────────────────────────────────

class _TransactionCard extends StatelessWidget {
  final List<WalletTransaction> transactions;
  final bool loading;

  const _TransactionCard({required this.transactions, required this.loading});

  String _dateLabel(DateTime dt) {
    final now       = DateTime.now();
    final local     = dt.toLocal();
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d         = DateTime(local.year, local.month, local.day);
    if (d == today) return 'Hôm nay';
    if (d == yesterday) return 'Hôm qua';
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  List<Object> _grouped() {
    final groups = <String, List<WalletTransaction>>{};
    final keys   = <String>[];
    for (final tx in transactions) {
      final key = _dateLabel(tx.createdAt);
      if (!groups.containsKey(key)) { groups[key] = []; keys.add(key); }
      groups[key]!.add(tx);
    }
    final items = <Object>[];
    for (final k in keys) { items.add(k); items.addAll(groups[k]!); }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(children: [
              const Text(
                'Lịch sử giao dịch',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ]),
          ),

          const Divider(height: 1, color: AppColors.divider),

          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2)),
            )
          else if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_outlined,
                        size: 28, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 12),
                  const Text('Chưa có giao dịch nào',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  const Text('Các giao dịch sẽ hiển thị ở đây',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
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
                  widgets.add(Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ));
                } else {
                  final tx   = item as WalletTransaction;
                  final next = i + 1 < grouped.length ? grouped[i + 1] : null;
                  widgets.add(_TxItem(tx: tx));
                  if (next is WalletTransaction) {
                    widgets.add(const Divider(
                        height: 1, indent: 76, endIndent: 0,
                        color: AppColors.divider));
                  }
                }
              }
              return widgets;
            }(),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TxItem extends StatelessWidget {
  final WalletTransaction tx;
  const _TxItem({required this.tx});

  Color get _color    => tx.isCredit ? AppColors.success : AppColors.danger;
  Color get _bgColor  => tx.isCredit
      ? const Color(0xFFECFDF5)
      : const Color(0xFFFEF2F2);
  IconData get _icon  => tx.isCredit
      ? Icons.south_rounded
      : Icons.north_rounded;

  @override
  Widget build(BuildContext context) {
    final local   = tx.createdAt.toLocal();
    final timeStr = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final sign    = tx.isCredit ? '+' : '-';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(children: [

        // Circle avatar
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: _bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(_icon, color: _color, size: 20),
        ),

        const SizedBox(width: 14),

        // Description + time
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                timeStr,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // Amount
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$sign${Fmt.currency(tx.amount)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _color,
              ),
            ),
          ],
        ),

      ]),
    );
  }
}

// ── Withdraw sheet ────────────────────────────────────────────────────────────

class _WithdrawSheet extends ConsumerStatefulWidget {
  final BankAccount bankAccount;
  final Future<bool> Function(int amount) onSubmit;

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
    if (amount < 50000) {
      setState(() => _error = 'Số tiền tối thiểu là 50,000 đ');
      return;
    }
    // Đọc số dư mới nhất tại thời điểm bấm — không dùng snapshot lúc mở sheet,
    // tránh validate sai nếu số dư đổi trong lúc sheet đang mở.
    if (amount > ref.read(walletProvider).balance) {
      setState(() => _error = 'Số tiền vượt quá số dư khả dụng');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final ok = await widget.onSubmit(amount);
    if (mounted) {
      if (ok) {
        Navigator.of(context).pop();
      } else {
        setState(() { _loading = false; _error = 'Không thể gửi yêu cầu. Thử lại sau.'; });
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
    final bottom  = MediaQuery.of(context).viewInsets.bottom;
    final hasBank = !widget.bankAccount.isEmpty;
    // Watch trực tiếp — số dư luôn tươi kể cả khi thay đổi trong lúc sheet mở.
    final balance = ref.watch(walletProvider).balance;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Handle
        Center(child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 20),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(2),
          ),
        )),

        // Title
        Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_upward_rounded, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Rút tiền', style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
            )),
            Text('Số dư: ${Fmt.currency(balance)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ]),

        const SizedBox(height: 20),

        // Bank account info
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hasBank
                ? AppColors.success.withValues(alpha: 0.06)
                : AppColors.warning.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasBank
                  ? AppColors.success.withValues(alpha: 0.18)
                  : AppColors.warning.withValues(alpha: 0.25),
            ),
          ),
          child: hasBank
              ? Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_rounded,
                        size: 18, color: AppColors.success),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.bankAccount.bankName ?? '',
                        style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.bankAccount.accountNumber} · ${widget.bankAccount.accountHolder}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ])),
                  GestureDetector(
                    onTap: () { Navigator.pop(context); GoRouter.of(context).push('/bank-account'); },
                    child: const Icon(Icons.edit_rounded, size: 16, color: AppColors.textTertiary),
                  ),
                ])
              : Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Chưa liên kết tài khoản ngân hàng.\nVào Tài khoản → Ngân hàng để thiết lập.',
                        style: TextStyle(fontSize: 12, color: AppColors.warning, height: 1.4)),
                  ),
                ]),
        ),

        if (hasBank) ...[

          const SizedBox(height: 20),

          // Amount input
          const Text('Số tiền rút',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            onChanged: (_) => setState(() => _error = null),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: const TextStyle(fontSize: 18, color: AppColors.textTertiary),
              suffixText: 'VND',
              suffixStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              errorText: _error,
              errorStyle: const TextStyle(fontSize: 11, color: AppColors.danger),
            ),
          ),

          const SizedBox(height: 12),

          // Quick amount chips
          Wrap(spacing: 8, runSpacing: 8, children: [
            ..._quickAmounts
              .where((a) => a <= balance)
              .map((a) => GestureDetector(
                onTap: () => _setAmount(a),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(Fmt.currency(a).replaceAll(' đ', ''),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
              )),
            GestureDetector(
              onTap: () => _setAmount(balance),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Tất cả',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // Notice
          Row(children: [
            const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: 6),
            const Expanded(
              child: Text('Số dư bị trừ ngay · Hoàn lại nếu bị từ chối · Xử lý 1–2 ngày',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ),
          ]),

          const SizedBox(height: 20),

          // Submit
          SizedBox(
            width: double.infinity, height: 50,
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Gửi yêu cầu rút tiền',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),

        ] else ...[

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 48,
            child: FilledButton(
              onPressed: () { Navigator.pop(context); GoRouter.of(context).push('/bank-account'); },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Thêm tài khoản ngân hàng', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),

        ],

      ]),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

Widget _surfaceCard({required Widget child}) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      boxShadow: AppColors.cardShadow,
    ),
    child: child,
  );
}

