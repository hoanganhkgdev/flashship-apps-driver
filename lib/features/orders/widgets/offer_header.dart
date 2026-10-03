import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/order_model.dart';

/// Đầu màn nhận đơn: thu nhập nổi bật + vòng đếm ngược. Dưới 5 giây chuyển
/// sang đỏ và vòng đếm nhấp nháy để tài xế biết sắp hết hạn.
class OfferHeader extends StatelessWidget {
  final OrderModel order;
  final int remaining;
  final double progress;
  final bool isUrgent;
  final Animation<double> pulse;
  final double topInset;

  const OfferHeader({
    super.key,
    required this.order,
    required this.remaining,
    required this.progress,
    required this.isUrgent,
    required this.pulse,
    required this.topInset,
  });

  @override
  Widget build(BuildContext context) {
    final colors = isUrgent
        ? const [Color(0xFFC92A32), Color(0xFFE5483F)]
        : const [AppColors.primary, Color(0xFFFF8A3D)];

    return AnimatedContainer(
      duration: AppDuration.normal,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        topInset + AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.notifications_active_rounded,
                    size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text('ĐƠN MỚI',
                    style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withValues(alpha: .9),
                        letterSpacing: .8,
                        fontWeight: FontWeight.w800)),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(order.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label.copyWith(
                          color: Colors.white.withValues(alpha: .75))),
                ),
              ]),
              const SizedBox(height: AppSpacing.md),
              Text('Bạn nhận được',
                  style: AppTextStyles.label
                      .copyWith(color: Colors.white.withValues(alpha: .85))),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(Fmt.currency(order.driverEarning),
                    style: AppTextStyles.metricLarge
                        .copyWith(color: Colors.white, fontSize: 40)),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        _CountdownRing(
          remaining: remaining,
          progress: progress,
          isUrgent: isUrgent,
          pulse: pulse,
        ),
      ]),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  final int remaining;
  final double progress;
  final bool isUrgent;
  final Animation<double> pulse;

  const _CountdownRing({
    required this.remaining,
    required this.progress,
    required this.isUrgent,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: pulse,
        builder: (_, __) => Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white
                .withValues(alpha: isUrgent ? .18 + pulse.value * .14 : .18),
          ),
          child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  color: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: .25),
                ),
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$remaining',
                  style: AppTextStyles.metric
                      .copyWith(color: Colors.white, fontSize: 26, height: 1)),
              Text('giây',
                  style: AppTextStyles.caption
                      .copyWith(color: Colors.white.withValues(alpha: .85))),
            ]),
          ]),
        ),
      );
}
