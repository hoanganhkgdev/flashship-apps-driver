import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/market_order.dart';
import '../providers/order_market_provider.dart';

class OrderMarketScreen extends ConsumerWidget {
  const OrderMarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(orderMarketProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.read(orderMarketProvider.notifier).fetch(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chợ đơn', style: AppTextStyles.screenTitle),
                    const SizedBox(height: 6),
                    Text(
                      'Đơn đã phát nhiều lần nhưng chưa có tài xế nhận. Ai bấm nhận trước sẽ được giao đơn.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (state.mainOrderId != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Phiên gom chuyến #${state.mainOrderId}: còn ${state.extrasRemaining} lượt nhận đơn phụ${state.sessionExpiresAt == null ? '' : ' · hết lúc ${TimeOfDay.fromDateTime(state.sessionExpiresAt!.toLocal()).format(context)}'}',
                          style: AppTextStyles.bodyStrong
                              .copyWith(color: AppColors.primaryDark),
                        ),
                      )
                    else
                      Text(
                        'Nhận một offer chính để mở phiên gom chuyến.',
                        style: AppTextStyles.label
                            .copyWith(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ),
            if (state.loading && state.orders.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.error != null && state.orders.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _Message(
                  icon: Icons.cloud_off_rounded,
                  title: state.error!,
                  action: () => ref.read(orderMarketProvider.notifier).fetch(),
                ),
              )
            else if (state.orders.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _Message(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Chưa có đơn phù hợp',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: state.orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final order = state.orders[index];
                    return _MarketCard(
                      order: order,
                      claiming: state.claimingId == order.id,
                      disabled: state.claimingId != null,
                      onClaim: () => _claim(context, ref, order),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _claim(
      BuildContext context, WidgetRef ref, MarketOrder order) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Nhận đơn này?'),
            content: Text(
                'Bạn sẽ nhận đơn ${order.code} với thu nhập dự kiến ${Fmt.currency(order.estimatedIncome)}.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Để sau'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Nhận đơn'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;

    final error = await ref.read(orderMarketProvider.notifier).claim(order.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? 'Đã nhận đơn ${order.code}'),
      backgroundColor: error == null ? AppColors.success : AppColors.danger,
    ));
  }
}

class _MarketCard extends StatelessWidget {
  final MarketOrder order;
  final bool claiming;
  final bool disabled;
  final VoidCallback onClaim;

  const _MarketCard({
    required this.order,
    required this.claiming,
    required this.disabled,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFF0E8E3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Fmt.serviceIcon(order.serviceType),
                  color: Fmt.serviceColor(order.serviceType)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    '${Fmt.serviceLabel(order.serviceType)} • ${order.code}',
                    style: AppTextStyles.sectionTitle),
              ),
              Text(Fmt.currency(order.estimatedIncome),
                  style: AppTextStyles.sectionTitle.copyWith(
                      color: AppColors.success, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 14),
            _Address(icon: Icons.storefront_rounded, text: order.pickupAddress),
            const SizedBox(height: 9),
            _Address(
                icon: Icons.location_on_rounded, text: order.deliveryAddress),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _Chip(
                  '${order.pickupDistanceKm.toStringAsFixed(1)} km tới điểm lấy'),
              if (order.distance != null)
                _Chip('${order.distance!.toStringAsFixed(1)} km chuyến'),
              if (order.codAmount > 0)
                _Chip('Thu hộ ${Fmt.currency(order.codAmount)}'),
              if (order.isFreeship) const _Chip('Freeship'),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: disabled ? null : onClaim,
                child: claiming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Nhận đơn'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Address extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Address({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text.isEmpty ? 'Không có địa chỉ giao' : text)),
        ],
      );
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(text, style: AppTextStyles.caption),
      );
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? action;
  const _Message({required this.icon, required this.title, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 54, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: action, child: const Text('Thử lại')),
            ],
          ]),
        ),
      );
}
