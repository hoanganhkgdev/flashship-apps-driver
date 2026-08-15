import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// 6 ô nhập OTP — TextField ẩn giữ focus/bàn phím số, hiển thị bằng 6 box.
class OtpInputRow extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onFilled;
  final VoidCallback onChanged;
  // Khoá ô nhập trong lúc đang xác thực — tránh user gõ lại số cuối, bắn
  // onFilled() lần nữa trong khi request xác thực trước còn đang chạy.
  final bool enabled;
  const OtpInputRow({
    super.key,
    required this.controller,
    required this.onFilled,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<OtpInputRow> createState() => _OtpInputRowState();
}

class _OtpInputRowState extends State<OtpInputRow> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: widget.enabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: widget.enabled ? () => _focus.requestFocus() : null,
        child: Stack(
          children: [
            Opacity(
              opacity: 0,
              child: SizedBox(
                height: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  showCursor: false,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterText: '',
                  ),
                  onChanged: (v) {
                    widget.onChanged();
                    setState(() {});
                    if (v.length == 6) widget.onFilled();
                  },
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) {
                final code   = widget.controller.text;
                final filled = i < code.length;
                final active = i == code.length;
                return AnimatedScale(
                  duration: const Duration(milliseconds: 150),
                  scale: active ? 1.04 : 1.0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 50,
                    height: 60,
                    decoration: BoxDecoration(
                      color: filled
                          ? AppColors.primary.withValues(alpha: 0.06)
                          : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                      border: active
                          ? Border.all(color: AppColors.primary, width: 1.5)
                          : filled
                              ? Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  width: 1.5)
                              : null,
                    ),
                    child: Center(
                      child: Text(
                        filled ? code[i] : '',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
