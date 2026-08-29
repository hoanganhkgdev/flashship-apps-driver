import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_back_button.dart';
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
      backgroundColor: const Color(0xFFFFFEFD),
      barrierColor: Colors.black.withValues(alpha: 0.38),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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

    final top = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8F5),
        body: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: double.infinity,
              color: const Color(0xFFFFFEFD),
              padding: EdgeInsets.fromLTRB(16, top + 16, 16, 16),
              child: Row(children: [
                AppBackButton(onTap: () => context.pop()),
                Expanded(
                  child: Text(
                      hasBank ? 'Tài khoản ngân hàng' : 'Thêm ngân hàng',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1B1411),
                          letterSpacing: -0.2)),
                ),
                const SizedBox(width: 40),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ngân hàng',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6A605C))),
                    const SizedBox(height: 9),
                    GestureDetector(
                      onTap: _showBankPicker,
                      child: Container(
                        height: 62,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8F5),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: const Color(0xFFE5DDD9)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE9E2),
                              borderRadius: BorderRadius.circular(9),
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
                                    ? const Color(0xFF1B1411)
                                    : const Color(0xFFA99F9A),
                              ),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF1B1411)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Số tài khoản',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6A605C))),
                    const SizedBox(height: 9),
                    TextField(
                      controller: _accountNumberCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1411)),
                      decoration:
                          _inputDeco('Nhập số tài khoản', Icons.tag_rounded),
                    ),
                    const SizedBox(height: 20),
                    const Text('Tên chủ tài khoản',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6A605C))),
                    const SizedBox(height: 9),
                    TextField(
                      controller: _accountNameCtrl,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1411)),
                      decoration: _inputDeco(
                          'VD: NGUYEN VAN A', Icons.person_outline_rounded),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 15, color: Color(0xFF1B1411)),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                            'Tên chủ tài khoản phải trùng với tên đăng ký ngân hàng',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF6A605C))),
                      ),
                    ]),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6035),
                          disabledBackgroundColor:
                              const Color(0xFFFF6035).withValues(alpha: 0.5),
                          shape: const StadiumBorder(),
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
                  ]),
            ),
          ]),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFA99F9A), fontSize: 16),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF1B1411)),
        filled: true,
        fillColor: const Color(0xFFFFF8F5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFFE5DDD9))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFFE5DDD9))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFFFF6035), width: 1.5)),
      );
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.67,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      child: Column(children: [
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
              color: const Color(0xFFE1D9D5),
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 17),
        const Text('Chọn ngân hàng',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B1411))),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _filter,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B1411)),
            decoration: InputDecoration(
              hintText: 'Tìm ngân hàng...',
              hintStyle:
                  const TextStyle(color: Color(0xFFA99F9A), fontSize: 15),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF1B1411), size: 21),
              filled: true,
              fillColor: const Color(0xFFFFF8F5),
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: Color(0xFFFF6035), width: 1.5)),
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
                minTileHeight: 58,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: _BankMark(bank: bank),
                title: Text(bank.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1B1411),
                    )),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_outline_rounded,
                        color: Color(0xFF1B1411), size: 20)
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
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.$1,
        borderRadius: BorderRadius.circular(9),
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
