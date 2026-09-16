import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class NavItem {
  final IconData on;
  final IconData off;
  final String label;
  const NavItem(this.on, this.off, this.label);
}

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const BottomNav({super.key, required this.currentIndex, required this.onTap});

  // Scaffold tự chừa chiều cao thanh điều hướng. Các màn cuộn chỉ cần một
  // khoảng thở nhỏ ở cuối danh sách.
  static double reservedHeight(BuildContext context) => AppSpacing.sm;

  static const _tabs = [
    NavItem(Icons.home_rounded, Icons.home_outlined, 'Trang chủ'),
    NavItem(Icons.history_rounded, Icons.history_outlined, 'Lịch sử'),
    NavItem(Icons.payments_rounded, Icons.payments_outlined, 'Thu nhập'),
    NavItem(Icons.person_rounded, Icons.person_outline_rounded, 'Tài khoản'),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 16,
      shadowColor: const Color(0x291B1411),
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
      clipBehavior: Clip.antiAlias,
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 68,
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.primary,
          indicatorShape: const StadiumBorder(),
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
                size: AppSize.iconLg,
                color: states.contains(WidgetState.selected)
                    ? Colors.white
                    : AppColors.textSecondary,
              )),
          labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => AppTextStyles.label.copyWith(
                    color: states.contains(WidgetState.selected)
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: states.contains(WidgetState.selected)
                        ? FontWeight.w800
                        : FontWeight.w600,
                  )),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onTap,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: _tabs
              .map((tab) => NavigationDestination(
                    icon: Icon(tab.off),
                    selectedIcon: Icon(tab.on),
                    label: tab.label,
                    tooltip: tab.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}
