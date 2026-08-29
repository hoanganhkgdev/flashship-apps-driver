import 'package:flutter/material.dart';

class OfferActions extends StatelessWidget {
  final bool accepting;
  final bool declining;
  final double bottomInset;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const OfferActions({
    super.key,
    required this.accepting,
    required this.declining,
    required this.bottomInset,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(children: [
        Expanded(
            child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: accepting || declining ? null : onDecline,
                  icon:
                      const Icon(Icons.close_rounded, color: Color(0xFF17110F)),
                  label: declining
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Từ chối',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD83C35),
                      side: const BorderSide(color: Color(0xFFD83C35)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26))),
                ))),
        const SizedBox(width: 12),
        Expanded(
            flex: 2,
            child: SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6035),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26)),
                ),
                onPressed: accepting || declining ? null : onAccept,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_rounded, size: 22, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Nhận đơn',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ],
                ),
              ),
            )),
      ]),
    );
  }
}
