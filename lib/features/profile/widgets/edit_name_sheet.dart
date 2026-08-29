import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

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
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFFEFD),
      barrierColor: Colors.black.withValues(alpha: 0.38),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFE1D9D5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Chỉnh sửa tên',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B1411))),
        ),
        const SizedBox(height: 4),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Tên chỉ được thay đổi một lần.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6A605C))),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _ctrl,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B1411)),
          decoration: InputDecoration(
            hintText: 'Họ và tên',
            hintStyle: const TextStyle(color: Color(0xFFA99F9A)),
            filled: true,
            fillColor: const Color(0xFFFFF8F5),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFFE5DDD9))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFFE5DDD9))),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide:
                  const BorderSide(color: Color(0xFFFF6035), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _saving ? null : _submit,
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
                : const Text('Lưu',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}
