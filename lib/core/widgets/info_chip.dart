import 'package:flutter/material.dart';

/// Pill nhỏ icon + chữ, dùng trên nền gradient cam (VD trong
/// [GradientHeaderShell]). [danger] đổi màu sang đỏ cho cảnh báo (VD "quá
/// hạn"). [borderAlpha] mặc định khớp màn công nợ (0.35) — earnings_screen
/// dùng 0.3, truyền tại chỗ gọi để giữ đúng giao diện cũ.
class InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final double borderAlpha;

  const InfoChip({
    super.key,
    required this.icon,
    required this.label,
    this.danger = false,
    this.borderAlpha = 0.35,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: (danger ? Colors.red : Colors.white).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (danger ? Colors.red : Colors.white).withValues(alpha: borderAlpha),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
              )),
        ]),
      );
}
