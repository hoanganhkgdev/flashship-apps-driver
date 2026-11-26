import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Header chuẩn cho các màn hình cấp hai của ứng dụng Driver.
class AppScreenHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final VoidCallback? onBack;
  final Color backgroundColor;
  final Color foregroundColor;

  const AppScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.onBack,
    this.backgroundColor = AppColors.primary,
    this.foregroundColor = AppBrand.ink,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final titleHeight = scaler.scale(18) * 1.25;
    final textHeight =
        titleHeight + (subtitle == null ? 0 : 3 + scaler.scale(12) * 1.35);
    return AppBar(
      toolbarHeight: preferredSize.height,
      automaticallyImplyLeading: false,
      backgroundColor: backgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      foregroundColor: foregroundColor,
      iconTheme: IconThemeData(color: foregroundColor),
      leadingWidth: 60,
      leading: automaticallyImplyLeading
          ? Center(
              child: IconButton(
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                tooltip: 'Quay lại',
                style: IconButton.styleFrom(
                  foregroundColor: foregroundColor,
                  padding: EdgeInsets.zero,
                ),
                icon: Container(
                  width: textHeight,
                  height: textHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, size: 18),
                ),
              ),
            )
          : null,
      titleSpacing: automaticallyImplyLeading ? 0 : AppSpacing.lg,
      title: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(title,
                  style: AppTextStyles.sectionTitle
                      .copyWith(fontSize: 18, color: foregroundColor)),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTextStyles.caption.copyWith(color: foregroundColor)),
            ],
          ],
        ),
      ),
      actions: actions,
    );
  }
}
