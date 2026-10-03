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
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  )
                : _error
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.lg),
                              ),
                              child: const Icon(Icons.cloud_off_rounded,
                                  size: 30, color: AppColors.textTertiary),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            const Text('Không thể tải nội dung',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: AppSpacing.sm),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _loading = true;
                                  _error = false;
                                });
                                _load();
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Thử lại'),
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
                          const SizedBox(height: AppSpacing.lg),
                          AppSurfaceCard(
                            color: Colors.white,
                            showBorder: false,
                            padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                                AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
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
                                  margin: Margins.only(top: 20, bottom: 8),
                                  padding: HtmlPaddings.only(left: 10),
                                  border: const Border(
                                    left: BorderSide(
                                        color: AppColors.primary, width: 3),
                                  ),
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
                                'a': Style(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                                'blockquote': Style(
                                  backgroundColor: AppColors.primarySoft,
                                  padding: HtmlPaddings.all(12),
                                  margin: Margins.only(top: 8, bottom: 12),
                                ),
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
    final color = isPrivacy ? AppColors.info : AppColors.primary;
    return Column(children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Icon(
          isPrivacy ? Icons.privacy_tip_rounded : Icons.gavel_rounded,
          color: color,
          size: 32,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        isPrivacy ? 'Bảo vệ thông tin của bạn' : 'Quy định sử dụng',
        textAlign: TextAlign.center,
        style: AppTextStyles.screenTitle.copyWith(
            fontSize: AppFontSize.xl2,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary),
      ),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Text(
          isPrivacy
              ? 'Thông tin về cách FlashShip thu thập, sử dụng và bảo vệ dữ liệu tài xế.'
              : 'Các quyền và trách nhiệm khi tài xế sử dụng dịch vụ FlashShip.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      ),
    ]);
  }
}
