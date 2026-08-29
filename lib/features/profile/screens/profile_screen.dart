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
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../widgets/avatar_picker_sheet.dart';
import '../widgets/balance_row.dart';
import '../widgets/edit_name_sheet.dart';
import '../widgets/kyc_summary_card.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_score_card.dart';
import '../widgets/settings_section.dart';
import 'change_password_screen.dart';
import 'legal_page_screen.dart';
import '../../auth/providers/auth_provider.dart';
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
  bool _avatarLocked = false;
  DateTime? _avatarNextUpdate;

  String? _licenseStatus;
  String? _cccdImageStatus;
  String? _vehicleType;
  String? _licensePlate;
  bool _deleteRequested = false;

  int? _balance;
  String? _bankName;
  String? _bankAccount;
  String _appVersion = '';

  int? _acceptanceRate;
  int? _completionRate;

  int? _score;
  int? _maxScore;
  String? _scoreLabel;
  int? _scoreBonusAt;
  int? _scorePenaltyAt;
  int? _scoreBonusAmt;
  int? _scorePenaltyAmt;
  int? _scoreStreak;

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
    // trắng cả trang, kể cả khi profile/score đã lấy được bình thường.
    Map<String, dynamic>? profileData;
    Map<String, dynamic>? statsData;
    Map<String, dynamic>? scoreData;
    List<dynamic>? debtsRaw;

    await Future.wait([
      ref.read(apiClientProvider).get('/driver/profile').then((r) {
        profileData = ((r.data['data'] ?? r.data)
            as Map<String, dynamic>)['user'] as Map<String, dynamic>?;
      }).catchError((_) {}),
      ref.read(apiClientProvider).get('/driver/stats').then((r) {
        statsData = (r.data['data'] ?? r.data) as Map<String, dynamic>?;
      }).catchError((_) {}),
      ref.read(apiClientProvider).get('/driver/score').then((r) {
        scoreData = (r.data['data'] ?? r.data) as Map<String, dynamic>?;
      }).catchError((_) {}),
      ref.read(apiClientProvider).get('/debts').then((r) {
        final d = r.data['data'] ?? r.data;
        debtsRaw = d is List ? d : <dynamic>[];
      }).catchError((_) {}),
    ]);

    if (mounted) {
      setState(() {
        final p = profileData;
        if (p != null) {
          _cityName = p['city_name'] as String?;
          _photoUrl = p['profile_photo_url'] as String?;
          _rating = p['rating'] == null
              ? null
              : double.tryParse(p['rating'].toString());
          _licenseStatus = p['license_status'] as String?;
          _cccdImageStatus = p['cccd_image_status'] as String?;
          _vehicleType = p['vehicle_type'] as String?;
          _licensePlate = p['license_plate'] as String?;
          _balance = (p['balance'] as num?)?.toInt();
          _bankName = p['bank_name'] as String?;
          _bankAccount = p['bank_account'] as String?;
          _deleteRequested = p['delete_requested_at'] != null;
          _nameLocked = p['name_locked'] as bool? ?? false;
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
        final sc = scoreData;
        if (sc != null) {
          _score = sc['score'] as int?;
          _maxScore = sc['max_score'] as int?;
          _scoreLabel = sc['label'] as String?;
          final week = sc['week'] as Map<String, dynamic>?;
          _scoreBonusAt = (week?['bonus_at'] as num?)?.toInt();
          _scorePenaltyAt = (week?['penalty_at'] as num?)?.toInt();
          _scoreBonusAmt = (week?['bonus_amount'] as num?)?.toInt();
          _scorePenaltyAmt = (week?['penalty_amount'] as num?)?.toInt();
          final streak = sc['streak'] as Map<String, dynamic>?;
          _scoreStreak = (streak?['count'] as num?)?.toInt();
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

  // ── Công nợ trailing ──────────────────────────────────────────────────────

  Widget? _debtTrailing() {
    if (_debts.isEmpty) {
      return const Text('Không có nợ',
          style: TextStyle(fontSize: 12, color: AppColors.textTertiary));
    }
    final total = _debts.fold<int>(0, (s, d) => s + d.remaining);
    final hasOverdue = _debts.any((d) => d.isOverdue);
    if (hasOverdue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('Cần thanh toán ngay',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            )),
      );
    }
    return Text(Fmt.currency(total),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ));
  }

  Future<void> _showVehicleEditor() async {
    var selectedType = _vehicleType ?? 'motorbike';
    var saving = false;
    var plateInput = _licensePlate ?? '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final media = MediaQuery.of(context);
          final maxHeight = (media.size.height -
                  media.viewInsets.bottom -
                  media.padding.top -
                  16)
              .clamp(240.0, media.size.height * 0.9)
              .toDouble();
          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: const BoxDecoration(
                color: Color(0xFFFFFEFD),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding:
                    EdgeInsets.fromLTRB(20, 12, 20, media.padding.bottom + 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                        color: const Color(0xFFD8D0CC),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 18),
                  const Text('Thông tin phương tiện',
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 18),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'motorbike',
                          label: Text('Xe máy'),
                          icon: Icon(Icons.two_wheeler_rounded)),
                      ButtonSegment(
                          value: 'car',
                          label: Text('Ô tô'),
                          icon: Icon(Icons.directions_car_rounded)),
                    ],
                    selected: {selectedType},
                    onSelectionChanged: saving
                        ? null
                        : (value) =>
                            setSheetState(() => selectedType = value.first),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: plateInput,
                    onChanged: (value) => plateInput = value,
                    enabled: !saving,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 20,
                    decoration: InputDecoration(
                      labelText: 'Biển số xe',
                      hintText: 'Ví dụ: 68B1-123.45',
                      counterText: '',
                      prefixIcon: const Icon(Icons.pin_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final plate = plateInput.trim().toUpperCase();
                              if (plate.isEmpty) {
                                _toast(
                                    sheetContext, 'Vui lòng nhập biển số xe');
                                return;
                              }
                              setSheetState(() => saving = true);
                              try {
                                await ref.read(apiClientProvider).post(
                                  '/driver/profile/update',
                                  data: {
                                    'vehicle_type': selectedType,
                                    'license_plate': plate,
                                  },
                                );
                                if (!mounted) return;
                                setState(() {
                                  _vehicleType = selectedType;
                                  _licensePlate = plate;
                                });
                                await ref
                                    .read(authProvider.notifier)
                                    .refreshUser();
                                if (!sheetContext.mounted) return;
                                Navigator.pop(sheetContext);
                                _toast(
                                    context, 'Cập nhật phương tiện thành công',
                                    success: true);
                              } on DioException catch (e) {
                                final data = e.response?.data;
                                final message = data is Map
                                    ? data['message'] as String?
                                    : null;
                                if (sheetContext.mounted) {
                                  _toast(
                                      sheetContext,
                                      message ??
                                          'Không thể cập nhật phương tiện');
                                  setSheetState(() => saving = false);
                                }
                              } catch (_) {
                                if (sheetContext.mounted) {
                                  _toast(sheetContext,
                                      'Không thể cập nhật phương tiện');
                                  setSheetState(() => saving = false);
                                }
                              }
                            },
                      child: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Lưu thông tin'),
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final hasStats =
        _acceptanceRate != null || _completionRate != null || _rating != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8F5),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadData,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // ── Header + floating stats card ──────────────────────────
              ProfileHeader(
                user: user,
                photoUrl: _photoUrl,
                uploadingAvatar: _uploadingAvatar,
                nameLocked: _nameLocked,
                cityName: _cityName,
                hasStats: hasStats,
                acceptanceRate: _acceptanceRate,
                completionRate: _completionRate,
                rating: _rating,
                onAvatarTap: _onAvatarTap,
                onEditName: (name) => _showEditName(context, name),
              ),

              const SizedBox(height: 12),

              // ── Score card ────────────────────────────────────────────
              if (_score != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ProfileScoreCard(
                    score: _score!,
                    maxScore: _maxScore ?? 140,
                    label: _scoreLabel ?? '',
                    bonusAt: _scoreBonusAt,
                    penaltyAt: _scorePenaltyAt,
                    bonusAmt: _scoreBonusAmt,
                    penaltyAmt: _scorePenaltyAmt,
                    streak: _scoreStreak,
                    onTap: () => context.push('/score'),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Hồ sơ tài xế ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: KycSummaryCard(
                  cccdStatus: _cccdImageStatus,
                  licenseStatus: _licenseStatus,
                  onTap: () async {
                    await context.push('/kyc');
                    _loadData();
                  },
                ),
              ),

              const SizedBox(height: 12),

              // ── Phương tiện ────────────────────────────────────────
              SettingsSection(
                header: 'Phương tiện',
                children: [
                  SettingsRow(
                    icon: _vehicleType == 'car'
                        ? Icons.directions_car_rounded
                        : Icons.two_wheeler_rounded,
                    iconBg: AppColors.primary.withValues(alpha: 0.12),
                    iconColor: AppColors.primary,
                    label: 'Loại xe',
                    trailing: Text(
                      switch (_vehicleType) {
                        'motorbike' => 'Xe máy',
                        'car' => 'Ô tô',
                        _ => 'Chưa cập nhật',
                      },
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    onTap: _showVehicleEditor,
                  ),
                  const Divider(
                      height: 1, indent: 56, color: Color(0xFFF5F5F5)),
                  SettingsRow(
                    icon: Icons.pin_rounded,
                    iconBg: AppColors.primary.withValues(alpha: 0.12),
                    iconColor: AppColors.primary,
                    label: 'Biển số xe',
                    trailing: Text(
                      _licensePlate?.trim().isNotEmpty == true
                          ? _licensePlate!.toUpperCase()
                          : 'Chưa cập nhật',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary),
                    ),
                    onTap: _showVehicleEditor,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Lịch làm việc ────────────────────────────────────────
              SettingsSection(
                header: 'Lịch làm việc',
                children: [
                  SettingsRow(
                    icon: Icons.schedule_rounded,
                    iconBg: AppColors.primary.withValues(alpha: 0.12),
                    iconColor: AppColors.primary,
                    label: 'Ca làm việc',
                    onTap: () => context.push('/shifts'),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Tài chính ────────────────────────────────────────────
              SettingsSection(
                header: 'Tài chính',
                children: [
                  // Balance row
                  BalanceRow(
                    balance: _balance,
                    onTap: () => context.push('/wallet'),
                  ),
                  const Divider(
                      height: 1, indent: 56, color: Color(0xFFF5F5F5)),
                  // Công nợ
                  SettingsRow(
                    icon: Icons.warning_amber_rounded,
                    iconBg: AppColors.danger.withValues(alpha: 0.12),
                    iconColor: AppColors.danger,
                    label: 'Công nợ',
                    trailing: _debtTrailing(),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DebtScreen())),
                  ),
                  const Divider(
                      height: 1, indent: 56, color: Color(0xFFF5F5F5)),
                  // Ngân hàng liên kết
                  SettingsRow(
                    icon: Icons.account_balance_rounded,
                    iconBg: AppColors.primary.withValues(alpha: 0.12),
                    iconColor: AppColors.primary,
                    label: 'Tài khoản ngân hàng',
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
                                color:
                                    AppColors.danger.withValues(alpha: 0.8))),
                    onTap: () => context.push('/bank-account'),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Bảo mật ──────────────────────────────────────────────
              SettingsSection(
                header: 'Bảo mật',
                children: [
                  SettingsRow(
                    icon: Icons.lock_outline_rounded,
                    iconBg: AppColors.primary.withValues(alpha: 0.12),
                    iconColor: AppColors.primary,
                    label: 'Đổi mật khẩu',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen())),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Pháp lý ──────────────────────────────────────────────
              SettingsSection(
                header: 'Pháp lý',
                children: [
                  SettingsRow(
                    icon: Icons.shield_outlined,
                    iconBg: AppColors.primary.withValues(alpha: 0.12),
                    iconColor: AppColors.primary,
                    label: 'Chính sách bảo mật',
                    onTap: () => _showPage(
                        context, 'privacy-policy', 'Chính sách bảo mật'),
                  ),
                  const Divider(
                      height: 1, indent: 56, color: Color(0xFFF5F5F5)),
                  SettingsRow(
                    icon: Icons.description_outlined,
                    iconBg: AppColors.primary.withValues(alpha: 0.12),
                    iconColor: AppColors.primary,
                    label: 'Điều khoản sử dụng',
                    onTap: () => _showPage(
                        context, 'terms-of-service', 'Điều khoản sử dụng'),
                  ),
                  const Divider(
                      height: 1, indent: 56, color: Color(0xFFF5F5F5)),
                  SettingsRow(
                    icon: Icons.info_outline_rounded,
                    iconBg: AppColors.primary.withValues(alpha: 0.12),
                    iconColor: AppColors.primary,
                    label: 'Phiên bản',
                    trailing: Text(
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
              SettingsSection(
                children: [
                  SettingsRow(
                    icon: Icons.logout_rounded,
                    iconBg: AppColors.danger.withValues(alpha: 0.12),
                    iconColor: AppColors.danger,
                    label: 'Đăng xuất',
                    labelColor: AppColors.danger,
                    showChevron: false,
                    onTap: () => _confirmLogout(context),
                  ),
                  const Divider(
                      height: 1, indent: 56, color: Color(0xFFF5F5F5)),
                  SettingsRow(
                    icon: _deleteRequested
                        ? Icons.restore_rounded
                        : Icons.delete_forever_rounded,
                    iconBg: AppColors.danger.withValues(alpha: 0.12),
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

              // Chừa chỗ cho thanh bottom nav nổi (kính mờ, extendBody: true
              // ở HomeScreen) — không thì phần cuối bị nav che mất.
              SizedBox(height: BottomNav.reservedHeight(context)),
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
        setState(() => _nameLocked = true);
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
