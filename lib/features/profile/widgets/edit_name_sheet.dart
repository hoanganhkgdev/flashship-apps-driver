import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';

class EditNameSheet extends StatefulWidget {
  final String currentName;
  final Future<void> Function(String name) onSave;
  final VoidCallback onSaved;

  const EditNameSheet({
    super.key,
    required this.currentName,
    required this.onSave,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required String currentName,
    required Future<void> Function(String name) onSave,
    required VoidCallback onSaved,
  }) {
    return showAppBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditNameSheet(
        currentName: currentName,
        onSave: onSave,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<EditNameSheet> {
  late final _ctrl = TextEditingController(text: widget.currentName);
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Thành công: pop sheet rồi báo cho caller toast bằng context màn hình
  // (widget.onSaved). Thất bại: toast ngay tại đây bằng context của sheet —
  // sheet vẫn đang mở, không pop — để tài xế thấy lỗi và sửa lại luôn.
  Future<void> _submit() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(name);
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cập nhật thất bại'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const AppBottomSheetHeader(
          title: 'Chỉnh sửa tên',
          subtitle: 'Tên chỉ được thay đổi một lần.',
        ),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          controller: _ctrl,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(
              fontSize: AppFontSize.md,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Họ và tên',
            hintStyle: const TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: AppColors.divider)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: AppColors.divider)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _saving ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
              shape: const StadiumBorder(),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Lưu',
                    style: TextStyle(
                        fontSize: AppFontSize.md,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}
