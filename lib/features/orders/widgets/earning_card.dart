import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/order_model.dart';
import 'order_card_shell.dart';

class EarningCard extends StatelessWidget {
  final OrderModel order;
  final Color color;
  const EarningCard({super.key, required this.order, required this.color});

  @override
  Widget build(BuildContext context) {
    return orderCardShell(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────────
        const Text('Thu nhập đơn này',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            )),

        const SizedBox(height: 14),

        // ── Earning hero (1 card nền xám nhạt duy nhất) ───────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tài xế nhận',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        )),
                    const SizedBox(height: 3),
                    Text(Fmt.currency(order.driverEarning),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.success,
                          letterSpacing: -0.5,
                        )),
                    if (order.hasDiscount && order.discountAmount > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        order.driverEarning == 0
                            ? 'Tiền ship cộng vào ví sau hoàn thành'
                            : '+ ${Fmt.currency(order.discountAmount)} cộng thêm vào ví',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.success,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ]),
            ),
            if (order.isCod) ...[
              const SizedBox(width: 10),
              // Chỉ mang tính thông báo "đơn này cần thu tiền COD" — không có
              // hành động bấm riêng (giữ nguyên như bản gốc), chỉ đổi kiểu
              // hiển thị sang outline nhỏ cho đỡ nổi hơn nút hành động chính.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.monetization_on_rounded,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 5),
                  const Text('Thu tiền',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      )),
                ]),
              ),
            ],
          ]),
        ),

        // ── Fee breakdown ─────────────────────────────────────────────
        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFF5F5F5)),
        const SizedBox(height: 12),

        FeeRow(
          label: 'Phí giao hàng',
          value: Fmt.currency(order.shippingFee + order.discountAmount),
        ),
        // Phụ phí đêm khuya đã được cộng sẵn vào "Phí giao hàng" ở trên (backend
        // tính fee = base + surcharge) — hiện tách dòng để tài xế biết vì sao
        // phí cao hơn bình thường, không phải cộng thêm vào tổng.
        if (order.nightSurcharge > 0) ...[
          const SizedBox(height: 8),
          FeeRow(
            label: '· Gồm phụ phí đêm khuya',
            value: Fmt.currency(order.nightSurcharge),
            valueColor: AppColors.textSecondary,
          ),
        ],
        if (order.hasDiscount) ...[
          const SizedBox(height: 8),
          FeeRow(
            label: order.voucherCode != null
                ? 'Giảm giá (${order.voucherCode})'
                : 'Giảm giá',
            value: '- ${Fmt.currency(order.discountAmount)}',
            valueColor: AppColors.danger,
          ),
        ],
        if (order.bonusFee > 0) ...[
          const SizedBox(height: 8),
          FeeRow(
            label: 'Thưởng thêm',
            value: '+ ${Fmt.currency(order.bonusFee)}',
            valueColor: AppColors.success,
          ),
        ],

        // ── Shopping advance ──────────────────────────────────────────
        if (order.serviceType == 'shopping' && (order.codAmount ?? 0) > 0) ...[
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF5F5F5)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shopping_cart_checkout_rounded,
                    size: 18, color: AppColors.warning),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tiền ứng mua hàng',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(Fmt.currency(order.codAmount!),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.warning)),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }
}

class FeeRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const FeeRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: valueColor)),
      ]);
}
