import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Header chuẩn cho các màn hình cấp hai của ứng dụng Driver.
class AppScreenHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final VoidCallback? onBack;
  final Color backgroundColor;
  final Color foregroundColor;

  const AppScreenHeader({
    super.key,
    required this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.onBack,
    this.backgroundColor = AppColors.surface,
    this.foregroundColor = AppColors.textPrimary,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) => AppBar(
        toolbarHeight: preferredSize.height,
        automaticallyImplyLeading: false,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        leading: automaticallyImplyLeading
            ? IconButton(
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                tooltip: 'Quay lại',
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: actions,
      );
}
