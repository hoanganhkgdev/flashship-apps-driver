import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';

class BankAccountScreen extends ConsumerStatefulWidget {
  const BankAccountScreen({super.key});

  @override
  ConsumerState<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends ConsumerState<BankAccountScreen> {
  final _accountNumberCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  BankListItem? _selectedBank;
  bool _saving = false;
  bool _formEdited = false;

  @override
  void initState() {
    super.initState();
    _hydrateBankForm(ref.read(walletProvider), notify: false);
  }

  @override
  void dispose() {
    _accountNumberCtrl.dispose();
    _accountNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedBank == null) {
      _showError('Vui lòng chọn ngân hàng');
      return;
    }
    if (_accountNumberCtrl.text.trim().isEmpty) {
      _showError('Vui lòng nhập số tài khoản');
      return;
    }
    if (_accountNameCtrl.text.trim().isEmpty) {
      _showError('Vui lòng nhập tên chủ tài khoản');
      return;
    }

    setState(() => _saving = true);
    final ok = await ref.read(walletProvider.notifier).updateBank(
          bankCode: _selectedBank!.code,
          bankName: _selectedBank!.name,
          accountNumber: _accountNumberCtrl.text.trim(),
          accountHolder: _accountNameCtrl.text.trim().toUpperCase(),
        );
    setState(() => _saving = false);

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Lưu tài khoản ngân hàng thành công'),
        backgroundColor: AppColors.success,
      ));
      context.pop();
    } else {
      _showError('Không thể lưu. Thử lại sau.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.danger,
    ));
  }

  void _showBankPicker() {
    final banks = ref.read(walletProvider).bankList;
    showAppBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BankPickerSheet(
        banks: banks,
        selected: _selectedBank,
        onSelect: (bank) {
          setState(() {
            _selectedBank = bank;
            _formEdited = true;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final hasBank = !wallet.bankAccount.isEmpty;

    ref.listen<WalletState>(walletProvider, (previous, next) {
      if (_formEdited || next.bankAccount.isEmpty) return;
      final accountChanged =
          previous?.bankAccount.bankCode != next.bankAccount.bankCode ||
              previous?.bankAccount.accountNumber !=
                  next.bankAccount.accountNumber ||
              previous?.bankList.length != next.bankList.length;
      if (accountChanged) _hydrateBankForm(next);
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppScreenHeader(
          title: hasBank ? 'Tài khoản ngân hàng' : 'Thêm ngân hàng',
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl3),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ListenableBuilder(
              listenable:
                  Listenable.merge([_accountNumberCtrl, _accountNameCtrl]),
              builder: (_, __) => _BankPreviewCard(
                hasBank: hasBank,
                bank: _selectedBank,
                accountNumber: _accountNumberCtrl.text,
                holder: _accountNameCtrl.text,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSurfaceCard(
              color: Colors.white,
              showBorder: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Thông tin nhận tiền',
                      style: AppTextStyles.sectionTitle),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Kiểm tra chính xác trước khi lưu để tránh chuyển tiền nhầm.',
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Text('Ngân hàng', style: AppTextStyles.bodyStrong),
                  const SizedBox(height: 9),
                  GestureDetector(
                    onTap: _showBankPicker,
                    child: Container(
                      height: 62,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: _selectedBank != null
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : AppColors.divider,
                        ),
                      ),
                      child: Row(children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: _selectedBank?.logoUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: Image.network(
                                    _selectedBank!.logoUrl!,
                                    width: 25,
                                    height: 25,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.account_balance_rounded,
                                        size: 19),
                                  ),
                                )
                              : const Icon(Icons.account_balance_rounded,
                                  size: 19),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedBank?.name ?? 'Chọn ngân hàng',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: _selectedBank != null
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _selectedBank != null
                                  ? AppColors.textPrimary
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textSecondary),
                      ]),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Text('Số tài khoản', style: AppTextStyles.bodyStrong),
                  const SizedBox(height: 9),
                  TextField(
                    controller: _accountNumberCtrl,
                    onChanged: (_) => _formEdited = true,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                    decoration:
                        _inputDeco('Nhập số tài khoản', Icons.tag_rounded),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Text('Tên chủ tài khoản',
                      style: AppTextStyles.bodyStrong),
                  const SizedBox(height: 9),
                  TextField(
                    controller: _accountNameCtrl,
                    onChanged: (_) => _formEdited = true,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                    decoration: _inputDeco(
                        'VD: NGUYEN VAN A', Icons.person_outline_rounded),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.infoSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline_rounded,
                          size: 17, color: AppColors.info),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Tên chủ tài khoản phải trùng với tên đăng ký ngân hàng.',
                          style: TextStyle(
                            fontSize: AppFontSize.sm,
                            height: 1.4,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: AppSpacing.xl2),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha: 0.5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(hasBank ? 'Cập nhật' : 'Lưu tài khoản',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) =>
      appSheetInputDecoration(
        hint: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
      );

  void _hydrateBankForm(WalletState wallet, {bool notify = true}) {
    final account = wallet.bankAccount;
    if (account.isEmpty || _formEdited) return;

    void apply() {
      _accountNumberCtrl.text = account.accountNumber ?? '';
      _accountNameCtrl.text = account.accountHolder ?? '';
      final code = account.bankCode;
      if (code != null) {
        final matches = wallet.bankList.where((bank) => bank.code == code);
        if (matches.isNotEmpty) _selectedBank = matches.first;
      }
    }

    if (notify && mounted) {
      setState(apply);
    } else {
      apply();
    }
  }
}

/// Thẻ ngân hàng xem trước: cập nhật trực tiếp khi tài xế chọn ngân hàng và
/// nhập số tài khoản / tên chủ tài khoản.
class _BankPreviewCard extends StatelessWidget {
  final bool hasBank;
  final BankListItem? bank;
  final String accountNumber;
  final String holder;

  const _BankPreviewCard({
    required this.hasBank,
    required this.bank,
    required this.accountNumber,
    required this.holder,
  });

  String get _numberLabel {
    final digits = accountNumber.replaceAll(RegExp(r'\s'), '');
    if (digits.isEmpty) return '••••  ••••  ••••';
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write('  ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final holderLabel = holder.trim().isEmpty
        ? 'TÊN CHỦ TÀI KHOẢN'
        : holder.trim().toUpperCase();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B2320), Color(0xFF4A3A33)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B1411).withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            ),
            alignment: Alignment.center,
            child: bank?.logoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(bank!.logoUrl!,
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.account_balance_rounded,
                            size: 20,
                            color: Colors.white)),
                  )
                : const Icon(Icons.account_balance_rounded,
                    size: 20, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(bank?.name ?? 'Chưa chọn ngân hàng',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyStrong.copyWith(color: Colors.white)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (hasBank ? AppColors.success : AppColors.warning)
                  .withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  hasBank
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  size: 13,
                  color: Colors.white),
              const SizedBox(width: 4),
              Text(hasBank ? 'Đã liên kết' : 'Chưa liên kết',
                  style: AppTextStyles.caption.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
        const SizedBox(height: AppSpacing.xl2),
        Text(_numberLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.metricLarge.copyWith(
                color: Colors.white, fontSize: 24, letterSpacing: 1.5)),
        const SizedBox(height: AppSpacing.lg),
        Text('CHỦ TÀI KHOẢN',
            style: AppTextStyles.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.6), letterSpacing: .8)),
        const SizedBox(height: 2),
        Text(holderLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyStrong.copyWith(
                color: holder.trim().isEmpty
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.white,
                letterSpacing: 0.6)),
        const SizedBox(height: AppSpacing.md),
        Text(
          hasBank
              ? 'Tài khoản này được dùng để nhận tiền rút từ ví.'
              : 'Thêm tài khoản để có thể rút số dư trong ví.',
          style: AppTextStyles.label
              .copyWith(color: Colors.white.withValues(alpha: 0.7)),
        ),
      ]),
    );
  }
}

class _BankPickerSheet extends StatefulWidget {
  final List<BankListItem> banks;
  final BankListItem? selected;
  final ValueChanged<BankListItem> onSelect;

  const _BankPickerSheet(
      {required this.banks, this.selected, required this.onSelect});

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<BankListItem> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.banks;
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.banks;
      } else {
        final q = query.toLowerCase();
        _filtered = widget.banks
            .where(
                (b) => b.name.toLowerCase().contains(q) || b.code.contains(q))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: AppBottomSheetHeader(
            title: 'Chọn ngân hàng',
            subtitle: 'Ngân hàng nhận tiền rút',
            icon: Icons.account_balance_rounded,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AppSheetSearchField(
              controller: _searchCtrl,
              hint: 'Tìm ngân hàng...',
              onChanged: _filter),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: _filtered.isEmpty
              ? const Center(
                  child: Text('Không tìm thấy ngân hàng',
                      style: TextStyle(
                          fontSize: AppFontSize.base,
                          color: AppColors.textSecondary)),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(12, 4, 12, bottom + 16),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final bank = _filtered[i];
                    return AppSheetOption(
                      leading: _BankMark(bank: bank),
                      label: bank.name,
                      selected: widget.selected?.code == bank.code,
                      onTap: () => widget.onSelect(bank),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _BankMark extends StatelessWidget {
  final BankListItem bank;

  const _BankMark({required this.bank});

  @override
  Widget build(BuildContext context) {
    final code = bank.code.toUpperCase();
    final palette = switch (code) {
      'VCB' => (const Color(0xFFD9F3E1), const Color(0xFF229650)),
      'TCB' => (const Color(0xFFFFDFDD), const Color(0xFFD52E36)),
      'BIDV' || 'BID' => (const Color(0xFFE1ECFD), const Color(0xFF286BCB)),
      'ACB' => (const Color(0xFFFFEDC9), const Color(0xFFAF7000)),
      'MB' || 'MBBANK' => (const Color(0xFFFFE9E2), const Color(0xFFFF6035)),
      _ => (const Color(0xFFF1ECE9), const Color(0xFF6A605C)),
    };
    final mark = code.length > 4 ? code.substring(0, 4) : code;

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.$1,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        mark,
        maxLines: 1,
        style: TextStyle(
          fontSize: mark.length > 3 ? 10 : 12,
          fontWeight: FontWeight.w900,
          color: palette.$2,
        ),
      ),
    );
  }
}
