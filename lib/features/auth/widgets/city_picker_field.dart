import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'city_sheet.dart';

class CityPickerField extends StatelessWidget {
  final City? selected;
  final bool loading;
  final bool loadFailed;
  final bool hasError;
  final VoidCallback onTap;

  const CityPickerField({
    super.key,
    required this.selected,
    required this.loading,
    required this.loadFailed,
    required this.hasError,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: loading ? null : onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: (loadFailed || (hasError && selected == null) || selected != null)
                    ? Border.all(
                        color: loadFailed || (hasError && selected == null)
                            ? AppColors.danger
                            : AppColors.primary,
                        width: 1.8,
                      )
                    : null,
              ),
              child: Row(children: [
                Icon(
                  loadFailed ? Icons.refresh_rounded : Icons.location_city_outlined,
                  size: 20,
                  color: loadFailed
                      ? AppColors.danger
                      : selected != null
                          ? AppColors.primary
                          : AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: loading
                      ? Row(children: [
                          SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.grey.shade400),
                          ),
                          const SizedBox(width: 8),
                          const Text('Đang tải...',
                              style: TextStyle(
                                  fontSize: 17,
                                  color: AppColors.textSecondary)),
                        ])
                      : Text(
                          loadFailed
                              ? 'Không tải được khu vực — Nhấn để thử lại'
                              : selected?.name ?? 'Chọn khu vực',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: selected != null ? FontWeight.w500 : FontWeight.w400,
                            color: loadFailed
                                ? AppColors.danger
                                : selected != null
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                          ),
                        ),
                ),
                if (!loadFailed)
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary, size: 20),
              ]),
            ),
          ),
          if (hasError && selected == null && !loadFailed) ...[
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('Vui lòng chọn khu vực',
                  style: TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
          ],
        ],
      );
}
