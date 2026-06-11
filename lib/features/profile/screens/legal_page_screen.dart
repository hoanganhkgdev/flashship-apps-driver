import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class LegalPageScreen extends ConsumerStatefulWidget {
  final String slug;
  final String title;

  const LegalPageScreen({super.key, required this.slug, required this.title});

  @override
  ConsumerState<LegalPageScreen> createState() => _LegalPageScreenState();
}

class _LegalPageScreenState extends ConsumerState<LegalPageScreen> {
  String? _content;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get('/pages/${widget.slug}');
      final data = (res.data['data'] ?? res.data) as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _content = data?['content'] as String? ?? data?['body'] as String? ?? '';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Column(children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            color: AppColors.primary,
            padding: EdgeInsets.fromLTRB(8, top + 8, 16, 16),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 4),
              Text(widget.title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ]),
          ),

          // ── Body ──────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 40, color: AppColors.textSecondary),
                            const SizedBox(height: 12),
                            const Text('Không thể tải nội dung',
                                style: TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                setState(() { _loading = true; _error = false; });
                                _load();
                              },
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: Html(
                          data: _content ?? '',
                          style: {
                            'body': Style(
                              fontSize: FontSize(14),
                              lineHeight: LineHeight(1.6),
                              color: AppColors.textPrimary,
                              margin: Margins.zero,
                              padding: HtmlPaddings.symmetric(horizontal: 12),
                            ),
                            'h1': Style(
                              fontSize: FontSize(20),
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              margin: Margins.only(top: 16, bottom: 8),
                            ),
                            'h2': Style(
                              fontSize: FontSize(17),
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              margin: Margins.only(top: 16, bottom: 6),
                            ),
                            'h3': Style(
                              fontSize: FontSize(15),
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              margin: Margins.only(top: 12, bottom: 4),
                            ),
                            'p': Style(
                              margin: Margins.only(bottom: 10),
                            ),
                            'li': Style(
                              margin: Margins.only(bottom: 4),
                            ),
                            'strong': Style(fontWeight: FontWeight.w600),
                          },
                        ),
                      ),
          ),
        ]),
      ),
    );
  }
}
