import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_back_button.dart';
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
      final res =
          await ref.read(apiClientProvider).get('/pages/${widget.slug}');
      final data = (res.data['data'] ?? res.data) as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _content =
              data?['content'] as String? ?? data?['body'] as String? ?? '';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFFF6035),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFEFD),
        body: Column(children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            color: const Color(0xFFFF6035),
            padding: EdgeInsets.fromLTRB(16, top + 10, 16, 16),
            child: Row(children: [
              AppBackButton.onColor(onTap: () => Navigator.of(context).pop()),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ]),
          ),

          // ── Body ──────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF6035),
                      strokeWidth: 2,
                    ),
                  )
                : _error
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 40, color: AppColors.textSecondary),
                            const SizedBox(height: 12),
                            const Text('Không thể tải nội dung',
                                style:
                                    TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _loading = true;
                                  _error = false;
                                });
                                _load();
                              },
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 18, 12, 36),
                        child: Html(
                          data: _content ?? '',
                          style: {
                            'body': Style(
                              fontFamily: GoogleFonts.robotoCondensed().fontFamily,
                              fontSize: FontSize(15),
                              lineHeight: LineHeight(1.55),
                              color: const Color(0xFF1B1411),
                              margin: Margins.zero,
                              padding: HtmlPaddings.symmetric(horizontal: 4),
                            ),
                            'h1': Style(
                              fontSize: FontSize(22),
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1B1411),
                              lineHeight: LineHeight(1.25),
                              margin: Margins.only(top: 10, bottom: 10),
                            ),
                            'h2': Style(
                              fontSize: FontSize(18),
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1B1411),
                              lineHeight: LineHeight(1.3),
                              margin: Margins.only(top: 18, bottom: 7),
                            ),
                            'h3': Style(
                              fontSize: FontSize(16),
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1B1411),
                              lineHeight: LineHeight(1.3),
                              margin: Margins.only(top: 14, bottom: 5),
                            ),
                            'p': Style(
                              margin: Margins.only(bottom: 11),
                            ),
                            'li': Style(
                              margin: Margins.only(bottom: 7),
                            ),
                            'strong': Style(fontWeight: FontWeight.w800),
                          },
                        ),
                      ),
          ),
        ]),
      ),
    );
  }
}
