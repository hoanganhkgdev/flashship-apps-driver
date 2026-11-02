import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/models/driver_model.dart';
import '../../shifts/widgets/offline_budget_banner.dart';

class DashboardHeader extends StatelessWidget {
  final DriverModel? user;
  final bool isOnline;
  final bool toggling;
  final int toggleCooldownSeconds;
  final bool locked;
  final String? locationIssue;
  final int todayEarnings;
  final int todayOrders;
  final VoidCallback onToggle;

  const DashboardHeader(
      {super.key,
      required this.user,
      required this.isOnline,
      required this.toggling,
      this.toggleCooldownSeconds = 0,
      required this.locked,
      required this.locationIssue,
      required this.todayEarnings,
      required this.todayOrders,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final gpsReady = locationIssue == null;
    final statusColor = locked
        ? AppColors.danger
        : isOnline && !gpsReady
            ? AppColors.warning
            : isOnline
                ? AppColors.success
                : AppColors.textSecondary;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: Color(0xFFFFC9B3))),
      ),
      padding: EdgeInsets.fromLTRB(AppSpacing.lg,
          MediaQuery.paddingOf(context).top + 10, AppSpacing.lg, AppSpacing.md),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            right: -54,
            top: -70,
            child: _HeaderBubble(size: 150, opacity: .34),
          ),
          const Positioned(
            left: -42,
            bottom: -70,
            child: _HeaderBubble(size: 112, opacity: .22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(_greeting(user?.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.screenTitle.copyWith(
                            fontSize: AppFontSize.lg,
                            color: AppColors.textPrimary,
                          )),
                      const SizedBox(height: AppSpacing.xs),
                      Row(children: [
                        const Icon(Icons.insights_rounded,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$todayOrders đơn · ${Fmt.currency(todayEarnings)} hôm nay',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _OnlineButton(
                  isOnline: isOnline,
                  toggling: toggling,
                  cooldownSeconds: toggleCooldownSeconds,
                  locked: locked,
                  color: statusColor,
                  onTap: onToggle,
                ),
              ]),
              const OfflineBudgetBanner(compact: true),
            ],
          ),
        ],
      ),
    );
  }

  TextSpan _greeting(String? name) {
    final hour = DateTime.now().hour;
    final greeting = hour < 11
        ? 'Chào buổi sáng'
        : hour < 18
            ? 'Chào buổi chiều'
            : 'Chào buổi tối';
    final trimmed = name?.trim() ?? '';
    final shortName =
        trimmed.isEmpty ? 'tài xế' : trimmed.split(RegExp(r'\s+')).last;
    return TextSpan(children: [
      TextSpan(text: '$greeting, '),
      TextSpan(
        text: shortName,
        style: const TextStyle(color: AppColors.primary),
      ),
    ]);
  }
}

class _HeaderBubble extends StatelessWidget {
  final double size;
  final double opacity;

  const _HeaderBubble({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );
}

class _OnlineButton extends StatelessWidget {
  final bool isOnline;
  final bool toggling;
  final int cooldownSeconds;
  final bool locked;
  final Color color;
  final VoidCallback onTap;

  const _OnlineButton({
    required this.isOnline,
    required this.toggling,
    required this.cooldownSeconds,
    required this.locked,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final coolingDown = cooldownSeconds > 0;
    final enabled = !toggling && !coolingDown && !locked;
    return Semantics(
      button: true,
      enabled: enabled,
      label: locked
          ? 'Tài khoản tạm khóa'
          : coolingDown
              ? 'Có thể đổi trạng thái sau $cooldownSeconds giây'
              : isOnline
                  ? 'Đang Online, chạm để Offline'
                  : 'Đang Offline, chạm để Online',
      child: AnimatedContainer(
        duration: AppDuration.normal,
        width: 88,
        height: 40,
        decoration: BoxDecoration(
          color: locked
              ? AppColors.dangerSoft
              : isOnline
                  ? AppColors.successSoft
                  : Colors.white.withValues(alpha: .82),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Center(
              child: toggling
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: color,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          locked
                              ? Icons.lock_rounded
                              : coolingDown
                                  ? Icons.hourglass_top_rounded
                                  : isOnline
                                      ? Icons.bolt_rounded
                                      : Icons.power_settings_new_rounded,
                          size: 18,
                          color: color,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            locked
                                ? 'Đã khóa'
                                : coolingDown
                                    ? '${cooldownSeconds}s'
                                    : (isOnline ? 'Online' : 'Offline'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.label.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
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
