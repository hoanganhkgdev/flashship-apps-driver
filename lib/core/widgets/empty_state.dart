import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Khối "trống dữ liệu" chuẩn: vòng tròn icon + tiêu đề + mô tả, có thể kèm
/// 1 nút hành động (VD "Tải lại"). Mọi màu/kích thước đều optional để mỗi
/// màn hình tái tạo đúng giao diện riêng của mình.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final double circleSize;
  final double iconSize;
  final String title;
  final double titleFontSize;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? actionColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    this.circleSize = 80,
    this.iconSize = 40,
    required this.title,
    this.titleFontSize = 17,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.actionColor,
  });

  @override
  Widget build(BuildContext context) {
    final btnColor = actionColor ?? iconColor;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: circleSize, height: circleSize,
          decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
        const SizedBox(height: 16),
        Text(title,
            style: TextStyle(
              fontSize: titleFontSize, fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            )),
        const SizedBox(height: 6),
        Text(subtitle,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: btnColor.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(actionLabel!,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: btnColor,
                  )),
            ),
          ),
        ],
      ]),
    );
  }
}
