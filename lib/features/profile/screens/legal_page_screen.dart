import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/app_surface_card.dart';
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppScreenHeader(title: widget.title),
        body: Column(children: [
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
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                            AppSpacing.lg, AppSpacing.lg, AppSpacing.xl3),
                        child: Column(children: [
                          _LegalIntro(
                            isPrivacy: widget.slug == 'privacy-policy',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppSurfaceCard(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                                AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
                            child: Html(
                              data: _content ?? '',
                              style: {
                                'body': Style(
                                  fontFamily: GoogleFonts.inter().fontFamily,
                                  fontSize: FontSize(AppFontSize.base),
                                  lineHeight: LineHeight(1.6),
                                  color: AppColors.textPrimary,
                                  margin: Margins.zero,
                                  padding:
                                      HtmlPaddings.symmetric(horizontal: 4),
                                ),
                                'h1': Style(
                                  fontSize: FontSize(AppFontSize.xl2),
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  lineHeight: LineHeight(1.25),
                                  margin: Margins.only(top: 10, bottom: 10),
                                ),
                                'h2': Style(
                                  fontSize: FontSize(AppFontSize.lg),
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  lineHeight: LineHeight(1.3),
                                  margin: Margins.only(top: 18, bottom: 7),
                                ),
                                'h3': Style(
                                  fontSize: FontSize(AppFontSize.md),
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
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
                        ]),
                      ),
          ),
        ]),
      ),
    );
  }
}

class _LegalIntro extends StatelessWidget {
  final bool isPrivacy;

  const _LegalIntro({required this.isPrivacy});

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      color: isPrivacy ? AppColors.infoSoft : AppColors.primarySoft,
      showBorder: false,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            isPrivacy ? Icons.privacy_tip_outlined : Icons.gavel_rounded,
            color: isPrivacy ? AppColors.info : AppColors.primary,
            size: 21,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              isPrivacy ? 'Bảo vệ thông tin của bạn' : 'Quy định sử dụng',
              style: AppTextStyles.bodyStrong,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isPrivacy
                  ? 'Thông tin về cách FlashShip thu thập, sử dụng và bảo vệ dữ liệu tài xế.'
                  : 'Các quyền và trách nhiệm khi tài xế sử dụng dịch vụ FlashShip.',
              style: const TextStyle(
                fontSize: AppFontSize.sm,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
