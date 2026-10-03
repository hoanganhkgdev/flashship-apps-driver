import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: true,
      backgroundColor: Colors.white,
      barrierColor: Colors.black.withValues(alpha: .45),
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: builder,
    );

/// Đầu sheet: tay nắm kéo, (icon) + tiêu đề + phụ đề, nút đóng bên phải.
class AppBottomSheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool showClose;

  const AppBottomSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.showClose = true,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            if (icon != null) ...[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.screenTitle.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            if (showClose) ...[
              const SizedBox(width: AppSpacing.sm),
              Semantics(
                button: true,
                label: 'Đóng',
                child: GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ]),
        ],
      );
}

/// Kiểu ô nhập dùng chung trong sheet: nền xám nhạt, viền mảnh, focus cam.
InputDecoration appSheetInputDecoration({
  String? hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? suffixText,
  String? errorText,
  bool bordered = true,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide:
            bordered ? BorderSide(color: color, width: width) : BorderSide.none,
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textTertiary),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    suffixText: suffixText,
    suffixStyle: const TextStyle(
        fontSize: AppFontSize.base,
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600),
    errorText: errorText,
    errorStyle:
        const TextStyle(fontSize: AppFontSize.sm, color: AppColors.danger),
    filled: true,
    fillColor: AppColors.surfaceAlt,
    contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg, vertical: AppSpacing.md + 2),
    border: border(AppColors.divider),
    enabledBorder: border(AppColors.divider),
    focusedBorder: border(AppColors.primary, 1.5),
    errorBorder: border(AppColors.danger),
    focusedErrorBorder: border(AppColors.danger, 1.5),
  );
}

/// Ô tìm kiếm trong sheet danh sách (khu vực, ngân hàng...).
class AppSheetSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  const AppSheetSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(
            fontSize: AppFontSize.md,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
        decoration: appSheetInputDecoration(
          hint: hint,
          bordered: false,
          prefixIcon: const Icon(Icons.search_rounded,
              size: 21, color: AppColors.textSecondary),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, v, __) => v.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    onPressed: () {
                      controller.clear();
                      onChanged?.call('');
                    },
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.textSecondary),
                  ),
          ),
        ).copyWith(
          contentPadding:
              const EdgeInsets.symmetric(vertical: AppSpacing.md + 1),
        ),
      );
}

/// Một dòng lựa chọn: icon (hoặc [leading]) + nhãn + phụ đề. Khi [selected]
/// dòng được tô cam nhạt và hiện dấu tick.
class AppSheetOption extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final Color iconBackground;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final bool selected;
  final bool showChevron;
  final VoidCallback onTap;

  const AppSheetOption({
    super.key,
    this.icon,
    this.leading,
    this.iconBackground = AppColors.primarySoft,
    this.iconColor = AppColors.primary,
    required this.label,
    this.subtitle,
    this.selected = false,
    this.showChevron = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: selected ? AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.md),
              child: Row(children: [
                leading ??
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: iconBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 21, color: iconColor),
                    ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: AppFontSize.md,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? AppColors.primaryDark
                                  : AppColors.textPrimary)),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(subtitle!,
                              style: const TextStyle(
                                  fontSize: AppFontSize.sm,
                                  color: AppColors.textSecondary)),
                        ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      size: 22, color: AppColors.primary)
                else if (showChevron)
                  const Icon(Icons.chevron_right_rounded,
                      size: 22, color: AppColors.textTertiary),
              ]),
            ),
          ),
        ),
      );
}

/// Nút chính của sheet: cùng kiểu với nút ở các màn đăng nhập.
class AppSheetButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const AppSheetButton({
    super.key,
    required this.label,
    this.loading = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(label,
                  style: const TextStyle(
                      fontSize: AppFontSize.md,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
        ),
      );
}
