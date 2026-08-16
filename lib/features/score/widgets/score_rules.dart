import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import 'score_cards.dart';

class RulesCard extends ConsumerStatefulWidget {
  const RulesCard({super.key});

  @override
  ConsumerState<RulesCard> createState() => _RulesCardState();
}


class _RulesCardState extends ConsumerState<RulesCard> {
  bool _showPlus  = true;
  bool _showMinus = false;
  bool _showReset = false;

  @override
  Widget build(BuildContext context) {
    return ScoreSectionCard(
      padding: EdgeInsets.zero,
      child: Column(children: [

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            const Text('Cách tính điểm',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('+10 điểm/ngày tối đa',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
          ]),
        ),

        // Tab chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            Expanded(child: TabChip(
              label: '+ Cộng điểm',
              active: _showPlus,
              activeColor: AppColors.success,
              onTap: () => setState(() {
                _showPlus  = !_showPlus;
                _showMinus = false;
                _showReset = false;
              }),
            )),
            const SizedBox(width: 8),
            Expanded(child: TabChip(
              label: '− Trừ điểm',
              active: _showMinus,
              activeColor: AppColors.danger,
              onTap: () => setState(() {
                _showMinus = !_showMinus;
                _showPlus  = false;
                _showReset = false;
              }),
            )),
            const SizedBox(width: 8),
            Expanded(child: TabChip(
              label: 'Reset',
              active: _showReset,
              activeColor: AppColors.textSecondary,
              onTap: () => setState(() {
                _showReset = !_showReset;
                _showPlus  = false;
                _showMinus = false;
              }),
            )),
          ]),
        ),

        const Divider(height: 1, color: Color(0xFFF5F5F5)),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _showPlus
              ? RulesList(
                  key: const ValueKey('plus'),
                  color: AppColors.success,
                  items: const [
                    ('+1', '3 đơn liên tiếp (streak)'),
                    ('+2', '6 đơn liên tiếp (streak)'),
                    ('+3', 'Online ≥ 90% thời lượng ca'),
                    ('+4', '10 đơn liên tiếp (streak)'),
                  ],
                )
              : _showMinus
                  ? RulesList(
                      key: const ValueKey('minus'),
                      color: AppColors.danger,
                      items: const [
                        ('-1',  'Bỏ lỡ 3 đơn không xem (mỗi 3 lần)'),
                        ('-2',  'Từ chối đơn hàng'),
                        ('-2',  'Để đơn trôi qua (timeout)'),
                        ('-5',  'Online 50–69% thời lượng ca'),
                        ('-10', 'Online dưới 50% thời lượng ca'),
                        ('-15', 'Không online suốt cả ca'),
                      ],
                    )
                  : _showReset
                      ? RulesList(
                          key: const ValueKey('reset'),
                          color: AppColors.textSecondary,
                          items: const [
                            ('↺', 'Reset về 100 điểm mỗi đầu tuần mới'),
                          ],
                        )
                      : const SizedBox.shrink(key: ValueKey('none')),
        ),

        const SizedBox(height: 8),

      ]),
    );
  }
}


class TabChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const TabChip({
    super.key,
    required this.label, required this.active,
    required this.activeColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? activeColor.withValues(alpha: 0.1)
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? activeColor.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: active ? activeColor : AppColors.textSecondary,
            ),
          ),
        ),
      );
}


class RulesList extends StatelessWidget {
  final Color color;
  final List<(String, String)> items;
  const RulesList({super.key, required this.color, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(items.length, (i) {
        final (badge, label) = items[i];
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              Container(
                width: 42, height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: Text(badge,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800, color: color)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textPrimary)),
              ),
            ]),
          ),
          if (i < items.length - 1)
            const Divider(height: 1, color: Color(0xFFF5F5F5), indent: 70),
        ]);
      }),
    );
  }
}

