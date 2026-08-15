import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/launch_utils.dart';
import '../providers/support_provider.dart';

/// Nút hỗ trợ nổi góc dưới phải — thay cho card Hỗ trợ trống trước đây.
/// Tự lấy danh sách kênh liên hệ (điện thoại/zalo/facebook/email/website,
/// admin cấu hình được) từ supportProvider, không hardcode 1 số điện thoại.
class SupportFab extends ConsumerWidget {
  const SupportFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(supportProvider).value ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _showSheet(context, items),
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.headset_mic_rounded, color: Colors.white, size: 24),
      ),
    );
  }

  void _showSheet(BuildContext context, List<SupportItem> items) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Hỗ trợ',
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  )),
            ),
          ),
          ...items.map((item) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: item.displayColor.withValues(alpha: 0.12),
                  child: Icon(item.materialIcon, color: item.displayColor),
                ),
                title: Text(item.title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
                trailing: Text(item.ctaLabel,
                    style: TextStyle(
                        color: item.displayColor, fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(context);
                  launchExternal(item.uri);
                },
              )),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}
