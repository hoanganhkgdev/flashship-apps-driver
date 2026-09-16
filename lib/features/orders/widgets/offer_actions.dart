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
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md + bottomInset,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Color(0x0F1B1411),
            blurRadius: 14,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(children: [
        SizedBox(
            width: 112,
            child: SizedBox(
                height: AppSize.buttonHeight,
                child: OutlinedButton(
                  onPressed: accepting || declining ? null : onDecline,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.divider),
                      shape: const StadiumBorder()),
                  child: declining
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text(
                          'Từ chối',
                          maxLines: 1,
                          softWrap: false,
                        ),
                ))),
        const SizedBox(width: AppSpacing.md),
        Expanded(
            child: SizedBox(
          height: AppSize.buttonHeight,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: const StadiumBorder(),
            ),
            onPressed: accepting || declining ? null : onAccept,
            child: accepting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_rounded, size: 20, color: Colors.white),
                      SizedBox(width: AppSpacing.sm),
                      Text(
                        'Nhận đơn',
                        style: AppTextStyles.sectionTitle,
                      ),
                    ],
                  ),
          ),
        )),
      ]),
    );
  }
}
