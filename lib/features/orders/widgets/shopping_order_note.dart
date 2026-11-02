import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'formatted_note.dart';

/// Trình bày nội dung đơn Mua hộ từ app khách. Đơn một điểm là mô tả món;
/// đơn nhiều điểm được app khách ghép thành các khối `=== Điểm N: ... ===`.
class ShoppingOrderNote extends StatelessWidget {
  final String note;

  const ShoppingOrderNote({super.key, required this.note});

  static final _stopPattern = RegExp(
    r'={2,}\s*Điểm\s+(\d+)\s*:\s*(.*?)\s*={2,}',
    caseSensitive: false,
    unicode: true,
  );

  @override
  Widget build(BuildContext context) {
    final matches = _stopPattern.allMatches(note).toList();
    final sections = <({String number, String title, String detail})>[
      for (var i = 0; i < matches.length; i++)
        (
          number: matches[i].group(1)!,
          title: matches[i].group(2)!.trim(),
          detail: note
              .substring(
                matches[i].end,
                i + 1 < matches.length ? matches[i + 1].start : note.length,
              )
              .trim(),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.secondarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.secondary.withValues(alpha: .16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(
              Icons.shopping_bag_rounded,
              size: 18,
              color: AppColors.secondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                sections.isEmpty ? 'CẦN MUA' : 'DANH SÁCH CẦN MUA',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.secondary,
                  fontSize: 10,
                  letterSpacing: .55,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (sections.length > 1)
              Text(
                '${sections.length} điểm',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          if (sections.isEmpty)
            FormattedNote(note: note, style: _contentStyle)
          else
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0) ...[
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: AppSpacing.md),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      sections[i].number,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sections[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyStrong.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (sections[i].detail.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          FormattedNote(
                            note: sections[i].detail,
                            style: _contentStyle,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }

  static final _contentStyle = AppTextStyles.body.copyWith(
    color: AppColors.textPrimary,
    height: 1.45,
    fontWeight: FontWeight.w600,
  );
}
