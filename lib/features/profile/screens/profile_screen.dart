import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';
import 'change_password_screen.dart';
import 'legal_page_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallet/screens/debt_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _cityName;
  String? _photoUrl;
  double? _rating;
  bool _uploadingAvatar = false;
  bool _nameLocked      = false;
  bool _avatarLocked    = false;

  String? _licenseStatus;
  String? _licenseImageUrl;
  String? _cccdImageStatus;
  String? _cccdImageUrl;
  bool _deleteRequested = false;
  String _appVersion = '';

  int? _acceptanceRate;
  int? _completionRate;

  int?    _score;
  int?    _maxScore;
  String? _scoreLabel;
  String? _scoreTip;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _loadData();
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = info.version);
    });
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ref.read(apiClientProvider).get('/driver/profile'),
        ref.read(apiClientProvider).get('/driver/stats'),
        ref.read(apiClientProvider).get('/driver/score'),
      ]);

      final profileData =
          ((results[0].data['data'] ?? results[0].data) as Map<String, dynamic>)['user']
              as Map<String, dynamic>?;
      final statsData =
          (results[1].data['data'] ?? results[1].data) as Map<String, dynamic>?;
      final scoreData =
          (results[2].data['data'] ?? results[2].data) as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          if (profileData != null) {
            _cityName        = profileData['city_name'] as String?;
            _photoUrl        = profileData['profile_photo_url'] as String?;
            _rating          = profileData['rating'] == null
                ? null
                : double.tryParse(profileData['rating'].toString());
            _licenseStatus   = profileData['license_status'] as String?;
            _licenseImageUrl = profileData['license_image_url'] as String?;
            _cccdImageStatus = profileData['cccd_image_status'] as String?;
            _cccdImageUrl    = profileData['cccd_image_url'] as String?;
            _deleteRequested = profileData['delete_requested_at'] != null;
            _nameLocked      = profileData['name_locked'] as bool? ?? false;
            _avatarLocked    = profileData['avatar_locked'] as bool? ?? false;
          }
          if (statsData != null) {
            _acceptanceRate = statsData['acceptance_rate'] as int?;
            _completionRate = statsData['completion_rate'] as int?;
          }
          if (scoreData != null) {
            _score      = scoreData['score'] as int?;
            _maxScore   = scoreData['max_score'] as int?;
            _scoreLabel = scoreData['label'] as String?;
            final tips  = scoreData['tips'] as List?;
            _scoreTip   = tips?.isNotEmpty == true ? tips!.first as String? : null;
          }
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // ── Gradient header ──────────────────────────────────
                _ProfileHeader(
                  user:              user,
                  cityName:          _cityName,
                  photoUrl:          _photoUrl,
                  rating:            _rating,
                  isUploadingAvatar: _uploadingAvatar,
                  nameLocked:        _nameLocked,
                  avatarLocked:      _avatarLocked,
                  acceptanceRate:    _acceptanceRate,
                  completionRate:    _completionRate,
                  onAvatarTap: _avatarLocked ? null : _onAvatarTap,
                  onEditName:  _nameLocked   ? null : () => _showEditName(context, user?.name ?? ''),
                ),

                // ── Cards ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      // Score
                      if (_score != null) ...[
                        _ScoreCard(
                          score:    _score!,
                          maxScore: _maxScore ?? 150,
                          label:    _scoreLabel ?? '',
                          tip:      _scoreTip,
                          onTap:    () => context.push('/score'),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Hồ sơ tài xế
                      _SectionCard(
                        icon:  Icons.badge_outlined,
                        title: 'HỒ SƠ TÀI XẾ',
                        children: [
                          _DocTile(
                            icon:     Icons.badge_rounded,
                            label:    'Hình CCCD / CMND',
                            status:   _cccdImageStatus,
                            imageUrl: _cccdImageUrl,
                            onUpload: () => _showUploadCccd(context),
                          ),
                          const _CardDivider(),
                          _DocTile(
                            icon:     Icons.drive_eta_rounded,
                            label:    'Bằng lái xe',
                            status:   _licenseStatus,
                            imageUrl: _licenseImageUrl,
                            onUpload: () => _showUploadLicense(context),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Tài chính
                      _SectionCard(
                        icon:  Icons.account_balance_wallet_outlined,
                        title: 'TÀI CHÍNH',
                        children: [
                          _MenuTile(
                            icon:      Icons.account_balance_wallet_outlined,
                            iconColor: AppColors.danger,
                            label:     'Công nợ',
                            onTap:     () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const DebtScreen())),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Bảo mật
                      _SectionCard(
                        icon:  Icons.security_rounded,
                        title: 'BẢO MẬT',
                        children: [
                          _MenuTile(
                            icon:      Icons.lock_outline_rounded,
                            iconColor: AppColors.warning,
                            label:     'Đổi mật khẩu',
                            onTap:     () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Pháp lý
                      _SectionCard(
                        icon:  Icons.gavel_rounded,
                        title: 'PHÁP LÝ',
                        children: [
                          _MenuTile(
                            icon:      Icons.privacy_tip_outlined,
                            iconColor: AppColors.info,
                            label:     'Chính sách bảo mật',
                            onTap:     () => _showPage(context, 'privacy-policy', 'Chính sách bảo mật'),
                          ),
                          const _CardDivider(),
                          _MenuTile(
                            icon:      Icons.description_outlined,
                            iconColor: const Color(0xFF8B5CF6),
                            label:     'Điều khoản sử dụng',
                            onTap:     () => _showPage(context, 'terms-of-service', 'Điều khoản sử dụng'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Tài khoản
                      _SectionCard(
                        icon:  Icons.manage_accounts_rounded,
                        title: 'TÀI KHOẢN',
                        children: [
                          _MenuTile(
                            icon:       Icons.logout_rounded,
                            iconColor:  AppColors.danger,
                            label:      'Đăng xuất',
                            labelColor: AppColors.danger,
                            onTap:      () => _confirmLogout(context),
                          ),
                          const _CardDivider(),
                          _MenuTile(
                            icon: _deleteRequested
                                ? Icons.restore_rounded
                                : Icons.delete_forever_rounded,
                            iconColor: _deleteRequested
                                ? AppColors.textSecondary
                                : AppColors.danger,
                            label: _deleteRequested
                                ? 'Hủy yêu cầu xóa tài khoản'
                                : 'Yêu cầu xóa tài khoản',
                            labelColor: _deleteRequested
                                ? AppColors.textSecondary
                                : AppColors.danger,
                            onTap: () => _deleteRequested
                                ? _confirmCancelDelete(context)
                                : _confirmDeleteAccount(context),
                          ),
                        ],
                      ),

                    ],
                  ),
                ),

                // ── Version ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Center(
                    child: Text(
                      _appVersion.isNotEmpty
                          ? 'FlashShip Driver v$_appVersion'
                          : 'FlashShip Driver',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Avatar ─────────────────────────────────────────────────────────────────

  void _onAvatarTap() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Cập nhật ảnh đại diện',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          _SheetOption(
            icon: Icons.camera_alt_rounded,
            iconColor: AppColors.primary,
            label: 'Chụp ảnh',
            onTap: () { Navigator.pop(ctx); _pickAndUpload(ImageSource.camera); },
          ),
          const Divider(height: 1, indent: 56),
          _SheetOption(
            icon: Icons.photo_library_rounded,
            iconColor: AppColors.info,
            label: 'Chọn từ thư viện',
            onTap: () { Navigator.pop(ctx); _pickAndUpload(ImageSource.gallery); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    if (!Platform.isIOS && source == ImageSource.camera) {
      var status = await Permission.camera.status;
      if (!status.isGranted && !status.isLimited) {
        status = await Permission.camera.request();
      }
      if (status.isPermanentlyDenied) {
        if (mounted) _showPermissionDeniedDialog(context);
        return;
      }
      if (!status.isGranted && !status.isLimited) {
        if (mounted) _toast(context, 'Cần cấp quyền để thay đổi ảnh đại diện.');
        return;
      }
    }

    XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85,
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('permission') || msg.contains('denied') || msg.contains('access')) {
        if (mounted) _showPermissionDeniedDialog(context);
      } else {
        if (mounted) _toast(context, 'Không thể mở ảnh. Vui lòng thử lại.');
      }
      return;
    }
    if (file == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(file.path, filename: file.name),
      });
      final res = await ref
          .read(apiClientProvider)
          .postMultipart('/driver/profile/update', formData);
      final userData =
          ((res.data['data'] ?? res.data) as Map<String, dynamic>)['user']
              as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _photoUrl = userData?['profile_photo_url'] as String?;
          _uploadingAvatar = false;
        });
        _toast(context, 'Cập nhật ảnh thành công', success: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        _toast(context, 'Cập nhật ảnh thất bại');
      }
    }
  }

  void _showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cần cấp quyền'),
        content: const Text(
            'Quyền truy cập bị từ chối vĩnh viễn.\n'
            'Vui lòng vào Cài đặt để cấp quyền cho ứng dụng.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); openAppSettings(); },
            child: const Text('Mở Cài đặt'),
          ),
        ],
      ),
    );
  }

  // ── Upload docs ────────────────────────────────────────────────────────────

  void _showUploadSheet({
    required BuildContext context,
    required String title,
    required VoidCallback onCamera,
    required VoidCallback onGallery,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Ảnh rõ nét, đủ ánh sáng, không bị mờ',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          _SheetOption(
            icon: Icons.camera_alt_rounded, iconColor: AppColors.primary,
            label: 'Chụp ảnh',
            onTap: () { Navigator.pop(ctx); onCamera(); },
          ),
          const Divider(height: 1, indent: 56),
          _SheetOption(
            icon: Icons.photo_library_rounded, iconColor: AppColors.info,
            label: 'Chọn từ thư viện',
            onTap: () { Navigator.pop(ctx); onGallery(); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showUploadLicense(BuildContext context) {
    _showUploadSheet(
      context: context, title: 'Tải lên bằng lái xe',
      onCamera: () => _pickAndUploadLicense(ImageSource.camera),
      onGallery: () => _pickAndUploadLicense(ImageSource.gallery),
    );
  }

  Future<void> _pickAndUploadLicense(ImageSource source) async {
    XFile? file;
    try {
      file = await ImagePicker().pickImage(
          source: source, maxWidth: 1600, maxHeight: 1200, imageQuality: 90);
    } catch (_) { return; }
    if (file == null) return;
    try {
      final formData = FormData.fromMap(
          {'image': await MultipartFile.fromFile(file.path, filename: file.name)});
      final res = await ref.read(apiClientProvider).postMultipart('/driver/profile/license', formData);
      final imageUrl = res.data['image_url'] as String?;
      if (mounted) {
        setState(() { _licenseStatus = 'pending'; _licenseImageUrl = imageUrl; });
        _toast(context, 'Tải lên thành công, đang chờ xét duyệt', success: true);
      }
    } catch (_) {
      if (mounted) _toast(context, 'Tải lên thất bại');
    }
  }

  void _showUploadCccd(BuildContext context) {
    _showUploadSheet(
      context: context, title: 'Tải lên hình CCCD / CMND',
      onCamera: () => _pickAndUploadCccd(ImageSource.camera),
      onGallery: () => _pickAndUploadCccd(ImageSource.gallery),
    );
  }

  Future<void> _pickAndUploadCccd(ImageSource source) async {
    XFile? file;
    try {
      file = await ImagePicker().pickImage(
          source: source, maxWidth: 1600, maxHeight: 1200, imageQuality: 90);
    } catch (_) { return; }
    if (file == null) return;
    try {
      final formData = FormData.fromMap(
          {'image': await MultipartFile.fromFile(file.path, filename: file.name)});
      await ref.read(apiClientProvider).postMultipart('/driver/profile/cccd-image', formData);
      if (mounted) {
        setState(() => _cccdImageStatus = 'pending');
        _toast(context, 'Tải lên thành công, đang chờ xét duyệt', success: true);
      }
    } catch (_) {
      if (mounted) _toast(context, 'Tải lên thất bại');
    }
  }

  // ── Edit name ──────────────────────────────────────────────────────────────

  void _showEditName(BuildContext context, String current) {
    final ctrl   = TextEditingController(text: current);
    bool  saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Chỉnh sửa tên',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Tên chỉ được thay đổi một lần.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              textCapitalization: TextCapitalization.words,
              autofocus: true,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Họ và tên',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 50,
              child: FilledButton(
                onPressed: saving ? null : () async {
                  final name = ctrl.text.trim();
                  if (name.isEmpty) return;
                  setSheet(() => saving = true);
                  try {
                    await ref.read(apiClientProvider).post('/driver/profile/update', data: {'name': name});
                    await ref.read(authProvider.notifier).refreshName(name);
                    setState(() => _nameLocked = true);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      _toast(context, 'Cập nhật thành công', success: true);
                    }
                  } catch (_) {
                    setSheet(() => saving = false);
                    if (ctx.mounted) _toast(ctx, 'Cập nhật thất bại');
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Lưu',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Legal ──────────────────────────────────────────────────────────────────

  void _showPage(BuildContext context, String slug, String title) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LegalPageScreen(slug: slug, title: title),
    ));
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Bạn có muốn đăng xuất khỏi tài khoản không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Đăng xuất', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  // ── Delete account ─────────────────────────────────────────────────────────

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa tài khoản', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Tài khoản và toàn bộ dữ liệu của bạn sẽ bị xóa vĩnh viễn sau khi xác nhận.\n\n'
          'Hành động này không thể hoàn tác. Bạn sẽ bị đăng xuất ngay lập tức.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(apiClientProvider).post('/driver/delete-account/request');
                if (mounted) setState(() => _deleteRequested = true);
              } catch (_) {}
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Xác nhận', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _confirmCancelDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hủy yêu cầu xóa', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Bạn muốn hủy yêu cầu xóa tài khoản và tiếp tục sử dụng?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Để sau')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref.read(apiClientProvider).post('/driver/delete-account/cancel');
                if (!mounted) return;
                setState(() => _deleteRequested = false);
                messenger.showSnackBar(const SnackBar(
                  content: Text('Đã hủy yêu cầu xóa tài khoản'),
                  backgroundColor: AppColors.success,
                ));
              } catch (_) {
                if (!mounted) return;
                messenger.showSnackBar(const SnackBar(
                  content: Text('Không thể hủy. Vui lòng thử lại.'),
                  backgroundColor: AppColors.danger,
                ));
              }
            },
            child: const Text('Hủy yêu cầu xóa', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _toast(BuildContext ctx, String msg, {bool success = false}) {
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.success : AppColors.danger,
    ));
  }
}

// ── Profile header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final dynamic user;
  final String? cityName;
  final String? photoUrl;
  final double? rating;
  final bool isUploadingAvatar;
  final bool nameLocked;
  final bool avatarLocked;
  final int? acceptanceRate;
  final int? completionRate;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onEditName;

  const _ProfileHeader({
    required this.user,
    required this.cityName,
    required this.photoUrl,
    required this.rating,
    this.isUploadingAvatar = false,
    this.nameLocked = false,
    this.avatarLocked = false,
    this.acceptanceRate,
    this.completionRate,
    this.onAvatarTap,
    this.onEditName,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final hasStats = acceptanceRate != null || completionRate != null;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEF7C1A), AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Avatar + Info ──────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 16, 20, hasStats ? 16 : 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                // Avatar
                GestureDetector(
                  onTap: onAvatarTap,
                  child: Stack(children: [
                    Container(
                      width: 76, height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                      child: ClipOval(
                        child: isUploadingAvatar
                            ? Container(
                                color: Colors.white.withValues(alpha: 0.2),
                                child: Center(
                                  child: SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  ),
                                ),
                              )
                            : (photoUrl != null
                                ? Image.network(photoUrl!, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _AvatarInitials(user: user))
                                : _AvatarInitials(user: user)),
                      ),
                    ),
                    // Online dot
                    Positioned(
                      bottom: 3, right: 3,
                      child: Container(
                        width: 14, height: 14,
                        decoration: BoxDecoration(
                          color: user?.isOnline == true
                              ? AppColors.success
                              : Colors.grey.shade400,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                    // Camera badge
                    if (!isUploadingAvatar && !avatarLocked)
                      Positioned(
                        bottom: 0, left: 0,
                        child: Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 12, color: AppColors.primary),
                        ),
                      ),
                  ]),
                ),

                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Name row
                      Row(children: [
                        Expanded(
                          child: Text(
                            user?.name ?? 'Tài xế',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        if (!nameLocked)
                          GestureDetector(
                            onTap: onEditName,
                            child: Container(
                              width: 30, height: 30,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.edit_rounded,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                      ]),

                      const SizedBox(height: 4),

                      // Phone
                      Text(
                        user?.phone ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),

                      // City
                      if (cityName != null) ...[
                        const SizedBox(height: 3),
                        Row(children: [
                          Icon(Icons.location_on_rounded,
                              size: 12, color: Colors.white.withValues(alpha: 0.75)),
                          const SizedBox(width: 3),
                          Text(cityName!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.75))),
                        ]),
                      ],

                      // Rating
                      if (rating != null) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Stats row ──────────────────────────────────────────────
          if (hasStats)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  if (acceptanceRate != null) ...[
                    _StatChip(
                      icon: Icons.check_circle_outline_rounded,
                      value: '$acceptanceRate%',
                      label: 'Nhận đơn',
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (completionRate != null)
                    _StatChip(
                      icon: Icons.done_all_rounded,
                      value: '$completionRate%',
                      label: 'Hoàn thành',
                    ),
                ],
              ),
            ),

          // ── Curved bottom ──────────────────────────────────────────
          Container(
            height: 20,
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatChip({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
              Text(label,
                  style: TextStyle(
                      fontSize: 10, color: Colors.white.withValues(alpha: 0.78))),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Score card ────────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final int score;
  final int maxScore;
  final String label;
  final String? tip;
  final VoidCallback onTap;

  const _ScoreCard({
    required this.score,
    required this.maxScore,
    required this.label,
    this.tip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (score / maxScore).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppColors.cardShadow,
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [

            // Mini ring
            SizedBox(
              width: 64, height: 64,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 6,
                    color: AppColors.primary.withValues(alpha: 0.12),
                  ),
                ),
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '$score',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ]),
            ),

            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text(
                      'ĐIỂM TÍCH LŨY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$score / $maxScore',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textTertiary),
                    ),
                  ]),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (tip != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      tip!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.icon, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
            child: Row(children: [
              Icon(icon, size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ]),
          ),
          ...children,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        indent: 54,
        endIndent: 16,
        color: AppColors.divider,
      );
}

// ── Menu tile ─────────────────────────────────────────────────────────────────

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.card)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: labelColor ?? AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: labelColor?.withValues(alpha: 0.6) ?? AppColors.textTertiary,
            ),
          ]),
        ),
      );
}

// ── Document tile ─────────────────────────────────────────────────────────────

class _DocTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? status;
  final String? imageUrl;
  final VoidCallback? onUpload;

  const _DocTile({
    required this.icon,
    required this.label,
    this.status,
    this.imageUrl,
    this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final (statusLabel, color, statusIcon) = switch (status) {
      'approved' => ('Đã xác minh', AppColors.success, Icons.verified_rounded),
      'rejected' => ('Bị từ chối',  AppColors.danger,  Icons.cancel_rounded),
      'pending'  => ('Đang xét duyệt', AppColors.warning, Icons.hourglass_top_rounded),
      _          => ('Chưa tải lên', AppColors.textSecondary, Icons.upload_rounded),
    };

    return InkWell(
      onTap: status != 'approved' ? onUpload : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imageUrl != null
                ? Image.network(imageUrl!,
                    width: 42, height: 36, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _docIconBox(icon, color))
                : _docIconBox(icon, color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Row(children: [
                  Icon(statusIcon, size: 11, color: color),
                  const SizedBox(width: 4),
                  Text(statusLabel,
                      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
                ]),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status == 'approved' ? 'Xem' : 'Cập nhật',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: status == 'approved' ? AppColors.success : color),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _docIconBox(IconData icon, Color color) => Container(
        width: 42, height: 36,
        color: color.withValues(alpha: 0.10),
        child: Icon(icon, size: 18, color: color),
      );
}

// ── Avatar initials ───────────────────────────────────────────────────────────

class _AvatarInitials extends StatelessWidget {
  final dynamic user;
  const _AvatarInitials({required this.user});

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white.withValues(alpha: 0.3),
        child: Center(
          child: Text(
            user?.initials ?? 'D',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
}

// ── Sheet option ──────────────────────────────────────────────────────────────

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  const _SheetOption({
    required this.icon, required this.iconColor,
    required this.label, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          ]),
        ),
      );
}
