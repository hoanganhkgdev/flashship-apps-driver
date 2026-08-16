import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
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
  bool    _uploadingCccd = false;
  String? _licenseStatus;
  String? _licenseImageUrl;
  String? _licenseRejectionReason;
  bool    _uploadingLicense = false;

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
      final data = ((res.data['data'] ?? res.data) as Map<String, dynamic>)['user']
          as Map<String, dynamic>?;
      if (mounted && data != null) {
        setState(() {
          _cccdStatus             = data['cccd_image_status'] as String?;
          _cccdImageUrl           = data['cccd_image_url'] as String?;
          _cccdRejectionReason    = data['cccd_image_rejection_reason'] as String?;
          _licenseStatus          = data['license_status'] as String?;
          _licenseImageUrl        = data['license_image_url'] as String?;
          _licenseRejectionReason = data['license_rejection_reason'] as String?;
          _loading                = false;
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Ảnh rõ nét, đủ ánh sáng, không bị mờ',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
          ),
          const Divider(height: 1),
          _UploadOption(
            icon: Icons.camera_alt_rounded,
            iconColor: AppColors.primary,
            label: 'Chụp ảnh',
            onTap: () { Navigator.pop(ctx); onCamera(); },
          ),
          const Divider(height: 1, indent: 56),
          _UploadOption(
            icon: Icons.photo_library_rounded,
            iconColor: AppColors.info,
            label: 'Chọn từ thư viện',
            onTap: () { Navigator.pop(ctx); onGallery(); },
          ),
          const SizedBox(height: 8),
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
    } catch (_) { return; }
    if (file == null || !mounted) return;
    setState(() => _uploadingCccd = true);
    try {
      final formData = FormData.fromMap(
          {'image': await MultipartFile.fromFile(file.path, filename: file.name)});
      final res = await ref.read(apiClientProvider).postMultipart('/driver/profile/cccd-image', formData);
      final imageUrl = res.data['image_url'] as String?;
      if (mounted) {
        setState(() {
          _cccdStatus    = 'pending';
          _cccdImageUrl  = imageUrl;
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
    } catch (_) { return; }
    if (file == null || !mounted) return;
    setState(() => _uploadingLicense = true);
    try {
      final formData = FormData.fromMap(
          {'image': await MultipartFile.fromFile(file.path, filename: file.name)});
      final res = await ref.read(apiClientProvider).postMultipart('/driver/profile/license', formData);
      final imageUrl = res.data['image_url'] as String?;
      if (mounted) {
        setState(() {
          _licenseStatus     = 'pending';
          _licenseImageUrl   = imageUrl;
          _uploadingLicense  = false;
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
    final top   = MediaQuery.of(context).padding.top;
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
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadData,
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : ListView(
            padding: EdgeInsets.zero,
            children: [

              _buildHeader(top, steps),

              const SizedBox(height: 16),

              // ── Giấy tờ ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _sectionLabel('GIẤY TỜ TÙY THÂN'),
                  const SizedBox(height: 8),
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

  Widget _buildHeader(double top, int steps) {
    final isDone = steps == 2;
    return Column(children: [

      // Top bar
      Container(
        width: double.infinity,
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(16, top + 4, 16, 12),
        child: Row(children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: SizedBox(
              width: 40, height: 40,
              child: Center(
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textPrimary, size: 16),
                ),
              ),
            ),
          ),
          const Expanded(
            child: Text('Hồ sơ tài xế',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2)),
          ),
          const SizedBox(width: 40),
        ]),
      ),

      // Summary card
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isDone ? Icons.verified_user_rounded : Icons.shield_rounded,
                  color: AppColors.primary, size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    isDone ? 'Hồ sơ hoàn thiện' : 'Hoàn thiện hồ sơ',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isDone
                        ? 'Bạn có thể nhận tất cả loại đơn hàng'
                        : 'Điền đủ thông tin để nhận nhiều đơn hơn',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$steps/2',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ]),

            const SizedBox(height: 14),

            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: steps / 2,
                minHeight: 6,
                backgroundColor: AppColors.divider,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              _StepStatus(label: 'CCCD', done: _cccdStatus == 'approved'),
              const SizedBox(width: 20),
              _StepStatus(label: 'Bằng lái', done: _licenseStatus == 'approved'),
            ]),
          ]),
        ),
      ),
    ]);
  }

  // ── Docs card ─────────────────────────────────────────────────────────────────

  Widget _buildDocsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(
          child: _DocCard(
            icon: Icons.badge_rounded,
            label: 'CCCD / CMND',
            status: _cccdStatus,
            imageUrl: _cccdImageUrl,
            rejectionReason: _cccdRejectionReason,
            isUploading: _uploadingCccd,
            onTap: () => _showUploadSheet(
              title: 'Tải lên hình CCCD / CMND',
              onCamera:  () => _pickAndUploadCccd(ImageSource.camera),
              onGallery: () => _pickAndUploadCccd(ImageSource.gallery),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DocCard(
            icon: Icons.drive_eta_rounded,
            label: 'Bằng lái xe',
            status: _licenseStatus,
            imageUrl: _licenseImageUrl,
            rejectionReason: _licenseRejectionReason,
            isUploading: _uploadingLicense,
            onTap: () => _showUploadSheet(
              title: 'Tải lên bằng lái xe',
              onCamera:  () => _pickAndUploadLicense(ImageSource.camera),
              onGallery: () => _pickAndUploadLicense(ImageSource.gallery),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.5),
      );
}

// ── Step status ───────────────────────────────────────────────────────────────

class _StepStatus extends StatelessWidget {
  final String label;
  final bool done;
  const _StepStatus({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.success : AppColors.textTertiary;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(
        done ? Icons.check_circle_rounded : Icons.circle_outlined,
        size: 14,
        color: color,
      ),
      const SizedBox(width: 5),
      Text(label,
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
    ]);
  }
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
      'approved' => ('Đã xác minh',    AppColors.success, Icons.verified_rounded),
      'rejected' => ('Bị từ chối',     AppColors.danger,  Icons.cancel_rounded),
      'pending'  => ('Đang xét duyệt', AppColors.warning, Icons.hourglass_top_rounded),
      _          => ('Chưa tải lên',   AppColors.textSecondary, Icons.upload_rounded),
    };
    // Chặn bấm lần nữa trong lúc đang upload — tránh gửi nhiều request cùng lúc.
    final bool canUpload = status != 'approved' && !isUploading;

    return GestureDetector(
      onTap: canUpload ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Thumbnail / icon area
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: imageUrl != null
                ? Image.network(imageUrl!,
                    height: 90, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _iconArea(icon, color))
                : _iconArea(icon, color),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.3)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(statusIcon, size: 10, color: color),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(statusLabel,
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: color)),
                  ),
                ]),
              ),
              if (status == 'rejected' && (rejectionReason?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 6),
                Text(
                  rejectionReason!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
              if (status != 'approved') ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: isUploading
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (isUploading)
                      const SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: Colors.white),
                      )
                    else
                      const Icon(Icons.upload_rounded, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      isUploading
                          ? 'Đang tải lên...'
                          : (status == null ? 'Tải lên' : 'Cập nhật'),
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ]),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _iconArea(IconData icon, Color color) => Container(
        height: 90, width: double.infinity,
        color: color.withValues(alpha: 0.08),
        child: Center(child: Icon(icon, size: 36, color: color.withValues(alpha: 0.5))),
      );
}

// ── Upload option ─────────────────────────────────────────────────────────────

class _UploadOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  const _UploadOption({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 14),
              Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
            ]),
          ),
        ),
      );
}
