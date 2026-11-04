import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../auth/providers/auth_provider.dart';

class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen>
    with WidgetsBindingObserver {
  bool _loading = true;

  // Docs
  String? _cccdStatus;
  String? _cccdImageUrl;
  String? _cccdRejectionReason;
  bool _uploadingCccd = false;
  String? _licenseStatus;
  String? _licenseImageUrl;
  String? _licenseRejectionReason;
  bool _uploadingLicense = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_loadData);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Link ảnh KYC là link có chữ ký, hết hạn sau 30 phút. Quay lại app thì
  // xin link mới để ảnh không biến thành icon.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_uploadingCccd &&
        !_uploadingLicense) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/driver/profile');
      final data = ((res.data['data'] ?? res.data)
          as Map<String, dynamic>)['user'] as Map<String, dynamic>?;
      if (mounted && data != null) {
        setState(() {
          _cccdStatus = data['cccd_image_status'] as String?;
          _cccdImageUrl = data['cccd_image_url'] as String?;
          _cccdRejectionReason = data['cccd_image_rejection_reason'] as String?;
          _licenseStatus = data['license_status'] as String?;
          _licenseImageUrl = data['license_image_url'] as String?;
          _licenseRejectionReason = data['license_rejection_reason'] as String?;
        });
      }
    } catch (_) {
      // Giữ dữ liệu gần nhất nếu refresh thất bại.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _completedSteps {
    return _cccdStatus == 'approved' ? 1 : 0;
  }

  // ── Uploads ──────────────────────────────────────────────────────────────────

  void _showUploadSheet({
    required String title,
    required VoidCallback onCamera,
    required VoidCallback onGallery,
  }) {
    showAppBottomSheet(
      context: context,
      builder: (ctx) => AppBottomSheetBody(
        bottomPadding: 16,
        keyboardAware: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AppBottomSheetHeader(
            title: title,
            subtitle: 'Ảnh rõ nét, đủ ánh sáng, không bị mờ',
            icon: Icons.add_a_photo_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          AppSheetOption(
            icon: Icons.camera_alt_outlined,
            label: 'Chụp ảnh',
            subtitle: 'Dùng máy ảnh ngay bây giờ',
            showChevron: true,
            onTap: () {
              Navigator.pop(ctx);
              onCamera();
            },
          ),
          AppSheetOption(
            icon: Icons.photo_library_outlined,
            iconBackground: AppColors.infoSoft,
            iconColor: AppColors.info,
            label: 'Chọn từ thư viện',
            subtitle: 'Lấy ảnh có sẵn trong máy',
            showChevron: true,
            onTap: () {
              Navigator.pop(ctx);
              onGallery();
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _pickAndUploadCccd(ImageSource source) async {
    if (_uploadingCccd) return;
    XFile? file;
    try {
      file = await ImagePicker().pickImage(
          source: source, maxWidth: 1600, maxHeight: 1200, imageQuality: 90);
    } catch (_) {
      return;
    }
    if (file == null || !mounted) return;
    setState(() => _uploadingCccd = true);
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(file.path, filename: file.name)
      });
      final res = await ref
          .read(apiClientProvider)
          .postMultipart('/driver/profile/cccd-image', formData);
      final imageUrl = res.data['image_url'] as String?;
      if (mounted) {
        setState(() {
          _cccdStatus = 'pending';
          _cccdImageUrl = imageUrl;
          _uploadingCccd = false;
        });
        _toast('Tải lên thành công, đang chờ xét duyệt', success: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingCccd = false);
        _toast(parseApiError(e, fallback: 'Tải lên thất bại'));
      }
    }
  }

  Future<void> _pickAndUploadLicense(ImageSource source) async {
    if (_uploadingLicense) return;
    XFile? file;
    try {
      file = await ImagePicker().pickImage(
          source: source, maxWidth: 1600, maxHeight: 1200, imageQuality: 90);
    } catch (_) {
      return;
    }
    if (file == null || !mounted) return;
    setState(() => _uploadingLicense = true);
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(file.path, filename: file.name)
      });
      final res = await ref
          .read(apiClientProvider)
          .postMultipart('/driver/profile/license', formData);
      final imageUrl = res.data['image_url'] as String?;
      if (mounted) {
        setState(() {
          _licenseStatus = 'pending';
          _licenseImageUrl = imageUrl;
          _uploadingLicense = false;
        });
        _toast('Tải lên thành công, đang chờ xét duyệt', success: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingLicense = false);
        _toast(parseApiError(e, fallback: 'Tải lên thất bại'));
      }
    }
  }

  void _toast(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.success : AppColors.danger,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final steps = _completedSteps;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        // Header giờ nền trắng (trước là gradient cam) — icon status bar
        // phải đổi sang màu đen mới nhìn thấy được.
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const AppScreenHeader(
          title: 'Xác minh tài khoản',
          backgroundColor: AppColors.primarySoft,
        ),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadData,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildHeader(steps),

                    const SizedBox(height: AppSpacing.md),

                    // ── Giấy tờ ─────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel(),
                            const SizedBox(height: AppSpacing.md),
                            _buildDocsCard(),
                          ]),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────

  Widget _buildHeader(int steps) {
    final isDone = steps == 1;
    final accent = isDone ? AppColors.success : AppColors.primary;
    final accentSoft = isDone ? AppColors.successSoft : AppColors.primarySoft;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: accent.withValues(alpha: .18)),
        ),
        child: Column(children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentSoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                isDone ? Icons.verified_user_rounded : Icons.shield_outlined,
                color: accent,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDone ? 'Tài khoản đã xác minh' : 'Xác minh tài khoản',
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isDone
                        ? 'Bạn đã hoàn tất giấy tờ cần thiết'
                        : 'Hoàn tất giấy tờ để sẵn sàng nhận đơn',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accentSoft,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                '$steps/1',
                style: AppTextStyles.label.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: steps.toDouble(),
              minHeight: 5,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Docs card ─────────────────────────────────────────────────────────────────

  Widget _buildDocsCard() {
    return Column(children: [
      _DocCard(
        icon: Icons.badge_rounded,
        label: 'CCCD / CMND',
        requirementLabel: 'Bắt buộc',
        status: _cccdStatus,
        imageUrl: _cccdImageUrl,
        rejectionReason: _cccdRejectionReason,
        isUploading: _uploadingCccd,
        onTap: () => _showUploadSheet(
          title: 'Tải lên hình CCCD / CMND',
          onCamera: () => _pickAndUploadCccd(ImageSource.camera),
          onGallery: () => _pickAndUploadCccd(ImageSource.gallery),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      _DocCard(
        icon: Icons.drive_eta_rounded,
        label: 'Bằng lái ô tô',
        requirementLabel: 'Tùy chọn',
        unlocksCarOrders: true,
        status: _licenseStatus,
        imageUrl: _licenseImageUrl,
        rejectionReason: _licenseRejectionReason,
        isUploading: _uploadingLicense,
        onTap: () => _showUploadSheet(
          title: 'Tải lên bằng lái ô tô',
          onCamera: () => _pickAndUploadLicense(ImageSource.camera),
          onGallery: () => _pickAndUploadLicense(ImageSource.gallery),
        ),
      ),
    ]);
  }

  Widget _sectionLabel() => Row(children: [
        Container(
          width: 4,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Giấy tờ xác minh',
              style: AppTextStyles.sectionTitle.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'CCCD bắt buộc · Bằng lái ô tô tùy chọn',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ]),
        ),
      ]);
}

// ── Doc card ──────────────────────────────────────────────────────────────────

class _DocCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String requirementLabel;
  final bool unlocksCarOrders;
  final String? status;
  final String? imageUrl;
  final String? rejectionReason;
  final bool isUploading;
  final VoidCallback? onTap;

  const _DocCard({
    required this.icon,
    required this.label,
    required this.requirementLabel,
    this.unlocksCarOrders = false,
    this.status,
    this.imageUrl,
    this.rejectionReason,
    this.isUploading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (statusLabel, color, statusIcon) = switch (status) {
      'approved' => ('Đã xác minh', AppColors.success, Icons.verified_rounded),
      'rejected' => ('Bị từ chối', AppColors.danger, Icons.cancel_rounded),
      'pending' => (
          'Đang xét duyệt',
          AppColors.warning,
          Icons.hourglass_top_rounded
        ),
      _ => ('Chưa tải lên', AppColors.textSecondary, Icons.upload_rounded),
    };
    // Chặn bấm lần nữa trong lúc đang upload — tránh gửi nhiều request cùng lúc.
    final bool canUpload = status != 'approved' && !isUploading;
    final description = unlocksCarOrders
        ? switch (status) {
            'approved' => 'Đã đủ điều kiện nhận đơn lái hộ ô tô',
            'rejected' => 'Cập nhật lại để đăng ký nhận đơn ô tô',
            'pending' => 'Duyệt xong sẽ mở đơn lái hộ ô tô',
            _ => 'Tải lên để đăng ký nhận đơn lái hộ ô tô',
          }
        : switch (status) {
            'approved' => 'Thông tin đã được xác nhận',
            'rejected' => 'Vui lòng cập nhật lại ảnh giấy tờ',
            'pending' => 'Hồ sơ đang được kiểm tra',
            _ => 'Chưa có ảnh giấy tờ',
          };

    return AppSurfaceCard(
      color: AppColors.surface,
      showBorder: true,
      showShadow: false,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: imageUrl != null
                ? Image.network(
                    imageUrl!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _iconArea(icon, color),
                  )
                : _iconArea(icon, color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: requirementLabel == 'Bắt buộc'
                        ? AppColors.primarySoft
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    requirementLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: requirementLabel == 'Bắt buộc'
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 5),
              Row(children: [
                Icon(statusIcon, size: 14, color: color),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 3),
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ]),
          ),
        ]),
        if (status == 'rejected' && (rejectionReason?.isNotEmpty ?? false)) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.error_outline_rounded,
                  size: 16, color: AppColors.danger),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  rejectionReason!,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.danger,
                    height: 1.4,
                  ),
                ),
              ),
            ]),
          ),
        ],
        if (status != 'approved') ...[
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: canUpload ? onTap : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              icon: isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_rounded,
                      size: 18, color: Colors.white),
              label: Text(
                isUploading
                    ? 'Đang tải lên...'
                    : (status == null ? 'Tải ảnh giấy tờ' : 'Cập nhật ảnh'),
                style: const TextStyle(
                  fontSize: AppFontSize.base,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _iconArea(IconData icon, Color color) => Container(
        width: 64,
        height: 64,
        color: color.withValues(alpha: 0.08),
        child: Icon(icon, size: 28, color: color.withValues(alpha: 0.65)),
      );
}
