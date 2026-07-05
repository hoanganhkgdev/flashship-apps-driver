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

  // Chuẩn hoá value thành URI launch được — admin có thể nhập số/link thô
  // (vd "0981483284", "zalo.me/flashship") thiếu scheme.
  Uri get uri {
    final v = value.trim();
    switch (type) {
      case 'phone':
        final raw = v.startsWith('tel:') ? v.substring(4) : v;
        return Uri.parse('tel:${raw.replaceAll(RegExp(r'[^0-9+]'), '')}');
      case 'email':
        final raw = v.startsWith('mailto:') ? v.substring(7) : v;
        return Uri.parse('mailto:$raw');
      default:
        // zalo / facebook / website / url — đảm bảo có scheme
        final parsed = Uri.tryParse(v);
        if (parsed != null && parsed.hasScheme) return parsed;
        return Uri.parse('https://$v');
    }
  }

  IconData get materialIcon => switch (type) {
    'phone'    => Icons.phone_rounded,
    'email'    => Icons.email_rounded,
    'website'  => Icons.language_rounded,
    'zalo'     => Icons.chat_rounded,
    'facebook' => Icons.thumb_up_alt_rounded,
    _          => Icons.link_rounded,
  };

  String get ctaLabel => switch (type) {
    'phone'    => 'Gọi ngay',
    'email'    => 'Gửi email',
    'zalo'     => 'Chat Zalo',
    'facebook' => 'Nhắn tin',
    'website'  => 'Xem ngay',
    _          => 'Liên hệ',
  };

  Color get displayColor => switch (type) {
    'phone'    => const Color(0xFF34C759),
    'zalo'     => const Color(0xFF0068FF),
    'facebook' => const Color(0xFF1877F2),
    'email'    => const Color(0xFFEA4335),
    'website'  => const Color(0xFF6B7280),
    _          => const Color(0xFF6B7280),
  };
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
