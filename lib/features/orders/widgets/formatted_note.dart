import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launch_utils.dart';
import 'phone_link_text.dart';

/// Ghi chú đơn hàng dạng một khối chữ liền ("Điểm Lấy: ... Điểm Giao: ...")
/// được tách thành từng dòng theo nhãn; số điện thoại và link Google Maps hiện
/// thành nút bấm. Ghi chú không có nhãn nào thì giữ nguyên bằng [PhoneLinkText].
class FormattedNote extends StatelessWidget {
  final String note;
  final TextStyle style;

  const FormattedNote({super.key, required this.note, required this.style});

  static final _labelRegex = RegExp(
    r'(Mua\s+hộ\s*-\s*gọi\s+khách|Lái\s+(?:hộ\s+)?xe\s+(?:máy|ô\s*tô|oto)|Nạp\s+tiền|Điểm\s+(?:lấy|giao|rước|đến|nạp)(?:\s+đơn)?|Lấy\s+hàng|Giao\s+hàng|Người\s+(?:gửi|nhận)|SĐT|Ghi\s+chú|(?:Phí\s+)?ship|Tiền\s+xe|Cước|Phí|Về)\s*:',
    caseSensitive: false,
    unicode: true,
  );

  // Số điện thoại hoặc link; dấu ngoặc bao quanh số được bỏ đi cho gọn.
  static final _tokenRegex = RegExp(
    r'\(?\s*(0\d{8,10})\s*\)?|(https?://[^\s]+|(?:www\.)?(?:maps\.app\.goo\.gl|goo\.gl/maps|maps\.google\.[a-z.]+|google\.[a-z.]+/maps)[^\s]*)',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final displayNote = note
        .replaceFirst(
          RegExp(
            r'^\s*\[Chưa có điểm giao[^\]]*\]\s*',
            caseSensitive: false,
            unicode: true,
          ),
          '',
        )
        .trim();
    final labels = _labelRegex.allMatches(displayNote).toList();
    if (labels.isEmpty) return PhoneLinkText(text: displayNote, style: style);

    // Biểu tượng/ký tự trang trí đứng trước nhãn đầu tiên (vd. 🥖) không mang nội dung.
    final intro = displayNote
        .substring(0, labels.first.start)
        .replaceAll(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '')
        .trim();

    final rows = <Widget>[
      if (intro.isNotEmpty) _value(intro),
      for (var i = 0; i < labels.length; i++)
        _Section(
          label: labels[i].group(1)!,
          value: _sectionValue(
            labels[i].group(1)!,
            displayNote
                .substring(
                    labels[i].end,
                    i + 1 < labels.length
                        ? labels[i + 1].start
                        : displayNote.length)
                .trim(),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          rows[i],
        ],
      ],
    );
  }

  Widget _sectionValue(String label, String text) {
    final lowerLabel = label.toLowerCase();
    final isTopUpAmount = lowerLabel == 'nạp tiền';
    final isFee = lowerLabel.contains('ship') ||
        lowerLabel.contains('tiền xe') ||
        lowerLabel == 'cước' ||
        lowerLabel == 'phí';
    if (isTopUpAmount || isFee) {
      final moneyMatch = RegExp(
        r'(\d+(?:[.,]\d+)*)\s*(triệu|tr|k|nghìn|đ|₫)?',
        caseSensitive: false,
        unicode: true,
      ).firstMatch(text);
      final amount = _parseMoney(moneyMatch);
      if (amount != null) {
        final remaining = moneyMatch == null
            ? ''
            : '${text.substring(0, moneyMatch.start)} '
                    '${text.substring(moneyMatch.end)}'
                .trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Fmt.currency(amount),
              style: style.copyWith(fontWeight: FontWeight.w800),
            ),
            if (remaining.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              _value(remaining),
            ],
          ],
        );
      }
    }
    return _value(text);
  }

  int? _parseMoney(RegExpMatch? match) {
    if (match == null) return null;
    final number = match.group(1)!;
    final unit = match.group(2)?.toLowerCase();
    if (unit == 'triệu' || unit == 'tr') {
      final value = double.tryParse(number.replaceAll(',', '.'));
      return value == null ? null : (value * 1000000).round();
    }
    if (unit == 'k' || unit == 'nghìn') {
      final value = double.tryParse(number.replaceAll(',', '.'));
      return value == null ? null : (value * 1000).round();
    }

    final value = int.tryParse(number.replaceAll(RegExp(r'[^0-9]'), ''));
    if (value == null) return null;
    // Tổng đài nhập phí rút gọn theo nghìn đồng: "15" = 15.000đ.
    return value < 1000 ? value * 1000 : value;
  }

  Widget _value(String text) {
    // Mẫu tổng đài thường thêm biểu tượng điện thoại trước số. Chip gọi điện
    // đã có icon riêng nên bỏ ký tự trang trí để không tạo một dòng thừa.
    final cleanText = text.replaceAll(RegExp(r'[☎📞]\uFE0F?\s*'), '');
    final spans = <InlineSpan>[];
    var last = 0;
    var afterPhone = false;

    // Số điện thoại luôn nằm riêng một dòng, tách khỏi phần chữ trước/sau nó.
    void addText(String part) {
      final trimmed = afterPhone ? part.trimLeft() : part;
      if (trimmed.trim().isEmpty) return;
      spans.add(TextSpan(text: afterPhone ? '\n$trimmed' : trimmed));
      afterPhone = false;
    }

    for (final m in _tokenRegex.allMatches(cleanText)) {
      addText(cleanText.substring(last, m.start));
      final phone = m.group(1);
      if (phone != null) {
        if (spans.isNotEmpty) spans.add(const TextSpan(text: '\n'));
        afterPhone = true;
      }
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: phone != null
            ? _ActionChip(
                icon: Icons.call_rounded,
                label: phone,
                color: AppColors.success,
                onTap: () => launchPhoneCall(phone),
              )
            : _ActionChip(
                icon: Icons.map_rounded,
                label: 'Mở bản đồ',
                color: AppColors.info,
                onTap: () => launchLink(m.group(2)!),
              ),
      ));
      last = m.end;
    }
    addText(cleanText.substring(last));
    return Text.rich(TextSpan(style: style, children: spans));
  }
}

class _Section extends StatelessWidget {
  final String label;
  final Widget value;

  const _Section({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final lower = label.toLowerCase();
    final isPickup = lower.contains('lấy') ||
        lower.contains('gửi') ||
        lower.contains('rước');
    final isDropoff = lower.contains('giao') ||
        lower.contains('nhận') ||
        lower.contains('đến') ||
        lower == 'về';
    final isShippingFee = lower.contains('ship') ||
        lower.contains('tiền xe') ||
        lower == 'cước' ||
        lower == 'phí';
    final isShoppingInstruction = lower.contains('mua hộ');
    final isTopUpAmount = lower == 'nạp tiền';
    final isTopUpPoint = lower.contains('điểm nạp');
    final isMotorPickup = lower.contains('lái') && lower.contains('xe máy');
    final isCarPickup = lower.contains('lái') &&
        (lower.contains('ô tô') || lower.contains('oto'));
    final color = isTopUpAmount || isTopUpPoint
        ? Fmt.serviceColor('topup')
        : isCarPickup
            ? Fmt.serviceColor('car')
            : isMotorPickup
                ? Fmt.serviceColor('motor')
                : isShoppingInstruction
                    ? Fmt.serviceColor('shopping')
                    : isShippingFee
                        ? AppColors.primary
                        : isPickup
                            ? AppColors.warningStrong
                            : isDropoff
                                ? AppColors.success
                                : AppColors.textSecondary;
    final icon = isTopUpAmount
        ? Icons.account_balance_wallet_rounded
        : isTopUpPoint
            ? Icons.add_location_alt_rounded
            : isCarPickup
                ? Icons.directions_car_rounded
                : isMotorPickup
                    ? Icons.two_wheeler_rounded
                    : isShoppingInstruction
                        ? Icons.shopping_bag_rounded
                        : isShippingFee
                            ? Icons.payments_rounded
                            : isPickup
                                ? Icons.storefront_rounded
                                : isDropoff
                                    ? Icons.location_on_rounded
                                    : Icons.notes_rounded;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontSize: 10,
                  letterSpacing: .5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              value,
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}
