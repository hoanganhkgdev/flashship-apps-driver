import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launch_utils.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import 'order_card_shell.dart';

class BatchStopsCard extends ConsumerStatefulWidget {
  final OrderModel order;
  final Future<void> Function()? onCompleted;
  final ValueChanged<bool>? onCompletionStateChanged;
  const BatchStopsCard({
    super.key,
    required this.order,
    this.onCompleted,
    this.onCompletionStateChanged,
  });

  @override
  ConsumerState<BatchStopsCard> createState() => _BatchStopsCardState();
}

class _BatchStopsCardState extends ConsumerState<BatchStopsCard> {
  final Set<int> _delivering = {};

  Future<void> _deliverStop(int seq) async {
    if (_delivering.contains(seq)) return;
    final pendingStops = widget.order.stops
        .where((stop) => stop['delivered_at'] == null)
        .toList();
    final isFinalStop = pendingStops.length == 1 &&
        (pendingStops.single['seq'] as int? ?? seq) == seq;
    if (isFinalStop) widget.onCompletionStateChanged?.call(true);
    setState(() => _delivering.add(seq));
    try {
      final res = await ref
          .read(apiClientProvider)
          .post('/orders/${widget.order.code}/stops/$seq/deliver');
      final completed = res.data['completed'] as bool? ?? false;
      if (!mounted) return;
      setState(() => _delivering.remove(seq));
      if (completed) {
        // Báo cho màn hình cha đánh dấu trạng thái hoàn thành trước khi refresh.
        // Nếu refresh trước, đơn biến mất khỏi danh sách active sẽ bị hiểu nhầm
        // là khách đã huỷ đơn.
        await widget.onCompleted?.call();
        return;
      }
      if (isFinalStop) widget.onCompletionStateChanged?.call(false);
      await ref.read(activeOrderProvider.notifier).fetch();
    } catch (e) {
      if (isFinalStop) widget.onCompletionStateChanged?.call(false);
      if (mounted) {
        setState(() => _delivering.remove(seq));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể cập nhật điểm giao. Vui lòng thử lại.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stops = widget.order.stops;
    final delivered = stops.where((s) => s['delivered_at'] != null).length;
    final canDeliver = widget.order.status == 'processing';

    return orderCardShell(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Icon(Icons.route_rounded, size: 13, color: AppColors.textTertiary),
          const SizedBox(width: 6),
          Text(
            'CÁC ĐIỂM GIAO ($delivered/${stops.length})',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ]),

        const SizedBox(height: 12),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: stops.isEmpty ? 0 : delivered / stops.length,
            minHeight: 5,
            backgroundColor: AppColors.divider,
            valueColor: const AlwaysStoppedAnimation(AppColors.success),
          ),
        ),

        const SizedBox(height: 14),

        // Stops list
        ...stops.asMap().entries.map((e) {
          final i = e.key;
          final stop = e.value;
          final seq = stop['seq'] as int? ?? (i + 1);
          final isDone = stop['delivered_at'] != null;
          final addr = stop['address'] as String? ?? '';
          final phone = stop['phone'] as String? ?? '';
          final name = stop['name'] as String? ?? '';
          final cod = (stop['cod_amount'] as num?)?.toInt() ?? 0;
          final loading = _delivering.contains(seq);

          return Column(children: [
            if (i > 0) const Divider(height: 20, color: AppColors.divider),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Seq badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDone ? AppColors.success : AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                          size: 15, color: Colors.white)
                      : Text('$seq',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                ),
              ),

              const SizedBox(width: 10),

              // Info
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    if (name.isNotEmpty)
                      Text(name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDone
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            decoration:
                                isDone ? TextDecoration.lineThrough : null,
                            decorationColor: AppColors.textSecondary,
                          )),
                    Text(addr,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDone
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (phone.isNotEmpty)
                      GestureDetector(
                        onTap: () => launchPhoneCall(phone),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.phone_rounded,
                                size: 12, color: AppColors.info),
                            const SizedBox(width: 4),
                            Text(phone,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.info,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    if (cod > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text('Thu COD: ${Fmt.currency(cod)}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600)),
                      ),
                  ])),

              // Action
              if (!isDone)
                SizedBox(
                  width: 76,
                  height: 34,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    onPressed: (!canDeliver || loading)
                        ? null
                        : () => _deliverStop(seq),
                    child: loading
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Đã giao'),
                  ),
                )
              else
                const Icon(Icons.check_circle_rounded,
                    size: 22, color: AppColors.success),
            ]),
          ]);
        }),
      ]),
    );
  }
}
