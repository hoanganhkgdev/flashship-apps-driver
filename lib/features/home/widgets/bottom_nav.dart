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

  /// Số đơn mới đang chờ — hiện thành chấm đếm trên tab đầu tiên.
  final int newOrderCount;
  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.newOrderCount = 0,
  });

  static bool _wrapLabels(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1) > 1.4 ||
      (MediaQuery.sizeOf(context).width < 360 &&
          MediaQuery.textScalerOf(context).scale(1) > 1.2);

  static double _barHeight(BuildContext context) {
    final labelHeight = MediaQuery.textScalerOf(context).scale(AppFontSize.sm) *
        1.15 *
        (_wrapLabels(context) ? 2 : 1);
    final height = 32 + 4 + labelHeight + 16;
    return height < 72 ? 72 : height;
  }

  // HomeScreen dùng extendBody nên các danh sách tự chừa đúng chiều cao nav.
  static double reservedHeight(BuildContext context) =>
      _barHeight(context) + 16 + MediaQuery.paddingOf(context).bottom;

  List<NavItem> get _tabs => [
        const NavItem(Icons.receipt_long_rounded, Icons.receipt_long_outlined,
            'Đơn hàng'),
        const NavItem(
            Icons.payments_rounded, Icons.payments_outlined, 'Thu nhập'),
        const NavItem(
            Icons.person_rounded, Icons.person_outline_rounded, 'Tài khoản'),
      ];

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Container(
            height: _barHeight(context),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.divider),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D1C1410),
                  blurRadius: 18,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: _NavButton(
                    item: _tabs[i],
                    badge: i == 0 ? newOrderCount : 0,
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
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavItem item;
  final int badge;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    this.badge = 0,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: '$item.label${badge > 0 ? ', $badge đơn mới' : ''}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(
            height: double.infinity,
            child: ExcludeSemantics(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    width: 48,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          selected ? AppColors.primarySoft : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Badge(
                      isLabelVisible: badge > 0,
                      backgroundColor: AppColors.danger,
                      label: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
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
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: AppDuration.fast,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: AppFontSize.sm,
                      height: 1.15,
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    child: Text(
                      item.label,
                      maxLines: BottomNav._wrapLabels(context) ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
