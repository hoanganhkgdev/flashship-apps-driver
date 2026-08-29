import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';

class HistoryHeader extends StatelessWidget {
  final int todayCount, activeCount, todayEarnings, walletBalance, tabIndex;
  final bool isOnShift;
  final ValueChanged<int> onTab;

  const HistoryHeader(
      {super.key,
      required this.todayCount,
      required this.activeCount,
      required this.todayEarnings,
      required this.walletBalance,
      required this.tabIndex,
      required this.isOnShift,
      required this.onTab});

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFFFF8F5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(height: MediaQuery.paddingOf(context).top + 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Text('Đơn hàng',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.7,
                      color: Color(0xFF1B1411))),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                    color: const Color(0xFFE3F5F4),
                    borderRadius: BorderRadius.circular(22)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.schedule_rounded,
                      size: 17, color: Color(0xFF17110F)),
                  const SizedBox(width: 8),
                  Text(isOnShift ? 'Đang trong ca' : 'Ngoài ca',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF008F92))),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFFEFD),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5DDD9))),
              child: Row(children: [
                _Stat(value: '$todayCount', label: 'Đơn hôm nay'),
                const _Divider(),
                _Stat(
                    value: Fmt.currency(todayEarnings),
                    label: 'Thu nhập',
                    green: true),
                const _Divider(),
                _Stat(value: Fmt.currency(walletBalance), label: 'Số dư ví'),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            _Tab(
                label: 'Đang nhận',
                count: activeCount,
                active: tabIndex == 0,
                onTap: () => onTab(0)),
            _Tab(
                label: 'Hoàn thành',
                active: tabIndex == 1,
                onTap: () => onTab(1)),
          ]),
        ]),
      );
}

class _Stat extends StatelessWidget {
  final String value, label;
  final bool green;
  const _Stat({required this.value, required this.label, this.green = false});
  @override
  Widget build(BuildContext context) => Expanded(
          child: Column(children: [
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color:
                    green ? const Color(0xFF229650) : const Color(0xFF1B1411))),
        const SizedBox(height: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFFA99F9A))),
      ]));
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: const Color(0xFFE5DDD9));
}

class _Tab extends StatelessWidget {
  final String label;
  final int? count;
  final bool active;
  final VoidCallback onTap;
  const _Tab(
      {required this.label,
      this.count,
      required this.active,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 11),
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color:
                        active ? const Color(0xFFFF6035) : Colors.transparent,
                    width: 2))),
        child: Row(children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: active
                      ? const Color(0xFFFF6035)
                      : const Color(0xFF6A605C))),
          if (count != null && count! > 0) ...[
            const SizedBox(width: 7),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                color: const Color(0xFFFF6035),
                child: Text('$count',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white))),
          ],
        ]),
      ));
}
