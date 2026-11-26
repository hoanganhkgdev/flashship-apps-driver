import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

class NavItem {
  final IconData on;
  final IconData off;
  final String label;
  const NavItem(this.on, this.off, this.label);
}

/// Thanh điều hướng nổi: các tab rộng bằng nhau, icon trên và chữ dưới
/// căn giữa; tab đang chọn có nền cam nhạt và chữ cam đậm.
///
/// Tab Đơn hàng có:
///   - huy hiệu đỏ đếm đơn mới (khi đang Online);
///   - chấm cam khi đang có đơn chạy — đứng ở tab khác vẫn biết còn đơn
///     chưa xong.
class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Số đơn mới đang chờ — huy hiệu đỏ trên tab Đơn hàng.
  final int newOrderCount;

  /// Số đơn đang chạy — chấm cam trên tab Đơn hàng.
  final int runningCount;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.newOrderCount = 0,
    this.runningCount = 0,
  });

  static const _tabs = [
    NavItem(
        Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Đơn hàng'),
    NavItem(Icons.payments_rounded, Icons.payments_outlined, 'Thu nhập'),
    NavItem(Icons.person_rounded, Icons.person_outline_rounded, 'Tài khoản'),
  ];

  static double _barHeight(BuildContext context) {
    // Icon 24 + khoảng 3 + chữ nhỏ (11) theo cỡ chữ hệ thống + đệm trên dưới.
    final label = MediaQuery.textScalerOf(context).scale(11) * 1.2;
    final h = 24 + 3 + label + 22;
    return h < 64 ? 64 : h;
  }

  // HomeScreen dùng extendBody nên các danh sách tự chừa đúng chiều cao nav.
  static double reservedHeight(BuildContext context) =>
      _barHeight(context) + 16 + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          minimum: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Container(
              height: _barHeight(context),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFFDFC), Color(0xFFFFF5EE)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1DACA)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x18A44A0A),
                    blurRadius: 20,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _NavButton(
                      item: _tabs[i],
                      selected: i == currentIndex,
                      badge: i == 0 ? newOrderCount : 0,
                      running: i == 0 ? runningCount : 0,
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

class _NavButton extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final int badge;
  final int running;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.badge,
    required this.running,
    required this.onTap,
  });

  String get _semantics => [
        item.label,
        if (badge > 0) '$badge đơn mới',
        if (running > 0) '$running đơn đang chạy',
      ].join(', ');

  Widget _icon(Color color) => Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedSwitcher(
            duration: AppDuration.fast,
            child: Icon(
              selected ? item.on : item.off,
              key: ValueKey(selected),
              size: AppSize.iconLg,
              color: color,
            ),
          ),
          // Đang ở tab Đơn hàng thì đơn chạy đã hiện sẵn — chấm chỉ cần
          // khi đứng ở tab khác (trên nền cam chấm cam cũng chìm mất).
          if (running > 0 && !selected)
            Positioned(
              left: -3,
              top: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.warningStrong,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
          if (badge > 0)
            Positioned(
              right: -10,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: AppColors.surface,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                  textScaler: TextScaler.noScaling,
                ),
              ),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: _semantics,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: AnimatedContainer(
            duration: AppDuration.normal,
            decoration: BoxDecoration(
              color: selected ? AppColors.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _icon(selected
                          ? AppColors.primaryDark
                          : AppColors.textSecondary),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.label,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            color: selected
                                ? AppColors.primaryDark
                                : AppColors.textSecondary,
                            fontSize: 11,
                            height: 1.2,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
