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
        appBar: AppScreenHeader(
          title: widget.title,
          backgroundColor: AppColors.primarySoft,
        ),
        body: Column(children: [
          // ── Body ──────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const _LegalLoading()
                : _error
                    ? _LegalError(
                        onRetry: () {
                          setState(() {
                            _loading = true;
                            _error = false;
                          });
                          _load();
                        },
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                            AppSpacing.lg, AppSpacing.lg, AppSpacing.xl3),
                        child: Column(children: [
                          _LegalIntro(
                            isPrivacy: widget.slug == 'privacy-policy',
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if ((_content ?? '').trim().isEmpty)
                            const _LegalEmpty()
                          else
                            AppSurfaceCard(
                              color: AppColors.surface,
                              showBorder: true,
                              showShadow: false,
                              padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                                  AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
                              child: Html(
                                data: _content ?? '',
                                style: {
                                  'body': Style(
                                    fontFamily: GoogleFonts.inter().fontFamily,
                                    fontSize: FontSize(AppFontSize.base),
                                    lineHeight: LineHeight(1.65),
                                    color: AppColors.textPrimary,
                                    margin: Margins.zero,
                                    padding:
                                        HtmlPaddings.symmetric(horizontal: 4),
                                  ),
                                  'h1': Style(
                                    fontSize: FontSize(AppFontSize.xl2),
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    lineHeight: LineHeight(1.25),
                                    margin: Margins.only(top: 10, bottom: 10),
                                  ),
                                  'h2': Style(
                                    fontSize: FontSize(AppFontSize.lg),
                                    fontWeight: FontWeight.w600,
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
                                    fontWeight: FontWeight.w600,
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
                                  'strong': Style(fontWeight: FontWeight.w600),
                                  'a': Style(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
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
    return AppSurfaceCard(
      color: AppColors.surface,
      showBorder: true,
      showShadow: false,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            isPrivacy ? Icons.privacy_tip_rounded : Icons.gavel_rounded,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isPrivacy ? 'Bảo vệ thông tin của bạn' : 'Quy định sử dụng',
                style: AppTextStyles.sectionTitle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isPrivacy
                    ? 'Cách FlashShip thu thập, sử dụng và bảo vệ dữ liệu tài xế.'
                    : 'Các quyền và trách nhiệm khi tài xế sử dụng FlashShip.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _LegalLoading extends StatelessWidget {
  const _LegalLoading();

  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Container(
            height: 92,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                7,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Container(
                    height: index == 0 ? 20 : 12,
                    width: index == 0 || index.isEven
                        ? double.infinity
                        : MediaQuery.sizeOf(context).width * .58,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}

class _LegalError extends StatelessWidget {
  final VoidCallback onRetry;

  const _LegalError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Icon(Icons.cloud_off_rounded,
                    size: 28, color: AppColors.danger),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Không thể tải nội dung',
                style: AppTextStyles.sectionTitle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Vui lòng kiểm tra kết nối và thử lại.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
}

class _LegalEmpty extends StatelessWidget {
  const _LegalEmpty();

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
        color: AppColors.surface,
        showBorder: true,
        showShadow: false,
        child: Column(children: [
          const Icon(Icons.description_outlined,
              size: 30, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Nội dung đang được cập nhật',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyStrong.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
      );
}
