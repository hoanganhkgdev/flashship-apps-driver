import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import 'formatted_note.dart';

/// Các khối dùng chung cho thẻ đơn mới (tab Đơn mới) và thẻ đơn đang chạy —
/// để hai thẻ cùng một ngôn ngữ: đầu thẻ, dải tiền "Thu khách | Bạn nhận",
/// dòng việc cần làm, ghi chú.

/// "15.000" → "15k", "15.500" → "15,5k", "1.250.000" → "1,25tr" — cho dòng
/// diễn giải ngắn gọn, không tràn.
String moneyShort(int v) {
  String trim(double x, int digits) {
    var s = x.toStringAsFixed(digits);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s.replaceAll('.', ',');
  }

  if (v >= 1000000) return '${trim(v / 1000000, 2)}tr';
  if (v >= 1000) return '${trim(v / 1000, 1)}k';
  return '$vđ';
}

/// Từ chỉ phí theo dịch vụ, dùng trong dòng diễn giải ("ship 15k", "cước 35k").
String feeWord(String serviceType) => switch (serviceType) {
      'bike' || 'motor' || 'car' => 'cước',
      'topup' => 'phí',
      _ => 'ship',
    };

/// Một mảnh chữ ở dòng thứ hai của đầu thẻ (trạng thái, nguồn đơn, thời gian).
typedef OrderMeta = ({String text, Color color, bool strong});

class OrderCardHeader extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String code;
  final String? pill;
  final List<OrderMeta> meta;
  final bool emphasized;
  final bool brandStyle;

  const OrderCardHeader({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.code,
    this.pill,
    required this.meta,
    this.emphasized = false,
    this.brandStyle = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
        decoration: BoxDecoration(
          color: brandStyle
              ? Colors.white
              : emphasized
                  ? null
                  : accent.withValues(alpha: .07),
          gradient: !brandStyle && emphasized
              ? LinearGradient(
                  colors: [
                    accent.withValues(alpha: .15),
                    accent.withValues(alpha: .045),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          border: emphasized
              ? Border(
                  bottom: BorderSide(
                    color: AppColors.divider,
                  ),
                )
              : null,
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: emphasized ? null : accent,
              gradient: brandStyle
                  ? AppBrand.gradient
                  : emphasized
                      ? LinearGradient(
                          colors: [
                            accent,
                            Color.lerp(accent, Colors.black, .16)!
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: emphasized
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: .25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(icon,
                size: 22, color: brandStyle ? AppBrand.ink : Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chữ to: các phần tự xuống dòng thay vì bị cắt mất.
                Wrap(
                  spacing: 7,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: brandStyle ? 16 : null,
                      ),
                    ),
                    Text(
                      '#$code',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: brandStyle ? 12 : null,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (pill != null)
                      OrderPill(
                        text: pill!,
                        color: brandStyle
                            ? AppBrand.ink
                            : emphasized
                                ? accent
                                : null,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (var i = 0; i < meta.length; i++) ...[
                      if (i > 0)
                        const Icon(Icons.circle,
                            size: 4, color: AppColors.textTertiary),
                      Text(
                        meta[i].text,
                        style: AppTextStyles.caption.copyWith(
                          color: brandStyle
                              ? AppColors.textSecondary
                              : meta[i].color,
                          fontSize: brandStyle ? 12 : null,
                          fontWeight: meta[i].strong
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ]),
      );
}

class OrderPill extends StatelessWidget {
  final String text;
  final Color? color;
  const OrderPill({super.key, required this.text, this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color?.withValues(alpha: .1) ?? AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: color == null
              ? null
              : Border.all(color: color!.withValues(alpha: .18)),
        ),
        child: Text(
          text,
          style: AppTextStyles.caption.copyWith(
            color: color ?? AppColors.textSecondary,
            fontSize: color == null ? 11 : 10,
            letterSpacing: color == null ? 0 : .35,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

/// Dải tiền 2 cột: THU KHÁCH | BẠN NHẬN, mỗi cột có dòng diễn giải ngắn.
/// [highlightEarn]: tô nổi ô "Bạn nhận" (thẻ đơn mới — tài xế quyết định nhận
/// đơn theo số này).
class OrderMoneyStrip extends StatelessWidget {
  final String collectLabel;
  final int collect;
  final String collectNote;
  final int earn;
  final String earnNote;
  final bool highlightEarn;

  const OrderMoneyStrip({
    super.key,
    required this.collectLabel,
    required this.collect,
    required this.collectNote,
    required this.earn,
    required this.earnNote,
    this.highlightEarn = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: highlightEarn
              ? AppColors.surface
              : AppColors.surfaceAlt.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.divider),
        ),
        padding: EdgeInsets.all(highlightEarn ? 5 : AppSpacing.xs),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: highlightEarn
                    ? BoxDecoration(
                        color: Colors.white.withValues(alpha: .7),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      )
                    : null,
                child: OrderMoneyCell(
                  label: collectLabel,
                  amount: collect,
                  note: collectNote,
                  color:
                      collect == 0 ? AppColors.success : AppColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: highlightEarn
                    ? BoxDecoration(
                        color: AppColors.successSoft,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                            color: AppColors.success.withValues(alpha: .65)),
                      )
                    : const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: AppColors.divider),
                        ),
                      ),
                child: OrderMoneyCell(
                  label: 'BẠN NHẬN',
                  amount: earn,
                  note: earnNote,
                  color: AppColors.success,
                ),
              ),
            ),
          ]),
        ),
      );
}

class OrderMoneyCell extends StatelessWidget {
  final String label;
  final int amount;
  final String note;
  final Color color;

  const OrderMoneyCell({
    super.key,
    required this.label,
    required this.amount,
    required this.note,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
              letterSpacing: .4,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Fmt.currency(amount),
              style: AppTextStyles.metric.copyWith(
                color: color,
                fontSize: 26,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            note,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      );
}

/// Một dòng nổi bật cho việc tài xế phải làm (số tiền cần nạp, ứng trả shop…).
class OrderInfoLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const OrderInfoLine({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.label.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ]),
      );
}

class OrderNoteBlock extends StatelessWidget {
  final String note;
  const OrderNoteBlock({super.key, required this.note});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.warningSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: .65),
            width: 1.25,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.sticky_note_2_rounded,
                size: 18, color: AppColors.warning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GHI CHÚ',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.warning,
                      fontSize: 11,
                      letterSpacing: .5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  FormattedNote(
                    note: note,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
