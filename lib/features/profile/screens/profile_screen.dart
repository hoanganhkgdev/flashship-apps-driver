import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/avatar_picker_sheet.dart';
import '../widgets/edit_name_sheet.dart';
import '../widgets/kyc_summary_card.dart';
import '../widgets/profile_finance_card.dart';
import '../widgets/profile_header.dart';
import '../widgets/settings_section.dart';
import '../widgets/work_schedule_card.dart';
import 'change_password_screen.dart';
import 'legal_page_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shifts/providers/shift_provider.dart';
import '../../home/widgets/bottom_nav.dart';
import '../../wallet/models/wallet_model.dart';
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
  bool _nameLocked = false;
  String? _nameLockedReason;
  bool _avatarLocked = false;
  DateTime? _avatarNextUpdate;

  String? _licenseStatus;
  String? _cccdImageStatus;
  bool _deleteRequested = false;
  bool _profileLoaded = false;

  int? _balance;
  String? _bankName;
  String? _bankAccount;
  String _appVersion = '';

  int? _acceptanceRate;
  int? _completionRate;

  List<DriverDebt> _debts = const [];

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
    // Chạy độc lập — 1 API lỗi (vd /driver/stats timeout) không được làm
    // trắng cả trang, kể cả khi profile đã lấy được bình thường.
    Map<String, dynamic>? profileData;
    Map<String, dynamic>? statsData;
    Map<String, dynamic>? dashboardData;
    List<dynamic>? debtsRaw;

    await Future.wait([
      ref.read(apiClientProvider).get('/driver/profile').then((r) {
        profileData = ((r.data['data'] ?? r.data)
            as Map<String, dynamic>)['user'] as Map<String, dynamic>?;
      }).catchError((_) {}),
      ref.read(apiClientProvider).get('/driver/stats').then((r) {
        statsData = (r.data['data'] ?? r.data) as Map<String, dynamic>?;
      }).catchError((_) {}),
      ref.read(apiClientProvider).get('/orders/dashboard').then((r) {
        dashboardData = (r.data['data'] ?? r.data) as Map<String, dynamic>?;
      }).catchError((_) {}),
      // unpaid=1: mọi khoản chưa trả (khoản quá hạn cũ không rơi khỏi 20 khoản
      // mới nhất như khi gọi /debts thường).
      ref
          .read(apiClientProvider)
          .get('/debts', params: {'unpaid': 1}).then((r) {
        final d = r.data['data'] ?? r.data;
        debtsRaw = d is List ? d : <dynamic>[];
      }).catchError((_) {}),
    ]);

    if (mounted) {
      setState(() {
        final p = profileData;
        if (p != null) {
          _profileLoaded = true;
          _cityName = p['city_name'] as String?;
          _photoUrl = p['profile_photo_url'] as String?;
          _licenseStatus = p['license_status'] as String?;
          _cccdImageStatus = p['cccd_image_status'] as String?;
          _balance = (p['balance'] as num?)?.toInt();
          _bankName = p['bank_name'] as String?;
          _bankAccount = p['bank_account'] as String?;
          _deleteRequested = p['delete_requested_at'] != null;
          _nameLocked = p['name_locked'] as bool? ?? false;
          _nameLockedReason = p['name_locked_reason'] as String?;
          _avatarLocked = p['avatar_locked'] as bool? ?? false;
          final nextRaw = p['avatar_next_update_at'] as String?;
          _avatarNextUpdate =
              nextRaw != null ? DateTime.tryParse(nextRaw) : null;
        }
        final s = statsData;
        if (s != null) {
          _acceptanceRate = s['acceptance_rate'] as int?;
          _completionRate = s['completion_rate'] as int?;
        }
        final dashboard = dashboardData;
        if (dashboard != null) {
          _rating = (dashboard['rating'] as num?)?.toDouble();
        }
        if (debtsRaw != null) {
          _debts = debtsRaw!
              .map((e) => DriverDebt.fromJson(e as Map<String, dynamic>))
              .where((d) => !d.isPaid)
              .toList();
        }
      });
    }
  }

  String _currentShiftNames() {
    final shiftState = ref.watch(shiftProvider);
    return shiftState.shifts
        .where((s) => shiftState.currentShiftIds.contains(s.id))
        .map((s) => s.name)
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final verified = KycSummaryCard.isVerified(_cccdImageStatus);

    Future<void> openKyc() async {
      await context.push('/kyc');
      _loadData();
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadData,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // ── Ảnh, tên, xác minh, chỉ số ─────────────────────────────
              ProfileHeader(
                user: user,
                photoUrl: _photoUrl,
                uploadingAvatar: _uploadingAvatar,
                nameLocked: _nameLocked,
                nameLockedReason: _nameLockedReason,
                cityName: _cityName,
                verified: verified,
                acceptanceRate: _acceptanceRate,
                completionRate: _completionRate,
                rating: _rating,
                onAvatarTap: _onAvatarTap,
                onEditName: (name) => _showEditName(context, name),
                onVerifyTap: openKyc,
              ),

              // ── Nhắc xác minh (chỉ khi CCCD chưa duyệt) ─────────────────
              // _cccdImageStatus null cả khi chưa tải xong profile — chờ có
              // dữ liệu rồi mới nhắc, tránh băng nhắc nháy lên rồi biến mất.
              if (!verified && _profileLoaded) ...[
                const SizedBox(height: AppSpacing.lg),
                KycSummaryCard(
                  cccdStatus: _cccdImageStatus,
                  licenseStatus: _licenseStatus,
                  onTap: openKyc,
                ),
              ],

              if (_deleteRequested) ...[
                const SizedBox(height: AppSpacing.lg),
                _DeletePendingBanner(
                    onCancel: () => _confirmCancelDelete(context)),
              ],

              const SizedBox(height: AppSpacing.xl),

              // ── Ví & thanh toán ────────────────────────────────────────
              ProfileFinanceCard(
                balance: _balance ?? 0,
                debtAmount: _debts.fold<int>(0, (sum, d) => sum + d.remaining),
                hasOverdueDebt: _debts.any((d) => d.isOverdue),
                bankName: _bankName,
                bankAccount: _bankAccount,
                onWalletTap: () => context.push('/wallet'),
                onDebtTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DebtScreen()),
                ),
                onBankTap: () => context.push('/bank-account'),
                onReferralTap: () => context.push('/referral'),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Công việc ──────────────────────────────────────────────
              WorkScheduleCard(
                currentShiftNames: _currentShiftNames(),
                onShiftTap: () => context.push('/shifts'),
                onLeaveTap: () => context.push('/leave-request'),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Cài đặt & pháp lý ──────────────────────────────────────
              SettingsSection(
                header: 'Cài đặt',
                children: [
                  SettingsRow(
                    icon: Icons.verified_user_outlined,
                    iconBg: verified
                        ? AppColors.successSoft
                        : AppColors.primarySoft,
                    iconColor: verified ? AppColors.success : AppBrand.ink,
                    label: 'Hồ sơ & giấy tờ',
                    subtitle: 'CCCD, bằng lái ô tô',
                    onTap: openKyc,
                  ),
                  SettingsRow(
                    icon: Icons.lock_outline_rounded,
                    iconBg: AppColors.surfaceAlt,
                    iconColor: AppColors.textSecondary,
                    label: 'Đổi mật khẩu',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen())),
                  ),
                  SettingsRow(
                    icon: Icons.shield_outlined,
                    iconBg: AppColors.surfaceAlt,
                    iconColor: AppColors.textSecondary,
                    label: 'Chính sách bảo mật',
                    onTap: () => _showPage(
                        context, 'privacy-policy', 'Chính sách bảo mật'),
                  ),
                  SettingsRow(
                    icon: Icons.description_outlined,
                    iconBg: AppColors.surfaceAlt,
                    iconColor: AppColors.textSecondary,
                    label: 'Điều khoản sử dụng',
                    onTap: () => _showPage(
                        context, 'terms-of-service', 'Điều khoản sử dụng'),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Đăng xuất / xoá tài khoản / phiên bản ──────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: SizedBox(
                  height: AppSize.buttonHeight,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmLogout(context),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text('Đăng xuất'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppBrand.ink,
                      backgroundColor: AppColors.primarySoft,
                      side: const BorderSide(
                          color: AppColors.primary, width: 1.25),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md)),
                      textStyle: AppTextStyles.bodyStrong
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              if (!_deleteRequested)
                Center(
                  child: TextButton(
                    onPressed: () => _confirmDeleteAccount(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textTertiary,
                      minimumSize: const Size(48, AppSize.minTouchTarget),
                    ),
                    child: const Text('Yêu cầu xóa tài khoản'),
                  ),
                ),
              Padding(
                padding:
                    EdgeInsets.only(top: _deleteRequested ? AppSpacing.lg : 0),
                child: Text(
                  'FLASH SHIP Tài xế · phiên bản '
                  '${_appVersion.isEmpty ? '...' : _appVersion}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textTertiary),
                ),
              ),

              // Chừa chỗ cho thanh bottom nav nổi (extendBody: true ở
              // HomeScreen) — không thì phần cuối bị nav che mất.
              SizedBox(
                  height: BottomNav.reservedHeight(context) + AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  // ── Avatar ─────────────────────────────────────────────────────────────────

  void _onAvatarTap() {
    final user = ref.read(authProvider).user;

    AvatarPickerSheet.show(
      context,
      user: user,
      photoUrl: _photoUrl,
      avatarLocked: _avatarLocked,
      avatarNextUpdate: _avatarNextUpdate,
      onCamera: () => _pickAndUpload(ImageSource.camera),
      onGallery: () => _pickAndUpload(ImageSource.gallery),
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
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('permission') ||
          msg.contains('denied') ||
          msg.contains('access')) {
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
      final userData = ((res.data['data'] ?? res.data)
          as Map<String, dynamic>)['user'] as Map<String, dynamic>?;
      if (mounted) {
        // updateProfile() không trả avatar_locked/avatar_next_update_at (chỉ
        // GET /driver/profile mới tính) — nhưng vừa upload thành công nghĩa
        // là server vừa set avatar_updated_at=now(), nên tự tính khóa 30 ngày
        // ở đây, không thì client vẫn tưởng đổi được ảnh tiếp cho tới lần
        // pull-to-refresh kế tiếp.
        setState(() {
          _photoUrl = userData?['profile_photo_url'] as String?;
          _avatarLocked = true;
          _avatarNextUpdate = DateTime.now().add(const Duration(days: 30));
          _uploadingAvatar = false;
        });
        // Đồng bộ vào authProvider — nếu không, DashboardHeader ở Home vẫn
        // đọc ảnh cũ (null) từ state cũ cho tới khi app restart.
        unawaited(ref.read(authProvider.notifier).refreshUser());
        _toast(context, 'Cập nhật ảnh thành công', success: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        String msg = 'Cập nhật ảnh thất bại';
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map && data['message'] is String) {
            msg = data['message'] as String;
          }
        }
        _toast(context, msg);
      }
    }
  }

  void _showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cần cấp quyền'),
        content: const Text('Quyền truy cập bị từ chối vĩnh viễn.\n'
            'Vui lòng vào Cài đặt để cấp quyền cho ứng dụng.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Mở Cài đặt'),
          ),
        ],
      ),
    );
  }

  // ── Edit name ──────────────────────────────────────────────────────────────

  void _showEditName(BuildContext context, String current) {
    EditNameSheet.show(
      context,
      currentName: current,
      onSave: (name) async {
        await ref
            .read(apiClientProvider)
            .post('/driver/profile/update', data: {'name': name});
        await ref.read(authProvider.notifier).refreshName(name);
        setState(() {
          _nameLocked = true;
          _nameLockedReason = 'Tên chỉ được thay đổi một lần.';
        });
      },
      onSaved: () => _toast(context, 'Cập nhật thành công', success: true),
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
        title: const Text('Đăng xuất',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Bạn có muốn đăng xuất khỏi tài khoản không?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Đăng xuất',
                style: TextStyle(color: AppColors.danger)),
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
        title: const Text('Xóa tài khoản',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Yêu cầu xóa chỉ được tiếp nhận khi bạn không còn đơn đang giao, công nợ, số dư ví hoặc lệnh rút tiền chờ xử lý.\n\n'
          'Trong thời gian chờ xử lý, bạn có thể hủy yêu cầu tại trang này.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref
                    .read(apiClientProvider)
                    .post('/driver/delete-account/request');
                if (mounted) setState(() => _deleteRequested = true);
                await ref.read(authProvider.notifier).refreshUser();
              } catch (_) {
                // Request thất bại thì không logout — tài xế tưởng đã gửi yêu
                // cầu xóa nhưng thực ra chưa, để họ biết mà thử lại.
                messenger.showSnackBar(const SnackBar(
                  content: Text(
                      'Không thể gửi yêu cầu xóa tài khoản. Vui lòng thử lại.'),
                  backgroundColor: AppColors.danger,
                ));
              }
            },
            child: const Text('Xác nhận',
                style: TextStyle(color: AppColors.danger)),
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
        title: const Text('Hủy yêu cầu xóa',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'Bạn muốn hủy yêu cầu xóa tài khoản và tiếp tục sử dụng?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Để sau')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref
                    .read(apiClientProvider)
                    .post('/driver/delete-account/cancel');
                await ref.read(authProvider.notifier).refreshUser();
                // Gửi yêu cầu xoá đã xoá mã nhận thông báo trên server: gửi
                // lại ngay, không thì không nhận thông báo tới khi mở lại app.
                unawaited(NotificationService.resendToken());
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
            child: const Text('Hủy yêu cầu xóa',
                style: TextStyle(color: AppColors.primary)),
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

/// Đang có yêu cầu xoá tài khoản chờ xử lý — hiện rõ ở đầu trang kèm nút
/// huỷ, thay vì chỉ là một dòng chữ xám cuối danh sách.
class _DeletePendingBanner extends StatelessWidget {
  final VoidCallback onCancel;
  const _DeletePendingBanner({required this.onCancel});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(children: [
          const Icon(Icons.delete_outline_rounded,
              color: AppColors.danger, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đang chờ xóa tài khoản',
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Bạn vẫn có thể hủy yêu cầu trước khi được xử lý.',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Hủy yêu cầu'),
          ),
        ]),
      );
}
