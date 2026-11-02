import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'formatted_note.dart';

/// Khối thông tin chuẩn cho đơn tổng đài: điểm lấy, dẫn đường và ghi chú được
/// tách rõ để tài xế đọc nhanh trước khi nhận hoặc trong lúc thực hiện đơn.
class CallCenterPickupDetails extends StatelessWidget {
  final String pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String? note;
  final VoidCallback? onOpenMap;

  const CallCenterPickupDetails({
    super.key,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.note,
    this.onOpenMap,
  });

  bool get _hasCoordinates => pickupLat != null && pickupLng != null;
  bool get _hasAddress => pickupAddress.trim().isNotEmpty;
  bool get _hasNote => note?.trim().isNotEmpty == true;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(Icons.location_on_rounded,
                          size: 19, color: AppColors.primary),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ĐIỂM LẤY',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryDark,
                              fontSize: 9,
                              letterSpacing: .7,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _hasAddress
                                ? pickupAddress.trim()
                                : 'Điểm lấy được mô tả trong ghi chú bên dưới',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyStrong.copyWith(
                              color: _hasAddress
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  if (_hasCoordinates) ...[
                    const SizedBox(height: AppSpacing.md),
                    Material(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: InkWell(
                        onTap: onOpenMap,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 10,
                          ),
                          child: Row(children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.navigation_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dẫn đường đến điểm lấy',
                                    style: AppTextStyles.label.copyWith(
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Mở vị trí bằng ứng dụng bản đồ',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 22,
                              color: AppColors.primary,
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              color: _hasNote ? AppColors.warningSoft : AppColors.dangerSoft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _hasNote
                        ? Icons.sticky_note_2_outlined
                        : Icons.report_gmailerrorred_rounded,
                    size: 19,
                    color: _hasNote ? AppColors.warning : AppColors.danger,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GHI CHÚ TỔNG ĐÀI',
                          style: AppTextStyles.caption.copyWith(
                            color:
                                _hasNote ? AppColors.warning : AppColors.danger,
                            fontSize: 9,
                            letterSpacing: .7,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (_hasNote)
                          FormattedNote(
                            note: note!.trim(),
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          )
                        else
                          Text(
                            'Chưa có ghi chú. Hãy kiểm tra kỹ trước khi nhận đơn.',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
