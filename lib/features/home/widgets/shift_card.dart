import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../shifts/models/shift_model.dart';
import 'surface_card.dart';

class ShiftCard extends StatelessWidget {
  final List<ShiftModel> shifts;
  final List<int> currentShiftIds;
  final bool hasLoadedOnce;
  final VoidCallback onTap;

  const ShiftCard({
    super.key,
    required this.shifts,
    required this.currentShiftIds,
    required this.hasLoadedOnce,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Chưa fetch xong lần đầu → ẩn hẳn, tránh nháy sang trạng thái "chưa
    // đăng ký" sai trong lúc đợi dữ liệu thật.
    if (!hasLoadedOnce) return const SizedBox.shrink();

    final registered =
        shifts.where((s) => currentShiftIds.contains(s.id)).toList();
    final isRegistered = registered.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: surfaceCard(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Ca làm việc',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  )),
              const SizedBox(height: 8),
              if (isRegistered)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: registered
                      .map((s) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('${s.name} · ${s.timeRange}',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                )),
                          ))
                      .toList(),
                )
              else ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Chưa đăng ký',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warning,
                      )),
                ),
                const SizedBox(height: 5),
                const Text('Bấm để đăng ký ca làm việc',
                    style: TextStyle(
                        fontSize: 13.5, color: AppColors.textSecondary)),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textTertiary),
          ),
        ]),
      ),
    );
  }
}
