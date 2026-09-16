import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Icon + label + value dùng cho _TopupBody trong order_offer_screen.
class InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const InfoRow(
      {super.key,
      required this.icon,
      required this.iconColor,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const SizedBox(height: AppSpacing.xxs),
                Text(label,
                    style: const TextStyle(
                        fontSize: AppFontSize.xs,
                        color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.xxs),
                Text(value,
                    style: const TextStyle(
                        fontSize: AppFontSize.base,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ])),
        ],
      );
}

class CargoBadge extends StatelessWidget {
  final String cargoType;
  final String? cargoNote;
  final double? cargoWeight;
  const CargoBadge(
      {super.key, required this.cargoType, this.cargoNote, this.cargoWeight});

  static const _info = {
    'food': (Icons.lunch_dining_rounded, 'Đồ ăn', AppColors.amber),
    'flowers': (
      Icons.local_florist_rounded,
      'Giỏ hoa / Trái cây / Bó hoa',
      Color(0xFFEC4899)
    ),
    'parcel': (
      Icons.inventory_2_rounded,
      'Bưu kiện / Thùng / Kệ hoa',
      AppColors.slate
    ),
  };

  @override
  Widget build(BuildContext context) {
    final entry = _info[cargoType];
    if (entry == null) return const SizedBox.shrink();
    final (icon, label, color) = entry;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: AppFontSize.base,
                  fontWeight: FontWeight.w700,
                  color: color)),
          if (cargoWeight != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
                'Khoảng ${cargoWeight!.toStringAsFixed(cargoWeight! % 1 == 0 ? 0 : 1)} kg',
                style: const TextStyle(
                    fontSize: AppFontSize.sm, color: AppColors.textSecondary)),
          ],
          if (cargoNote != null && cargoNote!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(cargoNote!,
                style: const TextStyle(
                    fontSize: AppFontSize.sm, color: AppColors.textSecondary)),
          ],
        ])),
      ]),
    );
  }
}
