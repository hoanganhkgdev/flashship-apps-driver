import 'package:flutter/material.dart';

Widget surfaceCard(
    {required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) {
  return Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xFFFFFEFD),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE5DDD9)),
    ),
    child: child,
  );
}
