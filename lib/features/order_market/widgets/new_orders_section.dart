import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../home/providers/home_providers.dart';
import '../models/market_order.dart';
import '../providers/order_market_provider.dart';
import 'market_order_card.dart';

/// Khối "Đơn mới" — nội dung chính của màn hình chủ. Hiện mọi đơn đang chờ
/// trong khu vực để tài xế tự chọn nhận; tự cập nhật theo thời gian thực.
class NewOrdersSection extends ConsumerWidget {
  final bool isOnline;
  final bool locked;
  final bool togglingOnline;
  final VoidCallback onGoOnline;

  const NewOrdersSection({
    super.key,
    required this.isOnline,
    required this.locked,
    required this.togglingOnline,
    required this.onGoOnline,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(orderMarketProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (locked)
          const _Notice(
            icon: Icons.lock_outline_rounded,
            color: AppColors.danger,
            title: 'Tạm khóa nhận đơn',
            message: 'Thanh toán công nợ quá hạn để tiếp tục nhận đơn.',
          )
        else if (!isOnline)
          _Notice(
            icon: Icons.power_settings_new_rounded,
            color: AppColors.primary,
            title: 'Sẵn sàng chạy đơn?',
            message:
                'Chuyển sang Online để nhận đơn gần bạn và bắt đầu tính thời gian hoạt động.',
            actionLabel: 'Bắt đầu nhận đơn',
            onAction: togglingOnline ? null : onGoOnline,
            loading: togglingOnline,
          )
        else if (state.loading && state.orders.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.error != null && state.orders.isEmpty)
          _Notice(
            icon: Icons.cloud_off_rounded,
            color: AppColors.warning,
            title: state.error!,
            message: 'Kiểm tra kết nối mạng rồi thử lại.',
            actionLabel: 'Thử lại',
            onAction: () => ref.read(orderMarketProvider.notifier).fetch(),
          )
        else if (state.orders.isEmpty)
          _Notice(
            icon: Icons.notifications_active_outlined,
            color: AppColors.primary,
            title: 'Chưa có đơn mới',
            message: 'Đơn mới sẽ hiện ngay tại đây và có thông báo đến bạn.',
          )
        else ...[
          for (final order in state.orders) ...[
            MarketOrderCard(
              order: order,
              claiming: state.claimingId == order.id,
              disabled: state.claimingId != null,
              onClaim: () => _claim(context, ref, order),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ],
    );
  }

  Future<void> _claim(
      BuildContext context, WidgetRef ref, MarketOrder order) async {
    final error = await ref.read(orderMarketProvider.notifier).claim(order.id);
    if (!context.mounted) return;
    // Nhận thành công → chuyển sang tab "Đang chạy" để thấy đơn vừa nhận.
    if (error == null) ref.read(homeOrdersTabProvider.notifier).state = 1;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? 'Đã nhận đơn ${order.code}'),
      backgroundColor: error == null ? AppColors.success : AppColors.danger,
    ));
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  const _Notice({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.xl2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 34, color: color),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(title,
            textAlign: TextAlign.center, style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.xs),
        Text(message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
        if (onAction != null || loading) ...[
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: loading ? null : onAction,
              icon: loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Icon(Icons.bolt_rounded),
              label: Text(actionLabel ?? 'Thử lại'),
            ),
          ),
        ],
      ]),
    );
  }
}
