import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Nút back bo góc dùng chung cho các header tự vẽ (không phải AppBar mặc
/// định) — trước đây mỗi màn tự viết lại với size/radius/icon lệch nhau
/// (34–48px, radius 10–16, icon 16–27px, có nơi còn nhầm icon chevron).
/// 2 biến thể theo nền header:
/// - mặc định: nền xám ấm nhạt, dùng trên header trắng/kem.
/// - [AppBackButton.onColor]: nền trắng mờ, dùng trên header cam/gradient.
class AppBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool _onColor;

  const AppBackButton({super.key, required this.onTap}) : _onColor = false;
  const AppBackButton.onColor({super.key, required this.onTap})
      : _onColor = true;

  @override
  Widget build(BuildContext context) {
    final size = _onColor ? 34.0 : 40.0;
    final button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _onColor
            ? Colors.white.withValues(alpha: 0.22)
            : const Color(0xFFF7F0ED),
        borderRadius:
            BorderRadius.circular(_onColor ? AppRadius.sm : AppRadius.md),
      ),
      child: Icon(Icons.arrow_back_ios_new_rounded,
          size: _onColor ? 17 : 16, color: AppColors.textPrimary),
    );
    return GestureDetector(
      onTap: onTap,
      // Vùng chạm 48x48 cho biến thể onColor (nút vẽ nhỏ hơn để cân đối thị
      // giác trên header màu) — biến thể còn lại đã đủ 40px, không cần bọc.
      child: _onColor
          ? SizedBox(width: 48, height: 48, child: Center(child: button))
          : button,
    );
  }
}
