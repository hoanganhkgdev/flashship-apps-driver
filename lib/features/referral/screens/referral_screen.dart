import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../models/referral_model.dart';
import '../providers/referral_provider.dart';

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(referralProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppScreenHeader(title: 'Giới thiệu cửa hàng'),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2)),
        error: (_, __) => Center(
          child: TextButton.icon(
            onPressed: () => ref.invalidate(referralProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Không tải được. Nhấn để thử lại'),
          ),
        ),
        data: (info) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.refresh(referralProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _CodeCard(info: info),
              const SizedBox(height: AppSpacing.md),
              _StatsRow(info: info),
              const SizedBox(height: AppSpacing.lg),
              const Text('Cửa hàng đã giới thiệu',
                  style: TextStyle(
                      fontSize: AppFontSize.md,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.sm),
              if (info.shops.isEmpty)
                const AppSurfaceCard(
                  child: Text(
                    'Chưa có cửa hàng nào. Chia sẻ mã của bạn cho chủ shop để bắt đầu nhận thưởng.',
                    style: TextStyle(
                        fontSize: AppFontSize.base,
                        color: AppColors.textSecondary),
                  ),
                )
              else
                for (final shop in info.shops) _ShopTile(shop: shop, info: info),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  final ReferralInfo info;
  const _CodeCard({required this.info});

  String get _reward => info.rewardAmount > 0
      ? 'Nhận ${Fmt.currency(info.rewardAmount)} cho mỗi cửa hàng'
      : 'Giới thiệu cửa hàng mới';

  @override
  Widget build(BuildContext context) {
    final orders = info.requiredOrders;
    return AppSurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const Text('MÃ GIỚI THIỆU CỦA BẠN',
              style: TextStyle(
                  fontSize: AppFontSize.xs,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          Text(info.code.isEmpty ? '—' : info.code,
              style: const TextStyle(
                  fontSize: AppFontSize.xl5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                  color: AppColors.primary)),
          const SizedBox(height: AppSpacing.md),
          Text(
            '$_reward khi shop nhập mã lúc đăng ký và hoàn thành '
            '${orders > 1 ? '$orders đơn' : 'đơn đầu tiên'}.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: AppFontSize.base,
                height: 1.4,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: AppSize.buttonHeight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              onPressed: info.code.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(
                          text:
                              'Đăng ký FlashShip Shop và nhập mã giới thiệu ${info.code} của mình nhé!'));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Đã sao chép, dán gửi cho chủ shop')),
                      );
                    },
              icon: const Icon(Icons.copy_rounded, size: AppSize.iconMd),
              label: const Text('Sao chép lời mời',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final ReferralInfo info;
  const _StatsRow({required this.info});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: _Stat(label: 'Đã giới thiệu', value: '${info.totalReferred}')),
        const SizedBox(width: AppSpacing.md),
        Expanded(
            child: _Stat(
                label: 'Tiền thưởng đã nhận',
                value: Fmt.currency(info.totalRewarded))),
      ]);
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: AppFontSize.sm, color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Text(value,
              style: const TextStyle(
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
        ]),
      );
}

class _ShopTile extends StatelessWidget {
  final ReferredShop shop;
  final ReferralInfo info;
  const _ShopTile({required this.shop, required this.info});

  @override
  Widget build(BuildContext context) {
    final rewarded = shop.status == 'rewarded';
    final rejected = shop.status == 'rejected';
    final (label, fg, bg) = rewarded
        ? ('Đã thưởng${shop.rewardAmount != null ? ' ${Fmt.currency(shop.rewardAmount!)}' : ''}',
            AppColors.success, AppColors.successSoft)
        : rejected
            ? ('Không đủ điều kiện', AppColors.danger, AppColors.dangerSoft)
            : ('Chờ shop hoàn thành đơn', AppColors.warning,
                AppColors.warningSoft);
    final date = shop.rewardedAt ?? shop.registeredAt;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppSurfaceCard(
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: AppFontSize.base,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  if (date != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(Fmt.timeAgo(date),
                          style: const TextStyle(
                              fontSize: AppFontSize.sm,
                              color: AppColors.textTertiary)),
                    ),
                ]),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(AppRadius.full)),
            child: Text(label,
                style: TextStyle(
                    fontSize: AppFontSize.sm,
                    fontWeight: FontWeight.w700,
                    color: fg)),
          ),
        ]),
      ),
    );
  }
}
