import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'bubble.dart';

/// Khung header gradient cam dùng chung cho các màn hình (điểm, công nợ, thu
/// nhập, đơn đang chạy, lịch sử): nền gradient + 3 bubble trang trí + đường
/// viền trắng ("seam") cuối cùng để nối liền phần nội dung trắng bên dưới.
///
/// [children] là nội dung riêng của từng màn hình (kể cả phần chừa khoảng
/// trống safe-area phía trên, nếu màn hình đó tự quản lý) — shell chỉ thêm
/// đúng phần khung + seam, không tự chèn thêm padding nào khác.
class GradientHeaderShell extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final List<Color>? colors;
  final bool showBubbles;
  final Color? seamColor;

  final double bubble1Size, bubble1Top, bubble1Right, bubble1Opacity;
  final double bubble2Size, bubble2Top, bubble2Left, bubble2Opacity;
  final double bubble3Size, bubble3Bottom, bubble3Right, bubble3Opacity;

  const GradientHeaderShell({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.colors,
    this.showBubbles = true,
    this.seamColor,
    this.bubble1Size = 150,
    this.bubble1Top = -40,
    this.bubble1Right = -40,
    this.bubble1Opacity = 0.07,
    this.bubble2Size = 80,
    this.bubble2Top = 80,
    this.bubble2Left = -30,
    this.bubble2Opacity = 0.05,
    this.bubble3Size = 55,
    this.bubble3Bottom = 40,
    this.bubble3Right = 30,
    this.bubble3Opacity = 0.04,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors ??
                const [Color(0xFFCC5A08), Color(0xFFE8720C), Color(0xFFF59E30)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (showBubbles)
              Positioned(
                  top: bubble1Top,
                  right: bubble1Right,
                  child: Bubble(bubble1Size, bubble1Opacity)),
            if (showBubbles)
              Positioned(
                  top: bubble2Top,
                  left: bubble2Left,
                  child: Bubble(bubble2Size, bubble2Opacity)),
            if (showBubbles)
              Positioned(
                  bottom: bubble3Bottom,
                  right: bubble3Right,
                  child: Bubble(bubble3Size, bubble3Opacity)),
            Column(
              crossAxisAlignment: crossAxisAlignment,
              children: [
                ...children,
                Container(height: 20, color: seamColor ?? AppColors.background),
              ],
            ),
          ],
        ),
      );
}
