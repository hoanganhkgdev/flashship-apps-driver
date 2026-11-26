import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Nhóm danh sách kiểu "thẻ có nhãn": nhãn nhỏ viết hoa nằm NGOÀI thẻ, các
/// dòng trong thẻ tự có vạch ngăn — mọi nhóm trên màn Tài khoản cùng một
/// khuôn nên nhìn lướt là thấy cấu trúc.
class SettingsSection extends StatelessWidget {
  final String? header;
  final List<Widget> children;
  const SettingsSection({super.key, this.header, required this.children});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpacing.sm),
              child: Text(
                header!.toUpperCase(),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .6,
                ),
              ),
            ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.divider, width: 1.25),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Column(children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: children[i] is SettingsRow ? 64 : 0,
                      color: AppColors.divider,
                    ),
                  children[i],
                ],
              ]),
            ),
          ),
        ]),
      );
}

class SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color? iconBg;
  final Color? iconColor;
  final String label;
  final String? subtitle;
  final Color? labelColor;
  final Widget? trailing;

  /// Đặt dưới phụ đề (vd viên trạng thái) — không chiếm chỗ của nhãn như
  /// [trailing] trên máy hẹp.
  final Widget? below;
  final bool showChevron;
  final VoidCallback? onTap;

  const SettingsRow({
    super.key,
    required this.icon,
    this.iconBg,
    this.iconColor,
    required this.label,
    this.subtitle,
    this.labelColor,
    this.trailing,
    this.below,
    this.showChevron = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    gradient: iconBg == null ? AppBrand.gradient : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: iconColor ?? AppBrand.ink),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.body.copyWith(
                          color: labelColor ?? AppBrand.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (below != null) ...[
                        const SizedBox(height: 6),
                        below!,
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(child: trailing!),
                ],
                if (showChevron && onTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textTertiary, size: 22),
                ],
              ]),
            ),
          ),
        ),
      );
}

/// Viên trạng thái nhỏ cho cột phải của [SettingsRow].
class StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;
  const StatusPill(this.text,
      {super.key, required this.color, required this.background});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: color.withValues(alpha: .65)),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
