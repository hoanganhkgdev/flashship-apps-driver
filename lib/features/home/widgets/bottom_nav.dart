import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final bool showOrderMarket;
  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.showOrderMarket = false,
  });

  // Scaffold tự chừa chiều cao thanh điều hướng. Các màn cuộn chỉ cần một
  // khoảng thở nhỏ ở cuối danh sách.
  static double reservedHeight(BuildContext context) => AppSpacing.sm;

  List<NavItem> get _tabs => [
        const NavItem(Icons.home_rounded, Icons.home_outlined, 'Trang chủ'),
        if (showOrderMarket)
          const NavItem(
              Icons.storefront_rounded, Icons.storefront_outlined, 'Chợ đơn'),
        const NavItem(Icons.history_rounded, Icons.history_outlined, 'Lịch sử'),
        const NavItem(
            Icons.payments_rounded, Icons.payments_outlined, 'Thu nhập'),
        const NavItem(
            Icons.person_rounded, Icons.person_outline_rounded, 'Tài khoản'),
      ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0EBE8))),
        boxShadow: [
          BoxShadow(
            color: Color(0x141B1411),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: _NavButton(
                  item: _tabs[i],
                  selected: i == currentIndex,
                  onTap: () {
                    if (i != currentIndex) HapticFeedback.selectionClick();
                    onTap(i);
                  },
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkResponse(
        onTap: onTap,
        radius: 40,
        highlightShape: BoxShape.rectangle,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Viên thuốc cam nhạt giãn ra phía sau icon của tab đang chọn.
            AnimatedContainer(
              duration: AppDuration.normal,
              curve: Curves.easeOutCubic,
              width: selected ? 58 : 32,
              height: 32,
              decoration: BoxDecoration(
                color: selected ? AppColors.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: AnimatedSwitcher(
                duration: AppDuration.fast,
                child: Icon(
                  selected ? item.on : item.off,
                  key: ValueKey(selected),
                  size: AppSize.iconLg,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: AppDuration.normal,
              style: AppTextStyles.label.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
              child: Text(item.label,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
