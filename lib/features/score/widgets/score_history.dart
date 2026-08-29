import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/score_model.dart';
import 'score_cards.dart';

class HistoryCard extends StatelessWidget {
  final List<ScoreLogEntry> history;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final VoidCallback onLoadMore;

  const HistoryCard({
    super.key,
    required this.history,
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return ScoreSectionCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text('Lịch sử điểm',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
        ),
        const Divider(height: 1, color: Color(0xFFF5F5F5)),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary)),
          )
        else if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.history_rounded,
                      size: 24, color: AppColors.textTertiary),
                ),
                const SizedBox(height: 10),
                const Text('Chưa có lịch sử điểm',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ]),
            ),
          )
        else ...[
          ..._buildGrouped(),
          if (hasMore || loadingMore) ...[
            const Divider(height: 1, color: Color(0xFFF5F5F5)),
            loadingMore
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                        child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    )),
                  )
                : InkWell(
                    onTap: onLoadMore,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                          child: Text('Xem thêm',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary))),
                    ),
                  ),
          ],
        ],
      ]),
    );
  }

  List<Widget> _buildGrouped() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final widgets = <Widget>[];
    String? lastGroup;

    for (var i = 0; i < history.length; i++) {
      final entry = history[i];
      final d = DateTime(
          entry.createdAt.year, entry.createdAt.month, entry.createdAt.day);
      final String group;
      if (d == today) {
        group = 'Hôm nay';
      } else if (d == yesterday) {
        group = 'Hôm qua';
      } else {
        group = '${d.day}/${d.month}/${d.year}';
      }

      if (group != lastGroup) {
        lastGroup = group;
        widgets.add(DateHeader(label: group));
      }

      widgets.add(HistoryItem(entry: entry));
      if (i < history.length - 1) {
        final nextD = DateTime(history[i + 1].createdAt.year,
            history[i + 1].createdAt.month, history[i + 1].createdAt.day);
        final nextGroup = nextD == today
            ? 'Hôm nay'
            : nextD == yesterday
                ? 'Hôm qua'
                : '${nextD.day}/${nextD.month}/${nextD.year}';
        if (nextGroup == group) {
          widgets.add(
              const Divider(height: 1, color: Color(0xFFF5F5F5), indent: 70));
        }
      }
    }
    return widgets;
  }
}

class DateHeader extends StatelessWidget {
  final String label;
  const DateHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFFCF8F6),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
      );
}

class HistoryItem extends StatelessWidget {
  final ScoreLogEntry entry;
  const HistoryItem({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final isPos = entry.isPositive;
    final color = isPos ? AppColors.success : AppColors.danger;
    final sign = isPos ? '+' : '';
    final diff = DateTime.now().difference(entry.createdAt);
    final time = diff.inMinutes < 60
        ? '${diff.inMinutes} phút trước'
        : diff.inHours < 24
            ? '${diff.inHours} giờ trước'
            : '${entry.createdAt.hour.toString().padLeft(2, '0')}:${entry.createdAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            isPos ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            color: color,
            size: 17,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 3),
            Row(children: [
              Text('${entry.scoreBefore} → ${entry.scoreAfter}',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary)),
              Container(
                width: 3,
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: const BoxDecoration(
                    color: AppColors.textTertiary, shape: BoxShape.circle),
              ),
              Text(time,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary)),
            ]),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$sign${entry.delta}',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ),
      ]),
    );
  }
}
