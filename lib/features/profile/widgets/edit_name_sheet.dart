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
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const AppBottomSheetHeader(
          title: 'Chỉnh sửa tên',
          subtitle: 'Tên chỉ được thay đổi một lần.',
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: AppSpacing.xl),
        Align(
          alignment: Alignment.centerLeft,
          child: const Text('Họ và tên',
              style: TextStyle(
                  fontSize: AppFontSize.base,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _ctrl,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(
              fontSize: AppFontSize.md,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
          decoration: appSheetInputDecoration(
            hint: 'Nguyễn Văn An',
            prefixIcon: const Icon(Icons.person_outline_rounded,
                size: 20, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSheetButton(label: 'Lưu', loading: _saving, onPressed: _submit),
      ]),
    );
  }
}
