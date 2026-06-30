import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    final wallet = ref.read(walletProvider);
    if (!wallet.bankAccount.isEmpty) {
      _accountNumberCtrl.text = wallet.bankAccount.accountNumber ?? '';
      _accountNameCtrl.text = wallet.bankAccount.accountHolder ?? '';
      final code = wallet.bankAccount.bankCode;
      if (code != null && wallet.bankList.isNotEmpty) {
        final match = wallet.bankList.where((b) => b.code == code);
        if (match.isNotEmpty) _selectedBank = match.first;
      }
    }
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BankPickerSheet(
        banks: banks,
        selected: _selectedBank,
        onSelect: (bank) {
          setState(() => _selectedBank = bank);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final hasBank = !wallet.bankAccount.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(hasBank ? 'Tài khoản ngân hàng' : 'Thêm ngân hàng'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Ngân hàng',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showBankPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(children: [
                if (_selectedBank?.logoUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      _selectedBank!.logoUrl!,
                      width: 32, height: 32, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.account_balance, size: 24, color: AppColors.textTertiary),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    _selectedBank?.name ?? 'Chọn ngân hàng',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: _selectedBank != null ? FontWeight.w600 : FontWeight.w400,
                      color: _selectedBank != null ? AppColors.textPrimary : AppColors.textTertiary,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textTertiary),
              ]),
            ),
          ),

          const SizedBox(height: 20),
          const Text('Số tài khoản',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextField(
            controller: _accountNumberCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            decoration: _inputDeco('Nhập số tài khoản'),
          ),

          const SizedBox(height: 20),
          const Text('Tên chủ tài khoản',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextField(
            controller: _accountNameCtrl,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            decoration: _inputDeco('VD: NGUYEN VAN A'),
          ),

          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: 6),
            const Expanded(
              child: Text('Tên chủ tài khoản phải trùng với tên đăng ký ngân hàng',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ),
          ]),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity, height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(hasBank ? 'Cập nhật' : 'Lưu tài khoản',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 15),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
  );
}

class _BankPickerSheet extends StatefulWidget {
  final List<BankListItem> banks;
  final BankListItem? selected;
  final ValueChanged<BankListItem> onSelect;

  const _BankPickerSheet({required this.banks, this.selected, required this.onSelect});

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
        _filtered = widget.banks.where((b) =>
          b.name.toLowerCase().contains(q) || b.code.contains(q)
        ).toList();
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      child: Column(children: [
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 16),
        const Text('Chọn ngân hàng',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _filter,
            autofocus: true,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Tìm ngân hàng...',
              hintStyle: const TextStyle(color: AppColors.textTertiary),
              prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary, size: 20),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final bank = _filtered[i];
              final isSelected = widget.selected?.code == bank.code;
              return ListTile(
                leading: bank.logoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          bank.logoUrl!,
                          width: 36, height: 36, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.account_balance, size: 24),
                        ),
                      )
                    : const Icon(Icons.account_balance, size: 24, color: AppColors.textTertiary),
                title: Text(bank.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: AppColors.textPrimary,
                    )),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)
                    : null,
                onTap: () => widget.onSelect(bank),
              );
            },
          ),
        ),
      ]),
    );
  }
}
