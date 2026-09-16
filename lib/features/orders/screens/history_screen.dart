import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/app_root_header_title.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import '../widgets/history_overview_header.dart';
import '../widgets/history_completed_card.dart';
import '../../home/widgets/bottom_nav.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(orderHistoryProvider.notifier).fetch(refresh: true));
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 150) {
      ref.read(orderHistoryProvider.notifier).fetch();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _dateLabel(DateTime dt) {
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

  List<Object> _buildItems(List<OrderModel> orders) {
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
      items.add(key);
      items.addAll(groups[key]!);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(orderHistoryProvider);
    final allOrders = historyState.orders;

    final now = DateTime.now();
    final allCompleted = allOrders.where((o) => o.isCompleted);
    final todayOrders = allCompleted.where((o) {
      final dt = (o.completedAt ?? o.createdAt).toLocal();
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }).toList();
    final todayEarnings =
        todayOrders.fold<int>(0, (s, o) => s + o.driverEarning);
    final todayOrderCount = todayOrders.length;

    final completedOrders = allOrders.where((o) => o.isCompleted).toList();
    final items = _buildItems(completedOrders);

    final isLoading = historyState.loading;
    final isEmpty = completedOrders.isEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        // Header giờ nền trắng (trước là gradient cam) — icon status bar phải
        // đổi sang màu đen mới nhìn thấy được, không còn dùng icon trắng nữa.
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(children: [
          const AppRootHeader(title: 'Lịch sử'),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () =>
                  ref.read(orderHistoryProvider.notifier).fetch(refresh: true),
              child: CustomScrollView(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: HistoryOverviewHeader(
                      todayCount: todayOrderCount,
                      todayEarnings: todayEarnings,
                    ),
                  ),

                  // Loading
                  if (isLoading && isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary, strokeWidth: 2)),
                    ),

                  // Empty — completed tab
                  if (!isLoading && isEmpty)
                    SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.receipt_long_rounded,
                        iconColor: AppColors.primary.withValues(alpha: 0.45),
                        iconBgColor: AppColors.primary.withValues(alpha: 0.08),
                        circleSize: 76,
                        iconSize: 36,
                        title: 'Chưa có đơn nào',
                        titleFontSize: 16,
                        subtitle: 'Các đơn đã hoàn thành sẽ hiện ở đây',
                        actionLabel: 'Tải lại',
                        actionColor: AppColors.primary,
                        onAction: () {
                          ref
                              .read(orderHistoryProvider.notifier)
                              .fetch(refresh: true);
                        },
                      ),
                    ),

                  if (completedOrders.isNotEmpty) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            if (i < items.length) {
                              final item = items[i];
                              if (item is String) {
                                return HistoryDateLabel(label: item);
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: HistoryCompletedCard(
                                    order: item as OrderModel),
                              );
                            }
                            return historyState.loading
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(
                                        vertical: AppSpacing.xl),
                                    child: Center(
                                        child: CircularProgressIndicator(
                                            color: AppColors.primary,
                                            strokeWidth: 2)),
                                  )
                                : const SizedBox.shrink();
                          },
                          childCount:
                              items.length + (historyState.hasMore ? 1 : 0),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.xl3)),
                  ],

                  // Khoảng thở cuối danh sách trước thanh điều hướng.
                  SliverToBoxAdapter(
                    child: SizedBox(height: BottomNav.reservedHeight(context)),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
