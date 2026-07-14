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
  bool      _uploadingAvatar   = false;
  bool      _nameLocked        = false;
  bool      _avatarLocked      = false;
  DateTime? _avatarNextUpdate;

  String? _licenseStatus;
  String? _cccdImageStatus;
  bool _deleteRequested = false;

  int?    _balance;
  String? _bankName;
  String? _bankAccount;
  String _appVersion = '';

  int? _acceptanceRate;
  int? _completionRate;

  int?    _score;
  int?    _maxScore;
  String? _scoreLabel;
  int?    _scoreBonusAt;
  int?    _scorePenaltyAt;
  int?    _scoreBonusAmt;
  int?    _scorePenaltyAmt;
  int?    _scoreStreak;

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
    // trắng cả trang, kể cả khi profile/score đã lấy được bình thường.
    Map<String, dynamic>? profileData;
    Map<String, dynamic>? statsData;
    Map<String, dynamic>? scoreData;

    await Future.wait([
      ref.read(apiClientProvider).get('/driver/profile').then((r) {
        profileData = ((r.data['data'] ?? r.data) as Map<String, dynamic>)['user']
            as Map<String, dynamic>?;
      }).catchError((_) {}),
      ref.read(apiClientProvider).get('/driver/stats').then((r) {
        statsData = (r.data['data'] ?? r.data) as Map<String, dynamic>?;
      }).catchError((_) {}),
      ref.read(apiClientProvider).get('/driver/score').then((r) {
        scoreData = (r.data['data'] ?? r.data) as Map<String, dynamic>?;
      }).catchError((_) {}),
    ]);

    if (mounted) {
      setState(() {
        final p = profileData;
        if (p != null) {
          _cityName        = p['city_name'] as String?;
          _photoUrl        = p['profile_photo_url'] as String?;
          _rating          = p['rating'] == null
              ? null
              : double.tryParse(p['rating'].toString());
          _licenseStatus   = p['license_status'] as String?;
          _cccdImageStatus = p['cccd_image_status'] as String?;
          _balance         = (p['balance'] as num?)?.toInt();
          _bankName        = p['bank_name'] as String?;
          _bankAccount     = p['bank_account'] as String?;
          _deleteRequested = p['delete_requested_at'] != null;
          _nameLocked      = p['name_locked'] as bool? ?? false;
          _avatarLocked    = p['avatar_locked'] as bool? ?? false;
          final nextRaw    = p['avatar_next_update_at'] as String?;
          _avatarNextUpdate = nextRaw != null ? DateTime.tryParse(nextRaw) : null;
        }
        final s = statsData;
        if (s != null) {
          _acceptanceRate = s['acceptance_rate'] as int?;
          _completionRate = s['completion_rate'] as int?;
        }
        final sc = scoreData;
        if (sc != null) {
          _score        = sc['score']     as int?;
          _maxScore     = sc['max_score'] as int?;
          _scoreLabel   = sc['label']     as String?;
          final week    = sc['week']      as Map<String, dynamic>?;
          _scoreBonusAt   = (week?['bonus_at']   as num?)?.toInt();
          _scorePenaltyAt = (week?['penalty_at'] as num?)?.toInt();
          _scoreBonusAmt  = (week?['bonus_amount']   as num?)?.toInt();
          _scorePenaltyAmt= (week?['penalty_amount'] as num?)?.toInt();
          final streak  = sc['streak']    as Map<String, dynamic>?;
          _scoreStreak  = (streak?['count']      as num?)?.toInt();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final hasStats = _acceptanceRate != null || _completionRate != null || _rating != null;

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
          child: ListView(
            padding: EdgeInsets.zero,
            children: [

              // ── Header + floating stats card ──────────────────────────
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Gradient bg
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFCC5A08), Color(0xFFE8720C), Color(0xFFF59E30)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.of(context).padding.top + 20,
                      20,
                      hasStats ? 80 : 28,
                    ),
                    child: Column(
                      children: [
                        // Avatar
                        GestureDetector(
                          onTap: _onAvatarTap,
                          child: Stack(children: [
                            Container(
                              width: 86, height: 86,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: ClipOval(
                                child: _uploadingAvatar
                                    ? Container(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 22, height: 22,
                                            child: CircularProgressIndicator(
                                                color: Colors.white, strokeWidth: 2),
                                          ),
                                        ),
                                      )
                                    : (_photoUrl != null
                                        ? Image.network(_photoUrl!, fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _AvatarInitials(user: user))
                                        : _AvatarInitials(user: user)),
                              ),
                            ),
                            // Online dot
                            Positioned(
                              bottom: 4, right: 4,
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
                            if (!_uploadingAvatar)
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  width: 24, height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppColors.primary.withValues(alpha: 0.3),
                                        width: 1.5),
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded,
                                      size: 13, color: AppColors.primary),
                                ),
                              ),
                          ]),
                        ),

                        const SizedBox(height: 12),

                        // Name
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              user?.name ?? 'Tài xế',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (!_nameLocked) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _showEditName(context, user?.name ?? ''),
                                child: Container(
                                  width: 26, height: 26,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: const Icon(Icons.edit_rounded,
                                      size: 13, color: Colors.white),
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 4),
                        Text(
                          user?.phone ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                        ),

                        if (_cityName != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_on_rounded,
                                  size: 12, color: Colors.white.withValues(alpha: 0.75)),
                              const SizedBox(width: 3),
                              Text(_cityName!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.75))),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Floating stats card
                  if (hasStats)
                    Positioned(
                      left: 16, right: 16, bottom: -44,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.07),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            if (_acceptanceRate != null) ...[
                              _StatItem(
                                value: '$_acceptanceRate%',
                                label: 'Nhận đơn',
                                icon: Icons.check_circle_outline_rounded,
                                color: AppColors.primary,
                              ),
                              _StatDivider(),
                            ],
                            if (_completionRate != null) ...[
                              _StatItem(
                                value: '$_completionRate%',
                                label: 'Hoàn thành',
                                icon: Icons.done_all_rounded,
                                color: AppColors.success,
                              ),
                              _StatDivider(),
                            ],
                            _StatItem(
                              value: _rating != null
                                  ? _rating!.toStringAsFixed(1)
                                  : '—',
                              label: 'Đánh giá',
                              icon: Icons.star_rounded,
                              color: const Color(0xFFF59E0B),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              SizedBox(height: hasStats ? 56 : 0),

              const SizedBox(height: 12),

              // ── Score card ────────────────────────────────────────────
              if (_score != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ScoreCard(
                    score:      _score!,
                    maxScore:   _maxScore ?? 150,
                    label:      _scoreLabel ?? '',
                    bonusAt:    _scoreBonusAt,
                    penaltyAt:  _scorePenaltyAt,
                    bonusAmt:   _scoreBonusAmt,
                    penaltyAmt: _scorePenaltyAmt,
                    streak:     _scoreStreak,
                    onTap:      () => context.push('/score'),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Hồ sơ tài xế ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _KycSummaryCard(
                  cccdStatus:    _cccdImageStatus,
                  licenseStatus: _licenseStatus,
                  onTap: () async {
                    await context.push('/kyc');
                    _loadData();
                  },
                ),
              ),

              const SizedBox(height: 12),

              // ── Tài chính ────────────────────────────────────────────
              _SettingsSection(
                header: 'Tài chính',
                children: [
                  // Balance row
                  _BalanceRow(
                    balance: _balance,
                    onTap:   () => context.push('/wallet'),
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF5F5F5)),
                  // Công nợ
                  _SettingsRow(
                    icon:      Icons.warning_amber_rounded,
                    iconBg:    AppColors.danger.withValues(alpha: 0.12),
                    iconColor: AppColors.danger,
                    label:     'Công nợ',
                    onTap:     () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DebtScreen())),
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF5F5F5)),
                  // Ngân hàng liên kết
                  _SettingsRow(
                    icon:      Icons.account_balance_rounded,
                    iconBg:    const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                    iconColor: const Color(0xFF0EA5E9),
                    label:     'Tài khoản ngân hàng',
                    trailing: _bankName != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_bankName!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary)),
                              if (_bankAccount != null)
                                Text(
                                  '••••${_bankAccount!.length > 4 ? _bankAccount!.substring(_bankAccount!.length - 4) : _bankAccount!}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                            ],
                          )
                        : Text('Chưa liên kết',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.danger.withValues(alpha: 0.8))),
                    onTap: () => context.push('/bank-account'),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Bảo mật ──────────────────────────────────────────────
              _SettingsSection(
                header: 'Bảo mật',
                children: [
                  _SettingsRow(
                    icon:      Icons.lock_outline_rounded,
                    iconBg:    const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    iconColor: const Color(0xFF8B5CF6),
                    label:     'Đổi mật khẩu',
                    onTap:     () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Pháp lý ──────────────────────────────────────────────
              _SettingsSection(
                header: 'Pháp lý',
                children: [
                  _SettingsRow(
                    icon:      Icons.shield_outlined,
                    iconBg:    const Color(0xFF6366F1).withValues(alpha: 0.12),
                    iconColor: const Color(0xFF6366F1),
                    label:     'Chính sách bảo mật',
                    onTap:     () => _showPage(context, 'privacy-policy', 'Chính sách bảo mật'),
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF5F5F5)),
                  _SettingsRow(
                    icon:      Icons.description_outlined,
                    iconBg:    const Color(0xFF64748B).withValues(alpha: 0.12),
                    iconColor: const Color(0xFF64748B),
                    label:     'Điều khoản sử dụng',
                    onTap:     () => _showPage(context, 'terms-of-service', 'Điều khoản sử dụng'),
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF5F5F5)),
                  _SettingsRow(
                    icon:      Icons.info_outline_rounded,
                    iconBg:    const Color(0xFF94A3B8).withValues(alpha: 0.12),
                    iconColor: const Color(0xFF94A3B8),
                    label:     'Phiên bản',
                    trailing:  Text(
                      _appVersion.isEmpty ? '...' : _appVersion,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                    onTap: null,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Tài khoản ────────────────────────────────────────────
              _SettingsSection(
                children: [
                  _SettingsRow(
                    icon:       Icons.logout_rounded,
                    iconBg:     AppColors.danger.withValues(alpha: 0.12),
                    iconColor:  AppColors.danger,
                    label:      'Đăng xuất',
                    labelColor: AppColors.danger,
                    showChevron: false,
                    onTap:      () => _confirmLogout(context),
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF5F5F5)),
                  _SettingsRow(
                    icon: _deleteRequested
                        ? Icons.restore_rounded
                        : Icons.delete_forever_rounded,
                    iconBg:    AppColors.danger.withValues(alpha: 0.12),
                    iconColor: _deleteRequested
                        ? AppColors.textSecondary
                        : AppColors.danger,
                    label: _deleteRequested
                        ? 'Hủy yêu cầu xóa tài khoản'
                        : 'Yêu cầu xóa tài khoản',
                    labelColor: _deleteRequested
                        ? AppColors.textSecondary
                        : AppColors.danger,
                    showChevron: false,
                    onTap: () => _deleteRequested
                        ? _confirmCancelDelete(context)
                        : _confirmDeleteAccount(context),
                  ),
                ],
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  // ── Avatar ─────────────────────────────────────────────────────────────────

  void _onAvatarTap() {
    final user = ref.read(authProvider).user;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [

              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Avatar preview
              Stack(alignment: Alignment.center, children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      width: 3,
                    ),
                  ),
                  child: ClipOval(
                    child: _photoUrl != null
                        ? Image.network(_photoUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _AvatarInitials(user: user))
                        : _AvatarInitials(user: user),
                  ),
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 14, color: Colors.white),
                  ),
                ),
              ]),

              const SizedBox(height: 12),

              Text(
                user?.name ?? 'Tài xế',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Chọn ảnh đại diện mới',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),

              const SizedBox(height: 24),

              if (_avatarLocked) ...[
                // Locked notice
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8F0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.lock_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _avatarNextUpdate != null
                            ? 'Còn ${_avatarNextUpdate!.difference(DateTime.now()).inDays + 1} ngày nữa có thể đổi ảnh.'
                            : 'Ảnh đại diện chỉ được thay đổi 1 tháng 1 lần.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ]),
                ),
              ] else ...[
                // Camera & Gallery buttons side by side
                Row(children: [
                  Expanded(
                    child: _AvatarOptionCard(
                      icon: Icons.camera_alt_rounded,
                      color: AppColors.primary,
                      label: 'Máy ảnh',
                      subtitle: 'Chụp ngay',
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndUpload(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AvatarOptionCard(
                      icon: Icons.photo_library_rounded,
                      color: AppColors.info,
                      label: 'Thư viện',
                      subtitle: 'Chọn ảnh',
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndUpload(ImageSource.gallery);
                      },
                    ),
                  ),
                ]),
              ],

              const SizedBox(height: 8),

              // Cancel
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                  ),
                  child: const Text('Hủy',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                ),
              ),

            ]),
          ),
        ),
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
        // updateProfile() không trả avatar_locked/avatar_next_update_at (chỉ
        // GET /driver/profile mới tính) — nhưng vừa upload thành công nghĩa
        // là server vừa set avatar_updated_at=now(), nên tự tính khóa 30 ngày
        // ở đây, không thì client vẫn tưởng đổi được ảnh tiếp cho tới lần
        // pull-to-refresh kế tiếp.
        setState(() {
          _photoUrl         = userData?['profile_photo_url'] as String?;
          _avatarLocked     = true;
          _avatarNextUpdate = DateTime.now().add(const Duration(days: 30));
          _uploadingAvatar  = false;
        });
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref.read(apiClientProvider).post('/driver/delete-account/request');
                if (mounted) setState(() => _deleteRequested = true);
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              } catch (_) {
                // Request thất bại thì không logout — tài xế tưởng đã gửi yêu
                // cầu xóa nhưng thực ra chưa, để họ biết mà thử lại.
                messenger.showSnackBar(const SnackBar(
                  content: Text('Không thể gửi yêu cầu xóa tài khoản. Vui lòng thử lại.'),
                  backgroundColor: AppColors.danger,
                ));
              }
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

// ── Settings section ──────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String? header;
  final List<Widget> children;
  const _SettingsSection({this.header, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (header != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text(
            header!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(children: children),
        ),
      ),
    ]);
  }
}

// ── Settings row ──────────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color? iconBg;
  final Color? iconColor;
  final String label;
  final Color? labelColor;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    this.iconBg,
    this.iconColor,
    required this.label,
    this.labelColor,
    this.trailing,
    this.showChevron = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: iconBg ?? const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: iconColor ?? AppColors.textSecondary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: labelColor ?? AppColors.textPrimary)),
              ),
              if (trailing != null)
                trailing!
              else if (showChevron)
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFD0D0D5), size: 20),
            ]),
          ),
        ),
      );
}

// ── Score card ────────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final int score;
  final int maxScore;
  final String label;
  final int? bonusAt;
  final int? penaltyAt;
  final int? bonusAmt;
  final int? penaltyAmt;
  final int? streak;
  final VoidCallback onTap;

  const _ScoreCard({
    required this.score,
    required this.maxScore,
    required this.label,
    this.bonusAt,
    this.penaltyAt,
    this.bonusAmt,
    this.penaltyAmt,
    this.streak,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Week status
    final Color statusColor;
    final String statusText;
    if (bonusAt != null && score >= bonusAt!) {
      statusColor = AppColors.success;
      statusText  = bonusAmt != null
          ? 'Đạt thưởng +${_fmt(bonusAmt!)}đ cuối tuần 🎉'
          : 'Đạt mức thưởng!';
    } else if (penaltyAt != null && score <= penaltyAt!) {
      statusColor = AppColors.danger;
      statusText  = penaltyAmt != null
          ? 'Nguy hiểm — có thể bị phạt ${_fmt(penaltyAmt!)}đ'
          : 'Dưới ngưỡng an toàn';
    } else if (bonusAt != null) {
      statusColor = AppColors.primary;
      statusText  = 'Cần +${bonusAt! - score} điểm để nhận thưởng';
    } else {
      statusColor = AppColors.textSecondary;
      statusText  = label;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(children: [

          // ── Top: ring + info ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [

              // Ring
              SizedBox(
                width: 60, height: 60,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: 1, strokeWidth: 5,
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: (score / maxScore).clamp(0.0, 1.0),
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '$score',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ]),
              ),

              const SizedBox(width: 14),

              // Text info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Điểm tích lũy',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiary,
                            letterSpacing: 0.1,
                          ),
                        ),
                        Text(
                          '$score / $maxScore',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Label pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    if ((streak ?? 0) > 0) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Text('🔥', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          '$streak đơn liên tiếp',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),

              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: Color(0xFFD0D0D5)),
            ]),
          ),

          // ── Progress bar ─────────────────────────────────────────────
          if (bonusAt != null || penaltyAt != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ScoreBar(
                score:      score,
                maxScore:   maxScore,
                bonusAt:    bonusAt,
                penaltyAt:  penaltyAt,
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ── Status banner ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16)),
            ),
            child: Row(children: [
              Icon(
                score >= (bonusAt ?? maxScore + 1)
                    ? Icons.emoji_events_rounded
                    : score <= (penaltyAt ?? -1)
                        ? Icons.warning_amber_rounded
                        : Icons.trending_up_rounded,
                size: 14,
                color: statusColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),

        ]),
      ),
    );
  }

  String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(0)}.000' : '$n';
}

class _ScoreBar extends StatelessWidget {
  final int score;
  final int maxScore;
  final int? bonusAt;
  final int? penaltyAt;

  const _ScoreBar({
    required this.score,
    required this.maxScore,
    this.bonusAt,
    this.penaltyAt,
  });

  @override
  Widget build(BuildContext context) {
    final scoreFrac   = (score / maxScore).clamp(0.0, 1.0);
    final penaltyFrac = penaltyAt != null ? penaltyAt! / maxScore : 0.0;
    final bonusFrac   = bonusAt   != null ? bonusAt!   / maxScore : 1.0;

    return LayoutBuilder(builder: (_, box) {
      final w       = box.maxWidth;
      const h       = 6.0;
      final dotX    = (scoreFrac * w).clamp(3.0, w - 3.0);

      return SizedBox(
        height: h + 8,
        child: Stack(children: [
          // Track
          Positioned(
            left: 0, right: 0, top: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: h,
                child: Row(children: [
                  if (penaltyAt != null)
                    Expanded(
                      flex: (penaltyFrac * 100).round(),
                      child: Container(
                          color: AppColors.danger.withValues(alpha: 0.2)),
                    ),
                  Expanded(
                    flex: ((bonusFrac - penaltyFrac) * 100).round().clamp(0, 100),
                    child: Container(color: const Color(0xFFE5E7EB)),
                  ),
                  if (bonusAt != null)
                    Expanded(
                      flex: ((1 - bonusFrac) * 100).round(),
                      child: Container(
                          color: AppColors.success.withValues(alpha: 0.25)),
                    ),
                ]),
              ),
            ),
          ),
          // Score dot
          Positioned(
            left: dotX - 5, top: 1,
            child: Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ]),
      );
    });
  }
}

// ── Stat item ─────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 6),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: const Color(0xFFEEEEEE));
}

// ── KYC summary card ──────────────────────────────────────────────────────────

class _KycSummaryCard extends StatelessWidget {
  final String? cccdStatus;
  final String? licenseStatus;
  final VoidCallback onTap;

  const _KycSummaryCard({
    required this.cccdStatus,
    required this.licenseStatus,
    required this.onTap,
  });

  int get _steps {
    int n = 0;
    if (cccdStatus    == 'approved') n++;
    if (licenseStatus == 'approved') n++;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final steps  = _steps;
    final isDone = steps == 2;
    final color  = isDone ? AppColors.success : AppColors.primary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  isDone ? Icons.verified_user_rounded : Icons.shield_rounded,
                  color: color, size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Hồ sơ tài xế',
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  Text(
                    isDone ? 'Hồ sơ đã hoàn thiện' : '$steps/2 mục đã hoàn thiện',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$steps/2',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFD0D0D5), size: 20),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: steps / 2,
                minHeight: 5,
                backgroundColor: const Color(0xFFF0F0F0),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _StepChip('CCCD',      cccdStatus    == 'approved'),
              _StepChip('Bằng lái',  licenseStatus == 'approved'),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  final String label;
  final bool done;
  const _StepChip(this.label, this.done);

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.success : AppColors.textSecondary;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(
        done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
        size: 13, color: color,
      ),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: done ? FontWeight.w600 : FontWeight.w400,
              color: color)),
    ]);
  }
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

// ── Avatar option card ────────────────────────────────────────────────────────

class _AvatarOptionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _AvatarOptionCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Column(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
      );
}

// ── Balance row ───────────────────────────────────────────────────────────────

class _BalanceRow extends StatelessWidget {
  final int? balance;
  final VoidCallback onTap;
  const _BalanceRow({required this.balance, required this.onTap});

  String _fmt(int n) {
    if (n == 0) return '0đ';
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    buf.write('đ');
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final amt = balance ?? 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Text('Số dư ví',
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
            ),
            Text(
              _fmt(amt),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: amt > 0 ? AppColors.primary : AppColors.textSecondary),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFD0D0D5), size: 20),
          ]),
        ),
      ),
    );
  }
}

