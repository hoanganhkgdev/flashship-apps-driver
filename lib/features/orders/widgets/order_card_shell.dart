import 'package:flutter/material.dart';

/// Wrapper card trắng bo góc dùng chung cho các block trong active_order_screen
/// (RouteCard, TopupCard, BatchStopsCard, EarningCard).
Widget orderCardShell({required Widget child}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5DDD9)),
      ),
      child: child,
    );
