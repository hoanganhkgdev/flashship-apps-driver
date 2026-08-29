import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.30)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.sticky_note_2_outlined,
              size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                      letterSpacing: 0.5,
                    )),
                const SizedBox(height: 4),
                PhoneLinkText(
                  text: note,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textPrimary, height: 1.5),
                ),
              ])),
        ]),
      );
}
