import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';

class SupportItem {
  final String title;
  final String? subtitle;
  final String type;
  final String value;
  final String? color;

  const SupportItem({
    required this.title,
    this.subtitle,
    required this.type,
    required this.value,
    this.color,
  });

  factory SupportItem.fromJson(Map<String, dynamic> j) => SupportItem(
    title:    j['title'] as String,
    subtitle: j['subtitle'] as String?,
    type:     j['type'] as String? ?? 'url',
    value:    j['value'] as String,
    color:    j['color'] as String?,
  );

  Uri get uri => Uri.parse(value);

  Color get displayColor {
    if (color == null || color!.length < 7) return const Color(0xFF6B7280);
    return Color(int.parse('FF${color!.replaceFirst('#', '')}', radix: 16));
  }
}

final supportProvider = FutureProvider<List<SupportItem>>((ref) async {
  try {
    final res = await ref.read(apiClientProvider).get('/driver/support');
    final list = (res.data['data'] as List? ?? []);
    return list.map((e) => SupportItem.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
});
