import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

Widget surfaceCard(
    {required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) {
  return Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      boxShadow: AppColors.cardShadow,
    ),
    child: child,
  );
}
