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
      appBar: const AppScreenHeader(
        title: 'Giới thiệu cửa hàng',
        backgroundColor: AppColors.primarySoft,
      ),
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
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl3),
            children: [
              _CodeCard(info: info),
              const SizedBox(height: AppSpacing.md),
              _StatsRow(info: info),
              const SizedBox(height: AppSpacing.lg),
              _HowItWorks(info: info),
              const SizedBox(height: AppSpacing.xl),
              _SectionHeading(
                title: 'Cửa hàng đã giới thiệu',
                subtitle: 'Theo dõi tiến độ và phần thưởng',
                count: info.shops.isEmpty ? null : info.shops.length,
              ),
              const SizedBox(height: AppSpacing.md),
              if (info.shops.isEmpty)
                AppSurfaceCard(
                  color: AppColors.surface,
                  showBorder: true,
                  showShadow: false,
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xl2, horizontal: AppSpacing.lg),
                  child: Column(children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: const Icon(Icons.storefront_rounded,
                          size: 28, color: AppColors.primary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text('Chưa có cửa hàng nào',
                        style: TextStyle(
                            fontSize: AppFontSize.md,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text(
                      'Chia sẻ mã của bạn cho chủ shop để bắt đầu nhận thưởng.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: AppFontSize.base,
                          height: 1.4,
                          color: AppColors.textSecondary),
                    ),
                  ]),
                )
              else
                for (final shop in info.shops) _ShopTile(shop: shop),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final int? count;

  const _SectionHeading({
    required this.title,
    required this.subtitle,
    this.count,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 4,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.sectionTitle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              '$count',
              style: AppTextStyles.label.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ]);
}

class _CodeCard extends StatelessWidget {
  final ReferralInfo info;
  const _CodeCard({required this.info});

  String get _reward => info.rewardAmount > 0
      ? 'Nhận ${Fmt.currency(info.rewardAmount)} cho mỗi cửa hàng'
      : 'Giới thiệu cửa hàng mới';

  Future<void> _copy(BuildContext context, String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final hasCode = info.code.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.primary.withValues(alpha: .22)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.card_giftcard_rounded,
                size: 22, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mã giới thiệu của bạn',
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _reward,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        // Ô mã: bấm để sao chép nhanh.
        Material(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: hasCode
                ? () => _copy(context, info.code, 'Đã sao chép mã giới thiệu')
                : null,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.lg, horizontal: AppSpacing.xl),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(hasCode ? info.code : '—',
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 6,
                            color: AppColors.primary)),
                  ),
                ),
                if (hasCode) ...[
                  const SizedBox(width: AppSpacing.md),
                  const Icon(Icons.copy_rounded,
                      size: 20, color: AppColors.textTertiary),
                ],
              ]),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: hasCode
                ? () => _copy(
                    context,
                    'Đăng ký FlashShip Shop và nhập mã giới thiệu ${info.code} của mình nhé!',
                    'Đã sao chép, dán gửi cho chủ shop')
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text('Sao chép lời mời',
                style: AppTextStyles.sectionTitle.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final ReferralInfo info;
  const _StatsRow({required this.info});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: _Stat(
            icon: Icons.groups_rounded,
            color: AppColors.secondary,
            label: 'Đã giới thiệu',
            value: '${info.totalReferred}',
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _Stat(
            icon: Icons.payments_rounded,
            color: AppColors.success,
            label: 'Thưởng đã nhận',
            value: Fmt.currency(info.totalRewarded),
          ),
        ),
      ]);
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _Stat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
        color: AppColors.surface,
        showBorder: true,
        showShadow: false,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: AppTextStyles.metric
                        .copyWith(color: AppColors.textPrimary)),
              ),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
            ]),
          ),
        ]),
      );
}

/// Ba bước để tài xế biết cách nhận thưởng.
class _HowItWorks extends StatelessWidget {
  final ReferralInfo info;
  const _HowItWorks({required this.info});

  @override
  Widget build(BuildContext context) {
    final orders = info.requiredOrders;
    final steps = [
      ('Chia sẻ mã', 'Gửi mã giới thiệu cho chủ shop'),
      ('Shop đăng ký', 'Shop nhập mã của bạn khi tạo tài khoản'),
      (
        'Nhận thưởng',
        orders > 1
            ? 'Khi shop hoàn thành $orders đơn'
            : 'Khi shop hoàn thành đơn đầu tiên'
      ),
    ];
    return AppSurfaceCard(
      color: AppColors.surface,
      showBorder: true,
      showShadow: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeading(
          title: 'Cách nhận thưởng',
          subtitle: 'Hoàn thành 3 bước đơn giản',
        ),
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: EdgeInsets.only(
                bottom: i == steps.length - 1 ? 0 : AppSpacing.md),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Text('${i + 1}',
                    style: AppTextStyles.bodyStrong
                        .copyWith(color: AppColors.primary)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(steps[i].$1,
                          style: AppTextStyles.bodyStrong.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(height: 1),
                      Text(steps[i].$2,
                          style: AppTextStyles.label
                              .copyWith(color: AppColors.textSecondary)),
                    ]),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _ShopTile extends StatelessWidget {
  final ReferredShop shop;
  const _ShopTile({required this.shop});

  @override
  Widget build(BuildContext context) {
    final rewarded = shop.status == 'rewarded';
    final rejected = shop.status == 'rejected';
    final (label, fg, bg) = rewarded
        ? (
            'Đã thưởng${shop.rewardAmount != null ? ' ${Fmt.currency(shop.rewardAmount!)}' : ''}',
            AppColors.success,
            AppColors.successSoft
          )
        : rejected
            ? ('Không đủ điều kiện', AppColors.danger, AppColors.dangerSoft)
            : (
                'Chờ shop hoàn thành đơn',
                AppColors.warning,
                AppColors.warningSoft
              );
    final date = shop.rewardedAt ?? shop.registeredAt;
    final initial = shop.shopName.trim().isEmpty
        ? 'S'
        : shop.shopName.trim()[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppSurfaceCard(
        color: AppColors.surface,
        showBorder: true,
        showShadow: false,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            ),
            child: Text(initial,
                style: AppTextStyles.sectionTitle
                    .copyWith(color: AppColors.primary)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(shop.shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: AppFontSize.base,
                      fontWeight: FontWeight.w600,
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
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(AppRadius.full)),
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: AppFontSize.xs,
                      fontWeight: FontWeight.w600,
                      color: fg)),
            ),
          ),
        ]),
      ),
    );
  }
}
