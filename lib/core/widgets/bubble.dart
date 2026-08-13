import 'package:flutter/material.dart';

/// Vòng tròn trang trí mờ, dùng làm hoạ tiết nền cho các header gradient.
class Bubble extends StatelessWidget {
  final double size, opacity;
  const Bubble(this.size, this.opacity, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );
}
