import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';
import '../widgets/payment_qr_sheet.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _earningsTab;

  @override
  void initState() {
    super.initState();
    _earningsTab = TabController(length: 3, vsync: this);
    _earningsTab.addListener(() => setState(() {}));
    Future.microtask(() => ref.read(walletProvider.notifier).fetch());
  }

  @override
  void dispose() {
    _earningsTab.dispose();
    super.dispose();
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
                  balance:    wallet.balance,
                  loading:    wallet.loading,
                  onTopUp:    () => _showTopUp(context),
                  onWithdraw: () => _showWithdraw(context),
                ),

                // ── Cards ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Column(
                    children: [

                      _EarningsCard(
                        tabController: _earningsTab,
                        today:   wallet.earningsToday,
                        weekly:  wallet.earningsWeekly,
                        monthly: wallet.earningsMonthly,
                        loading: wallet.loading,
                      ),

                      const SizedBox(height: 12),

                      _BankCard(
                        bank:    wallet.bankAccount,
                        loading: wallet.loading,
                        onEdit:  () => _showBankEditor(context, wallet.bankAccount, wallet.bankList),
                      ),

                      const SizedBox(height: 12),

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

  Future<void> _showTopUp(BuildContext context) async {
    final ctrl = TextEditingController();
    final amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          const Text('Nạp tiền vào ví',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Quét QR để nạp tiền vào ví FlashShip',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Nhập số tiền (đ)',
              hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [50000, 100000, 200000, 500000].map((v) => GestureDetector(
              onTap: () => ctrl.text = v.toString(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(Fmt.currency(v),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () {
                final v = int.tryParse(ctrl.text.replaceAll(RegExp(r'\D'), ''));
                if (v == null || v < 10000) return;
                Navigator.pop(ctx, v);
              },
              child: const Text('Tạo QR thanh toán',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );

    if (amount == null || !context.mounted) return;
    final paid = await PaymentQrSheet.show(
      context, type: 'topup', amount: amount, label: 'Nạp ví FlashShip',
    );
    if (paid && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nạp tiền thành công!'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  Future<void> _showWithdraw(BuildContext context) async {
    final ctrl = TextEditingController();
    final balance = ref.read(walletProvider).balance;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          const Text('Rút tiền',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Row(children: [
            Text('Số dư: ${Fmt.currency(balance)}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(width: 8),
            const Text('·', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(width: 8),
            const Text('Xử lý 1–2 ngày làm việc',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 20),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Số tiền rút (tối thiểu 50,000đ)',
              hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Gửi yêu cầu',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final amount = int.tryParse(ctrl.text.replaceAll('.', '').replaceAll(',', '').trim()) ?? 0;
    if (amount < 50000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số tiền tối thiểu là 50,000 đ')),
      );
      return;
    }
    final ok = await ref.read(walletProvider.notifier).withdraw(amount);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Yêu cầu rút tiền đã được gửi' : 'Không thể gửi yêu cầu'),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ));
    }
  }

  Future<void> _showBankEditor(
    BuildContext context,
    BankAccount current,
    List<BankListItem> bankList,
  ) async {
    BankListItem? selectedBank = bankList.isEmpty ? null
        : bankList.where((b) => b.code == current.bankCode).firstOrNull
          ?? (current.bankName != null
              ? bankList.where((b) => b.name.toLowerCase().contains(current.bankName!.toLowerCase())).firstOrNull
              : null);

    final accountCtrl  = TextEditingController(text: current.accountNumber ?? '');
    final holderCtrl   = TextEditingController(text: current.accountHolder ?? '');
    final bankNameCtrl = TextEditingController(text: current.bankName ?? '');

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            Text(
              current.isEmpty ? 'Thêm tài khoản ngân hàng' : 'Cập nhật ngân hàng',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 20),

            _SheetLabel('Ngân hàng'),
            const SizedBox(height: 8),
            if (bankList.isNotEmpty)
              GestureDetector(
                onTap: () async {
                  final picked = await showDialog<BankListItem>(
                    context: ctx,
                    builder: (_) => _BankPickerDialog(banks: bankList, selected: selectedBank),
                  );
                  if (picked != null) setSt(() => selectedBank = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        selectedBank?.name ?? 'Chọn ngân hàng',
                        style: TextStyle(
                          fontSize: 15,
                          color: selectedBank != null ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 20),
                  ]),
                ),
              )
            else
              _FlatField(controller: bankNameCtrl, hint: 'Tên ngân hàng', textCapitalization: TextCapitalization.words),

            const SizedBox(height: 16),
            _SheetLabel('Số tài khoản'),
            const SizedBox(height: 8),
            _FlatField(controller: accountCtrl, hint: 'Nhập số tài khoản', keyboardType: TextInputType.number),

            const SizedBox(height: 16),
            _SheetLabel('Chủ tài khoản'),
            const SizedBox(height: 8),
            _FlatField(
              controller: holderCtrl,
              hint: 'NGUYEN VAN A',
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Lưu',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final bankName = bankList.isNotEmpty
        ? (selectedBank?.name ?? bankNameCtrl.text.trim())
        : bankNameCtrl.text.trim();
    final bankCode = bankList.isNotEmpty
        ? (selectedBank?.code ?? bankName.toUpperCase().replaceAll(' ', ''))
        : bankName.toUpperCase().replaceAll(' ', '');
    final account = accountCtrl.text.trim();
    final holder  = holderCtrl.text.trim();
    if (bankName.isEmpty || account.isEmpty || holder.isEmpty) return;

    final ok = await ref.read(walletProvider.notifier).updateBank(
      bankCode: bankCode,
      bankName: bankName,
      accountNumber: account,
      accountHolder: holder,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Cập nhật thành công' : 'Cập nhật thất bại'),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ));
    }
  }
}

// ── Bank picker dialog ────────────────────────────────────────────────────────

class _BankPickerDialog extends StatefulWidget {
  final List<BankListItem> banks;
  final BankListItem? selected;
  const _BankPickerDialog({required this.banks, this.selected});

  @override
  State<_BankPickerDialog> createState() => _BankPickerDialogState();
}

class _BankPickerDialogState extends State<_BankPickerDialog> {
  late List<BankListItem> _filtered;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.banks;
    _search.addListener(_onSearch);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.banks
          : widget.banks.where((b) => b.name.toLowerCase().contains(q) || b.code.toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(children: [
            const Text('Chọn ngân hàng',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Tìm ngân hàng...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF5F6FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final b = _filtered[i];
              final isSelected = b.code == widget.selected?.code;
              return ListTile(
                dense: true,
                title: Text(b.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    )),
                subtitle: Text(b.code,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                    : null,
                onTap: () => Navigator.pop(context, b),
              );
            },
          ),
        ),
      ]),
    ),
  );
}

// ── Wallet header ─────────────────────────────────────────────────────────────

class _WalletHeader extends StatelessWidget {
  final int balance;
  final bool loading;
  final VoidCallback onTopUp;
  final VoidCallback onWithdraw;

  const _WalletHeader({
    required this.balance,
    required this.loading,
    required this.onTopUp,
    required this.onWithdraw,
  });

  bool get _isLow => balance < 100000;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEF7C1A), AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Title
                const Text(
                  'Ví của tôi',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),

                const SizedBox(height: 24),

                // Balance label
                Text(
                  'Số dư ký quỹ',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),

                const SizedBox(height: 6),

                // Balance amount
                loading
                    ? Container(
                        height: 42, width: 160,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      )
                    : Text(
                        Fmt.currency(balance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),

                const SizedBox(height: 10),

                // Status badge
                if (!loading)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (_isLow ? Colors.amber : Colors.white).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (_isLow ? Colors.amber : Colors.white).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        _isLow ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _isLow ? 'Cần nạp thêm để nhận đơn' : 'Ví đủ điều kiện nhận đơn',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ]),
                  ),

                const SizedBox(height: 24),

                // Action buttons
                Row(children: [
                  Expanded(
                    child: _HeaderBtn(
                      icon: Icons.add_rounded,
                      label: 'Nạp tiền',
                      filled: true,
                      onTap: onTopUp,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HeaderBtn(
                      icon: Icons.arrow_upward_rounded,
                      label: 'Rút tiền',
                      filled: false,
                      onTap: onWithdraw,
                    ),
                  ),
                ]),
              ],
            ),
          ),

          // Curved bottom
          Container(
            height: 20,
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
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
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: filled ? AppColors.primary : Colors.white,
              ),
            ),
          ]),
        ),
      );
}

// ── Earnings card ─────────────────────────────────────────────────────────────

class _EarningsCard extends StatelessWidget {
  final TabController tabController;
  final EarningsSummary today;
  final EarningsSummary weekly;
  final EarningsSummary monthly;
  final bool loading;

  const _EarningsCard({
    required this.tabController,
    required this.today,
    required this.weekly,
    required this.monthly,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final summaries = [today, weekly, monthly];
    final labels    = ['Hôm nay', 'Tuần này', 'Tháng này'];
    final idx       = tabController.index;
    final current   = summaries[idx];

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Section header + tab
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              const Icon(Icons.trending_up_rounded, size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              const Text(
                'THU NHẬP',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              // Segmented tab
              SizedBox(
                width: 195,
                height: 30,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TabBar(
                    controller: tabController,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [BoxShadow(
                        color: const Color(0x14111827),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      )],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    padding: const EdgeInsets.all(2),
                    labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                    labelColor: AppColors.textPrimary,
                    unselectedLabelColor: AppColors.textSecondary,
                    tabs: labels.map((l) => Tab(text: l, height: 26)).toList(),
                  ),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.divider),

          // Earnings content
          Padding(
            padding: const EdgeInsets.all(16),
            child: loading
                ? const SizedBox(
                    height: 72,
                    child: Center(child: CircularProgressIndicator(color: AppColors.success, strokeWidth: 2)))
                : Row(children: [
                    // Primary stat
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            labels[idx],
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            Fmt.currency(current.total),
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.successSoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${current.orders} đơn',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),

                    // Mini comparison
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(3, (i) {
                        final isActive = i == idx;
                        final s = summaries[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (isActive)
                              Container(
                                width: 4, height: 4,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Text(
                              Fmt.currency(s.total),
                              style: TextStyle(
                                fontSize: isActive ? 14 : 12,
                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                                color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                              ),
                            ),
                          ]),
                        );
                      }),
                    ),
                  ]),
          ),
        ],
      ),
    );
  }
}

// ── Bank card ─────────────────────────────────────────────────────────────────

class _BankCard extends StatelessWidget {
  final BankAccount bank;
  final bool loading;
  final VoidCallback onEdit;

  const _BankCard({required this.bank, required this.loading, required this.onEdit});

  String _maskAccount(String? num) {
    if (num == null || num.length < 4) return num ?? '—';
    return '•••• ${num.substring(num.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              const Icon(Icons.account_balance_rounded, size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              const Text(
                'NGÂN HÀNG',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    bank.isEmpty ? 'Thêm' : 'Chỉnh sửa',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),

          if (loading)
            const SizedBox(
              height: 64,
              child: Center(child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))),
            )
          else if (bank.isEmpty)
            InkWell(
              onTap: onEdit,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.card)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_card_rounded, color: AppColors.info, size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Thêm tài khoản ngân hàng',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
                        SizedBox(height: 2),
                        Text('Để rút tiền thu nhập về tài khoản',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 20),
                ]),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_rounded, color: AppColors.info, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bank.bankName ?? '—',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        '${_maskAccount(bank.accountNumber)}  ·  ${bank.accountHolder ?? '—'}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ]),
            ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
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
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              Icon(Icons.receipt_long_rounded, size: 14, color: AppColors.textTertiary),
              SizedBox(width: 6),
              Text(
                'LỊCH SỬ GIAO DỊCH',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ]),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),

          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
            )
          else if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textTertiary),
                  SizedBox(height: 10),
                  Text('Chưa có giao dịch nào',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ));
                } else {
                  final tx   = item as WalletTransaction;
                  final next = i + 1 < grouped.length ? grouped[i + 1] : null;
                  widgets.add(_TxItem(tx: tx));
                  if (next is WalletTransaction) {
                    widgets.add(const Divider(height: 1, indent: 68, endIndent: 16, color: AppColors.divider));
                  }
                }
              }
              return widgets;
            }(),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _TxItem extends StatelessWidget {
  final WalletTransaction tx;
  const _TxItem({required this.tx});

  Color get _color => tx.isCredit ? AppColors.success : AppColors.danger;
  IconData get _icon => tx.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;

  @override
  Widget build(BuildContext context) {
    final local   = tx.createdAt.toLocal();
    final timeStr = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(_icon, color: _color, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tx.description ?? (tx.isCredit ? 'Nhận tiền' : 'Trừ tiền'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.access_time_rounded, size: 10, color: AppColors.textTertiary),
                const SizedBox(width: 3),
                Text(timeStr, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
              ]),
            ],
          ),
        ),
        Text(
          '${tx.isCredit ? '+' : '-'}${Fmt.currency(tx.amount)}',
          style: TextStyle(fontWeight: FontWeight.w800, color: _color, fontSize: 14),
        ),
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

class _SheetLabel extends StatelessWidget {
  final String text;
  const _SheetLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary));
}

class _FlatField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;

  const _FlatField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        textInputAction: textInputAction,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        ),
      );
}
