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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFFFCF6F3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: loadFailed || (hasError && selected == null)
                      ? AppColors.danger
                      : selected != null
                          ? const Color(0xFFFF6035)
                          : const Color(0xFFE5DDD9),
                  width: selected != null ? 1.2 : 1,
                ),
              ),
              child: Row(children: [
                Icon(
                  loadFailed
                      ? Icons.refresh_rounded
                      : Icons.location_on_outlined,
                  size: 21,
                  color:
                      loadFailed ? AppColors.danger : const Color(0xFF17110F),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: loading
                      ? Row(children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: Colors.grey.shade400),
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
                            fontSize: 16,
                            fontWeight: selected != null
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: loadFailed
                                ? AppColors.danger
                                : selected != null
                                    ? const Color(0xFF1B1411)
                                    : const Color(0xFFA99F9A),
                          ),
                        ),
                ),
                if (!loadFailed)
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF17110F),
                    size: 22,
                  ),
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
