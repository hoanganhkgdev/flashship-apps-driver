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
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
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
            LayoutBuilder(builder: (context, constraints) {
              const gap = 6.0;
              final boxWidth =
                  ((constraints.maxWidth - gap * 5) / 6).clamp(36.0, 47.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  final code = widget.controller.text;
                  final filled = i < code.length;
                  final active = i == code.length;
                  return AnimatedScale(
                    duration: const Duration(milliseconds: 150),
                    scale: active ? 1.04 : 1.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: boxWidth,
                      height: 56,
                      decoration: BoxDecoration(
                        color:
                            active ? AppColors.primarySoft : AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: active
                            ? Border.all(color: AppBrand.ink, width: 2)
                            : filled
                                ? Border.all(
                                    color: AppColors.success, width: 1.25)
                                : Border.all(
                                    color: AppColors.divider, width: 1.25),
                      ),
                      child: Center(
                        child: Text(
                          filled ? code[i] : '',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B1411),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            }),
          ],
        ),
      ),
    );
  }
}
