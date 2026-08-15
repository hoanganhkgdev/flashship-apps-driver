import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class OfferActions extends StatelessWidget {
  final bool accepting;
  final double bottomInset;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const OfferActions({
    super.key,
    required this.accepting,
    required this.bottomInset,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: accepting ? null : onAccept,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_rounded, size: 22, color: Colors.white),
                SizedBox(width: 8),
                Text('Nhận đơn ngay',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onDecline,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Bỏ qua',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          ),
        ),
      ]),
    );
  }
}
