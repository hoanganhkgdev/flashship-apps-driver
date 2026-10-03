import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../auth/providers/auth_provider.dart';

class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
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
    Future.microtask(_loadData);
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
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _completedSteps {
    int n = 0;
    if (_cccdStatus == 'approved') n++;
    if (_licenseStatus == 'approved') n++;
    return n;
  }

  // ── Uploads ──────────────────────────────────────────────────────────────────

  void _showUploadSheet({
    required String title,
    required VoidCallback onCamera,
    required VoidCallback onGallery,
  }) {
    showAppBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
    } catch (_) {
      if (mounted) {
        setState(() => _uploadingCccd = false);
        _toast('Tải lên thất bại');
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
    } catch (_) {
      if (mounted) {
        setState(() => _uploadingLicense = false);
        _toast('Tải lên thất bại');
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
        appBar: const AppScreenHeader(title: 'Hồ sơ tài xế'),
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

                    const SizedBox(height: 16),

                    // ── Giấy tờ ─────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel('GIẤY TỜ TÙY THÂN'),
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
    final isDone = steps == 2;
    final colors = isDone
        ? const [Color(0xFF1F8A4C), Color(0xFF34B368)]
        : const [AppColors.primary, Color(0xFFFF8A3D)];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: .28),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(children: [
          // Vòng tiến độ x/2
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: steps / 2,
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  color: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: .25),
                ),
              ),
              Text('$steps/2',
                  style: AppTextStyles.metric
                      .copyWith(color: Colors.white, fontSize: 22)),
            ]),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                isDone ? 'Hồ sơ hoàn thiện' : 'Hoàn thiện hồ sơ',
                style: AppTextStyles.sectionTitle
                    .copyWith(color: Colors.white, fontSize: AppFontSize.lg),
              ),
              const SizedBox(height: 3),
              Text(
                isDone
                    ? 'Bạn có thể nhận tất cả loại đơn hàng'
                    : 'Điền đủ thông tin để nhận nhiều đơn hơn',
                style: AppTextStyles.label
                    .copyWith(color: Colors.white.withValues(alpha: .9)),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(spacing: AppSpacing.sm, runSpacing: 6, children: [
                _StepStatus(label: 'CCCD', done: _cccdStatus == 'approved'),
                _StepStatus(
                    label: 'Bằng lái', done: _licenseStatus == 'approved'),
              ]),
            ]),
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
        label: 'Bằng lái xe',
        status: _licenseStatus,
        imageUrl: _licenseImageUrl,
        rejectionReason: _licenseRejectionReason,
        isUploading: _uploadingLicense,
        onTap: () => _showUploadSheet(
          title: 'Tải lên bằng lái xe',
          onCamera: () => _pickAndUploadLicense(ImageSource.camera),
          onGallery: () => _pickAndUploadLicense(ImageSource.gallery),
        ),
      ),
    ]);
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w800,
          letterSpacing: .8,
        ),
      );
}

// ── Step status ───────────────────────────────────────────────────────────────

class _StepStatus extends StatelessWidget {
  final String label;
  final bool done;
  const _StepStatus({required this.label, required this.done});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: done ? .28 : .16),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
      );
}

// ── Doc card ──────────────────────────────────────────────────────────────────

class _DocCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? status;
  final String? imageUrl;
  final String? rejectionReason;
  final bool isUploading;
  final VoidCallback? onTap;

  const _DocCard({
    required this.icon,
    required this.label,
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

    return AppSurfaceCard(
      color: Colors.white,
      showBorder: false,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Ảnh / khung icon, trạng thái nổi ở góc trên phải.
          Stack(children: [
            imageUrl != null
                ? Image.network(imageUrl!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _iconArea(icon, color))
                : _iconArea(icon, color),
            Positioned(
              top: AppSpacing.md,
              right: AppSpacing.md,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  boxShadow: AppShadows.soft,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(statusIcon, size: 14, color: color),
                  const SizedBox(width: 5),
                  Text(statusLabel,
                      style: AppTextStyles.caption
                          .copyWith(color: color, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: AppTextStyles.sectionTitle
                      .copyWith(color: AppColors.textPrimary)),
              if (status == 'rejected' &&
                  (rejectionReason?.isNotEmpty ?? false)) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 16, color: AppColors.danger),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(rejectionReason!,
                              style: AppTextStyles.label.copyWith(
                                  color: AppColors.danger, height: 1.4)),
                        ),
                      ]),
                ),
              ],
              if (status != 'approved') ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: canUpload ? onTap : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    icon: isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.upload_rounded,
                            size: 18, color: Colors.white),
                    label: Text(
                      isUploading
                          ? 'Đang tải lên...'
                          : (status == null ? 'Tải lên' : 'Cập nhật'),
                      style: const TextStyle(
                          fontSize: AppFontSize.md,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _iconArea(IconData icon, Color color) => Container(
        height: 150,
        width: double.infinity,
        color: color.withValues(alpha: 0.08),
        child: Center(
            child: Icon(icon, size: 52, color: color.withValues(alpha: 0.5))),
      );
}
