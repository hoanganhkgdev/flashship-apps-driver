import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/home_providers.dart';
import '../../orders/providers/order_provider.dart';
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
    // Đang chạy đủ số đơn tối đa của khu vực: backend sẽ từ chối nhận thêm,
    // nên khoá nút vuốt và nói rõ lý do thay vì để tài xế vuốt rồi bị báo lỗi.
    final maxActive =
        ref.watch(authProvider.select((s) => s.user?.maxActiveOrders));
    final activeCount =
        ref.watch(activeOrderProvider.select((s) => s.orders.length));
    final atLimit = maxActive != null && activeCount >= maxActive;

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
          if (atLimit) ...[
            _Banner(
              icon: Icons.inventory_2_outlined,
              color: AppColors.warning,
              text:
                  'Bạn đang chạy đủ $maxActive đơn. Hoàn thành bớt đơn để nhận thêm.',
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (state.error != null) ...[
            _Banner(
              icon: Icons.cloud_off_rounded,
              color: AppColors.danger,
              text: 'Mất kết nối, danh sách có thể chưa mới.',
              actionLabel: 'Thử lại',
              onAction: () => ref.read(orderMarketProvider.notifier).fetch(),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          for (final order in state.orders) ...[
            MarketOrderCard(
              order: order,
              claiming: state.claimingId == order.id,
              disabled: state.claimingId != null || atLimit,
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

/// Dải cảnh báo gọn phía trên danh sách (danh sách vẫn hiện bên dưới).
class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Banner({
    required this.icon,
    required this.color,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text,
              style:
                  AppTextStyles.caption.copyWith(color: color, height: 1.35)),
        ),
        if (onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: color,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(actionLabel ?? 'Thử lại'),
          ),
      ]),
    );
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
