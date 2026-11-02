import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../providers/shift_provider.dart';

/// Thanh nhỏ dưới header: còn bao nhiêu phút được Offline trong ca hiện tại.
/// Đang Offline thì đếm ngược từng giây; Online thì giữ nguyên số còn lại.
class OfflineBudgetBanner extends ConsumerStatefulWidget {
  final bool compact;

  const OfflineBudgetBanner({super.key, this.compact = false});

  @override
  ConsumerState<OfflineBudgetBanner> createState() =>
      _OfflineBudgetBannerState();
}

class _OfflineBudgetBannerState extends ConsumerState<OfflineBudgetBanner> {
  Timer? _timer;
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _ticks++;
      final status = ref.read(shiftProvider).offlineStatus;
      final isOnline = ref.read(authProvider).user?.isOnline ?? false;
      // Hết giờ được Offline mà server chưa ghi phạt: hỏi lại mỗi 20 giây để
      // hiện kết quả (khoản phạt vào công nợ).
      if (status != null &&
          !status.penalized &&
          !status.exempt &&
          status.remainingSeconds(isOnline: isOnline) == 0 &&
          _ticks % 20 == 0) {
        ref.read(shiftProvider.notifier).fetch();
        ref.read(walletProvider.notifier).fetch();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String _mmss(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(shiftProvider.select((s) => s.offlineStatus));
    final isOnline =
        ref.watch(authProvider.select((s) => s.user?.isOnline ?? false));
    final now = DateTime.now();
    if (status == null ||
        status.exempt ||
        status.limitSeconds <= 0 ||
        !status.isActiveAt(now)) {
      return const SizedBox.shrink();
    }

    final remaining = status.remainingSeconds(isOnline: isOnline, now: now);
    final limitMin = (status.limitSeconds / 60).round();
    final penalty = Fmt.currency(status.penaltyAmount);

    late final Color color;
    late final Color bg;
    late final IconData icon;
    late final String text;
    if (status.penalized) {
      color = AppColors.danger;
      bg = AppColors.dangerSoft;
      icon = Icons.gavel_rounded;
      text =
          '${status.shiftName}: đã Offline quá $limitMin phút, bị phạt $penalty (ghi vào Công nợ)';
    } else if (remaining == 0) {
      color = AppColors.danger;
      bg = AppColors.dangerSoft;
      icon = Icons.warning_amber_rounded;
      text =
          '${status.shiftName}: đã quá $limitMin phút Offline — phạt $penalty đang được ghi';
    } else if (isOnline) {
      final low = remaining <= 5 * 60;
      color = low ? AppColors.warning : AppColors.success;
      bg = low ? AppColors.warningSoft : AppColors.successSoft;
      icon = Icons.timer_outlined;
      text =
          '${status.shiftName}: còn ${(remaining / 60).ceil()} phút được Offline (tối đa $limitMin phút/ca)';
    } else {
      final low = remaining <= 5 * 60;
      color = low ? AppColors.danger : AppColors.warning;
      bg = low ? AppColors.dangerSoft : AppColors.warningSoft;
      icon = Icons.timer_rounded;
      text =
          '${status.shiftName}: đang Offline — còn ${_mmss(remaining)} trước khi bị phạt $penalty';
    }

    if (widget.compact) {
      final compactText = status.penalized
          ? '${status.shiftName} · Đã phạt $penalty'
          : remaining == 0
              ? '${status.shiftName} · Đã hết thời gian Offline'
              : isOnline
                  ? '${status.shiftName} · Còn ${(remaining / 60).ceil()} phút Offline'
                  : '${status.shiftName} · Offline còn ${_mmss(remaining)}';
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: Colors.white.withValues(alpha: .55)),
        ),
        child: Row(children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              compactText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(
                color: status.penalized || remaining == 0
                    ? color
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ]),
      );
    }

    final progress = status.limitSeconds == 0
        ? 0.0
        : (remaining / status.limitSeconds).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text,
                style: AppTextStyles.label
                    .copyWith(color: color, fontWeight: FontWeight.w700)),
          ),
        ]),
        if (!status.penalized) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ],
      ]),
    );
  }
}
