import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import 'history_completed_card.dart';
import 'history_overview_header.dart';

/// Danh sách đơn đã hoàn thành, nhóm theo ngày, dùng làm tab con "Hoàn thành"
/// của màn chủ. Việc tải thêm khi cuộn do màn chủ điều khiển.
class CompletedOrdersSliver extends ConsumerWidget {
  const CompletedOrdersSliver({super.key});

  static String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return 'Hôm nay';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day) {
      return 'Hôm qua';
    }
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  static List<Object> _buildItems(List<OrderModel> orders) {
    final groups = <String, List<OrderModel>>{};
    final keys = <String>[];
    for (final o in orders) {
      final key = _dateLabel(o.completedAt ?? o.createdAt);
      if (!groups.containsKey(key)) {
        groups[key] = [];
        keys.add(key);
      }
      groups[key]!.add(o);
    }
    final items = <Object>[];
    for (final key in keys) {
      final total = groups[key]!.fold<int>(0, (s, o) => s + o.driverEarning);
      items.add((key, '${groups[key]!.length} đơn · ${Fmt.currency(total)}'));
      items.addAll(groups[key]!);
    }
    return items;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(orderHistoryProvider);
    final completed = history.orders.where((o) => o.isCompleted).toList();

    final now = DateTime.now();
    final today = completed.where((o) {
      final dt = (o.completedAt ?? o.createdAt).toLocal();
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }).toList();
    final todayEarnings = today.fold<int>(0, (s, o) => s + o.driverEarning);
    final items = _buildItems(completed);

    if (completed.isEmpty) {
      return SliverToBoxAdapter(
        child: history.loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2)),
              )
            : EmptyState(
                icon: Icons.receipt_long_rounded,
                iconColor: AppColors.primary.withValues(alpha: 0.45),
                iconBgColor: AppColors.primary.withValues(alpha: 0.08),
                circleSize: 76,
                iconSize: 36,
                title: 'Chưa có đơn hoàn thành',
                titleFontSize: 16,
                subtitle: 'Các đơn đã hoàn thành sẽ hiện ở đây',
                actionLabel: 'Tải lại',
                actionColor: AppColors.primary,
                onAction: () => ref
                    .read(orderHistoryProvider.notifier)
                    .fetch(refresh: true),
              ),
      );
    }

    return SliverMainAxisGroup(slivers: [
      SliverToBoxAdapter(
        child: HistoryOverviewHeader(
          todayCount: today.length,
          todayEarnings: todayEarnings,
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) {
            if (i < items.length) {
              final item = items[i];
              if (item is (String, String)) {
                return HistoryDateLabel(label: item.$1, summary: item.$2);
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: HistoryCompletedCard(order: item as OrderModel),
              );
            }
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2)),
            );
          },
          childCount: items.length + (history.hasMore ? 1 : 0),
        ),
      ),
    ]);
  }
}
