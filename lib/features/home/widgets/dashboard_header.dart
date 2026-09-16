import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';
import '../../auth/models/driver_model.dart';

class DashboardHeader extends StatelessWidget {
  final DriverModel? user;
  final bool isOnline;
  final bool toggling;
  final bool locked;
  final String? locationIssue;
  final VoidCallback onToggle;

  const DashboardHeader(
      {super.key,
      required this.user,
      required this.isOnline,
      required this.toggling,
      required this.locked,
      required this.locationIssue,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final initials = user?.initials ?? 'TX';
    final vehicleLabel = switch (user?.vehicleType) {
      'car' => 'Ô tô',
      'motorbike' => 'Xe máy',
      _ => 'Chưa cập nhật loại xe',
    };
    final plate = user?.licensePlate?.trim().toUpperCase();
    final vehicleInfo = plate != null && plate.isNotEmpty
        ? '$plate · $vehicleLabel'
        : vehicleLabel;
    final gpsReady = locationIssue == null;
    final statusColor = locked
        ? AppColors.danger
        : isOnline && !gpsReady
            ? AppColors.warning
            : isOnline
                ? AppColors.success
                : AppColors.textSecondary;
    final statusLabel = locked
        ? 'Tạm khóa hoạt động'
        : isOnline && !gpsReady
            ? 'Tạm ngừng nhận đơn · kiểm tra GPS'
            : isOnline
                ? 'Sẵn sàng nhận đơn'
                : 'Chưa nhận đơn';
    final gpsLabel = gpsReady
        ? 'GPS sẵn sàng'
        : locationIssue == 'service'
            ? 'GPS đang tắt'
            : locationIssue == 'background_permission'
                ? 'GPS chưa được phép chạy nền'
                : 'Chưa cấp quyền GPS';
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.soft,
      ),
      padding: EdgeInsets.fromLTRB(AppSpacing.lg,
          MediaQuery.paddingOf(context).top + AppSpacing.md, AppSpacing.lg, 0),
      child: Column(children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: Color(0xFFFFE8DF), shape: BoxShape.circle),
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            child: user?.profilePhotoUrl != null
                ? Image.network(user!.profilePhotoUrl!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _Initials(initials))
                : _Initials(initials),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(user?.name ?? 'Tài xế',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong),
                const SizedBox(height: 2),
                Text(vehicleInfo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.textSecondary)),
              ])),
          Tooltip(
            message: gpsLabel,
            child: Semantics(
              label: gpsLabel,
              child: AppIconBadge(
                icon: gpsReady
                    ? Icons.gps_fixed_rounded
                    : Icons.location_off_rounded,
                color: gpsReady ? AppColors.success : AppColors.warning,
              ),
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        Material(
          color: locked
              ? AppColors.dangerSoft
              : isOnline && !gpsReady
                  ? AppColors.warningSoft
                  : isOnline
                      ? AppColors.successSoft
                      : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: (toggling || locked) ? null : onToggle,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Row(children: [
                AppIconBadge(
                  icon: locked
                      ? Icons.lock_rounded
                      : isOnline
                          ? Icons.wifi_tethering_rounded
                          : Icons.power_settings_new_rounded,
                  color: statusColor,
                  backgroundColor: Colors.white.withValues(alpha: 0.78),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locked
                            ? 'Đang khóa'
                            : isOnline && !gpsReady
                                ? 'Online · mất GPS'
                                : isOnline
                                    ? 'Đang online'
                                    : 'Đang offline',
                        style: AppTextStyles.sectionTitle
                            .copyWith(color: statusColor),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(statusLabel,
                          style: AppTextStyles.label.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                if (toggling)
                  const SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                else
                  Switch(
                    value: isOnline && !locked,
                    onChanged: (toggling || locked) ? null : (_) => onToggle(),
                  ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ]),
    );
  }
}

class _Initials extends StatelessWidget {
  final String text;
  const _Initials(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: AppTextStyles.screenTitle
          .copyWith(color: AppColors.primary, fontSize: AppFontSize.lg));
}
