import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
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

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Chào buổi sáng';
    if (h < 14) return 'Chào buổi trưa';
    if (h < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  @override
  Widget build(BuildContext context) {
    final initials = user?.initials ?? 'TX';
    final isCar = user?.vehicleType == 'car';
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
    final active = isOnline && !locked;

    final statusColor = locked
        ? AppColors.danger
        : isOnline && !gpsReady
            ? AppColors.warning
            : isOnline
                ? AppColors.success
                : AppColors.textSecondary;
    final statusBg = locked
        ? AppColors.dangerSoft
        : isOnline && !gpsReady
            ? AppColors.warningSoft
            : isOnline
                ? AppColors.successSoft
                : AppColors.surfaceAlt;
    final statusTitle = locked
        ? 'Đang khóa'
        : isOnline && !gpsReady
            ? 'Online · mất GPS'
            : isOnline
                ? 'Đang online'
                : 'Đang offline';
    final statusLabel = locked
        ? 'Tạm khóa hoạt động'
        : isOnline && !gpsReady
            ? 'Tạm ngừng nhận đơn · kiểm tra GPS'
            : isOnline
                ? 'Sẵn sàng nhận đơn'
                : 'Gạt công tắc để bắt đầu nhận đơn';
    final gpsLabel = gpsReady
        ? 'GPS sẵn sàng'
        : locationIssue == 'service'
            ? 'GPS đang tắt'
            : locationIssue == 'background_permission'
                ? 'GPS chưa được phép chạy nền'
                : 'Chưa cấp quyền GPS';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Color(0x181B1411), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          MediaQuery.paddingOf(context).top + AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          // Avatar có viền màu theo trạng thái + chấm online.
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 50,
              height: 50,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: active ? AppColors.success : AppColors.divider,
                    width: 2),
              ),
              child: ClipOval(
                child: ColoredBox(
                  color: AppColors.primarySoft,
                  child: user?.profilePhotoUrl != null
                      ? Image.network(user!.profilePhotoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _Initials(initials))
                      : _Initials(initials),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
              ),
            ),
          ]),
          const SizedBox(width: AppSpacing.md),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(_greeting(),
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 1),
                Text(user?.name ?? 'Tài xế',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.sectionTitle
                        .copyWith(fontSize: AppFontSize.lg)),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(
                      isCar
                          ? Icons.directions_car_filled_outlined
                          : Icons.two_wheeler_rounded,
                      size: 15,
                      color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(vehicleInfo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label
                            .copyWith(color: AppColors.textSecondary)),
                  ),
                ]),
              ])),
          const SizedBox(width: AppSpacing.sm),
          Tooltip(
            message: gpsLabel,
            child: Semantics(
              label: gpsLabel,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      gpsReady ? AppColors.successSoft : AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      gpsReady
                          ? Icons.gps_fixed_rounded
                          : Icons.location_off_rounded,
                      size: 15,
                      color: gpsReady ? AppColors.success : AppColors.warning),
                  const SizedBox(width: 4),
                  Text('GPS',
                      style: AppTextStyles.label.copyWith(
                          fontWeight: FontWeight.w800,
                          color: gpsReady
                              ? AppColors.success
                              : AppColors.warning)),
                ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        // Thẻ trạng thái nhận đơn — toàn bộ thẻ là vùng chạm lớn.
        AnimatedContainer(
          duration: AppDuration.normal,
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: statusColor.withValues(alpha: 0.22)),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: (toggling || locked) ? null : onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      locked
                          ? Icons.lock_rounded
                          : isOnline
                              ? Icons.wifi_tethering_rounded
                              : Icons.power_settings_new_rounded,
                      size: 24,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(statusTitle,
                            style: AppTextStyles.sectionTitle
                                .copyWith(color: statusColor)),
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
                      value: active,
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppColors.success,
                      onChanged:
                          (toggling || locked) ? null : (_) => onToggle(),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Initials extends StatelessWidget {
  final String text;
  const _Initials(this.text);
  @override
  Widget build(BuildContext context) => Center(
        child: Text(text,
            style: AppTextStyles.screenTitle
                .copyWith(color: AppColors.primary, fontSize: AppFontSize.lg)),
      );
}
