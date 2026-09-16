import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_surface_card.dart';
import 'phone_link_text.dart';

/// Card ghi chú đơn hàng, dùng chung cho active_order_screen và
/// order_offer_screen — trước đây là 2 widget gần như y hệt (_NoteCard/
/// _NoteRow) chỉ khác padding/border/shadow do trôi dạt copy-paste, không
/// phải khác biệt thiết kế thật. Style ở đây lấy theo bản active_order
/// (đầy đủ hơn: có boxShadow, guard canLaunchUrl trước khi gọi).
class OrderNoteCard extends StatelessWidget {
  final String note;
  final String label;

  const OrderNoteCard({super.key, required this.note, this.label = 'GHI CHÚ'});

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
        color: const Color(0xFFFFFCF3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.sticky_note_2_outlined,
              size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.warning, letterSpacing: .5)),
                const SizedBox(height: AppSpacing.xs),
                PhoneLinkText(
                  text: note,
                  style:
                      AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                ),
              ])),
        ]),
      );
}
