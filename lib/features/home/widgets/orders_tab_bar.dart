import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// Ba tab con của màn chủ: Đơn mới · Đang chạy · Hoàn thành.
class OrdersTabBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final int newCount;
  final int receivedCount;

  const OrdersTabBar({
    super.key,
    required this.index,
    required this.onChanged,
    required this.newCount,
    required this.receivedCount,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ('Đơn mới', newCount),
      ('Đang chạy', receivedCount),
      ('Hoàn thành', 0),
    ];
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.divider, width: 1.25),
        ),
        child: Row(children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  onTap: () {
                    if (i != index) HapticFeedback.selectionClick();
                    onChanged(i);
                  },
                  child: AnimatedContainer(
                    duration: AppDuration.fast,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: i == index ? AppBrand.gradient : null,
                      color: i == index ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      boxShadow: i == index
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: .22),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            tabs[i].$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.label.copyWith(
                              fontWeight: i == index
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: i == index
                                  ? AppBrand.ink
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (tabs[i].$2 > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            constraints: const BoxConstraints(minWidth: 18),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: i == index
                                  ? Colors.white.withValues(alpha: .22)
                                  : AppColors.surfaceAlt,
                              border: i == index
                                  ? Border.all(
                                      color: Colors.white.withValues(alpha: .2),
                                    )
                                  : null,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              tabs[i].$2 > 99 ? '99+' : '${tabs[i].$2}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                                color: i == index
                                    ? AppBrand.ink
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Dùng cho SliverPersistentHeader để thanh tab ghim ở đầu vùng cuộn.
class PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  PinnedHeaderDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      child;

  @override
  bool shouldRebuild(covariant PinnedHeaderDelegate old) =>
      old.child != child || old.height != height;
}
