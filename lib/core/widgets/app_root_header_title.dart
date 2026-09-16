import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Hàng tiêu đề chuẩn cho bốn tab chính.
class AppRootHeaderTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const AppRootHeaderTitle({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 40,
        child: Row(children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.screenTitle,
            ),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Header cố định dùng chung cho các tab chính có tiêu đề.
class AppRootHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const AppRootHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          MediaQuery.paddingOf(context).top + AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: AppShadows.soft,
        ),
        child: AppRootHeaderTitle(title: title, trailing: trailing),
      );
}
