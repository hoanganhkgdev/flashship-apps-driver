import 'package:flutter/material.dart';

/// Wrapper card trắng bo góc dùng chung cho các block trong active_order_screen
/// (RouteCard, TopupCard, BatchStopsCard, EarningCard).
Widget orderCardShell({required Widget child}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
