import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class OfferActions extends StatelessWidget {
  final bool accepting;
  final bool declining;
  final double bottomInset;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const OfferActions({
    super.key,
    required this.accepting,
    required this.declining,
    required this.bottomInset,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md + bottomInset,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F1B1411),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Row(children: [
        SizedBox(
          width: 112,
          height: 58,
          child: OutlinedButton(
            onPressed: accepting || declining ? null : onDecline,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: BorderSide(color: AppColors.danger.withValues(alpha: .35)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: declining
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Từ chối',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                        fontSize: AppFontSize.md, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: SizedBox(
            height: 58,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                disabledBackgroundColor:
                    AppColors.success.withValues(alpha: 0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              onPressed: accepting || declining ? null : onAccept,
              child: accepting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded,
                            size: 24, color: Colors.white),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          'Nhận đơn',
                          style: TextStyle(
                              fontSize: AppFontSize.lg,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ]),
    );
  }
}
