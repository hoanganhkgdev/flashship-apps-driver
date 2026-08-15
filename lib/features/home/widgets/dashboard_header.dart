import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../shifts/models/shift_model.dart';

class DashboardHeader extends StatelessWidget {
  final dynamic user;
  final bool isOnline;
  final bool toggling;
  final bool locked;
  final VoidCallback onToggle;
  final List<ShiftModel> shifts;
  final List<int> currentShiftIds;
  final VoidCallback onShiftTap;

  const DashboardHeader({
    super.key,
    required this.user,
    required this.isOnline,
    required this.toggling,
    required this.locked,
    required this.onToggle,
    required this.shifts,
    required this.currentShiftIds,
    required this.onShiftTap,
  });

  Widget _avatarInitials(String? initials) => Center(
        child: Text(initials ?? 'D',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
      );

  static String _hm(String t) => t.length >= 5 ? t.substring(0, 5) : t;

  static DateTime _todayAt(DateTime now, String hms) {
    final parts = hms.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return DateTime(now.year, now.month, now.day, h, m);
  }

  /// Tìm ca đã đăng ký đang trong khung giờ hiện tại + thời gian còn lại tới
  /// giờ kết thúc. Xử lý ca qua nửa đêm (endTime <= startTime) bằng cách
  /// cộng thêm 1 ngày, và kiểm tra thêm cửa sổ "bắt đầu từ hôm qua" cho ca
  /// qua đêm đang chạy dở (vd ca 22:00-06:00, giờ hiện tại 01:00).
  (ShiftModel, Duration)? _activeShift(DateTime now) {
    for (final s in shifts) {
      if (!currentShiftIds.contains(s.id)) continue;
      final start = _todayAt(now, s.startTime);
      var end = _todayAt(now, s.endTime);
      if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
      if (now.isAfter(start) && now.isBefore(end)) {
        return (s, end.difference(now));
      }
      final startYesterday = start.subtract(const Duration(days: 1));
      final endYesterday = end.subtract(const Duration(days: 1));
      if (now.isAfter(startYesterday) && now.isBefore(endYesterday)) {
        return (s, endYesterday.difference(now));
      }
    }
    return null;
  }

  static String _fmtRemaining(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h <= 0) return 'còn ${m}p';
    return 'còn ${h}h${m}p';
  }

  static (Color bg, Color fg, IconData icon) _statusCapsule(
      {required bool locked, required bool isOnline}) {
    if (locked) {
      return (AppColors.dangerSoft, AppColors.danger, Icons.lock_rounded);
    }
    if (isOnline) {
      return (AppColors.successSoft, AppColors.success, Icons.bolt_rounded);
    }
    return (AppColors.surfaceAlt, AppColors.textSecondary, Icons.bolt_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final active = _activeShift(DateTime.now());
    final (capsuleBg, capsuleFg, capsuleIcon) =
        _statusCapsule(locked: locked, isOnline: isOnline);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFCC5A08), Color(0xFFE8720C), Color(0xFFF59E30)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Decorative background blobs
          Positioned(
            top: -70,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            left: -40,
            top: 130,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar row
                    Row(children: [
                      // Avatar
                      Stack(children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.95),
                              width: 2.5,
                            ),
                            color: Colors.white.withValues(alpha: 0.22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: user?.profilePhotoUrl != null
                              ? Image.network(
                                  user!.profilePhotoUrl!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  frameBuilder:
                                      (_, child, frame, wasSyncLoaded) {
                                    if (wasSyncLoaded) return child;
                                    return AnimatedOpacity(
                                      opacity: frame == null ? 0 : 1,
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                      child: child,
                                    );
                                  },
                                  loadingBuilder: (_, child, progress) =>
                                      progress == null
                                          ? child
                                          : _avatarInitials(user?.initials),
                                  errorBuilder: (_, __, ___) =>
                                      _avatarInitials(user?.initials),
                                )
                              : _avatarInitials(user?.initials),
                        ),
                        // Online dot
                        Positioned(
                          bottom: 1,
                          right: 1,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? AppColors.success
                                  : AppColors.textTertiary,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ]),

                      const SizedBox(width: 12),

                      // Name
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Xin chào 👋',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.3,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.name ?? 'Tài xế',
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.4,
                                  shadows: [
                                    Shadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ]),
                      ),
                    ]),

                    const SizedBox(height: 16),

                    // Toggle card (trắng, nổi bằng shadow trên nền cam)
                    GestureDetector(
                      onTap: (toggling || locked) ? null : onToggle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(children: [
                          // Status icon capsule
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: capsuleBg,
                              shape: BoxShape.circle,
                            ),
                            child:
                                Icon(capsuleIcon, size: 20, color: capsuleFg),
                          ),

                          const SizedBox(width: 14),

                          // Label
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    locked
                                        ? 'Bị khóa do công nợ'
                                        : isOnline
                                            ? 'Đang nhận đơn'
                                            : 'Bật để nhận đơn',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: locked
                                          ? AppColors.danger
                                          : isOnline
                                              ? AppColors.success
                                              : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    locked
                                        ? 'Thanh toán công nợ để tiếp tục'
                                        : isOnline
                                            ? 'Đang hoạt động'
                                            : 'Nhấn để bắt đầu',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondary),
                                  ),
                                ]),
                          ),

                          const SizedBox(width: 14),

                          // Toggle switch
                          if (toggling)
                            const SizedBox(
                              width: 52,
                              height: 30,
                              child: Center(
                                  child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: AppColors.primary),
                              )),
                            )
                          else
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 52,
                              height: 30,
                              decoration: BoxDecoration(
                                color: locked
                                    ? const Color(0xFFDDDDDD)
                                    : isOnline
                                        ? AppColors.success
                                        : const Color(0xFFDDDDDD),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: AnimatedAlign(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                alignment: isOnline
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  margin: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle),
                                ),
                              ),
                            ),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Trạng thái ca làm việc ngay lúc này (khác ShiftCard bên
                    // dưới — đó là "đang đăng ký ca nào nói chung", đây là "có
                    // đang trong ca không tại thời điểm hiện tại").
                    GestureDetector(
                      onTap: onShiftTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          Icon(Icons.schedule_rounded,
                              size: 15,
                              color: Colors.white.withValues(alpha: 0.85)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: active != null
                                ? Text.rich(
                                    TextSpan(children: [
                                      TextSpan(
                                        text:
                                            '${active.$1.name} (${_hm(active.$1.startTime)}–${_hm(active.$1.endTime)})',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800),
                                      ),
                                      const TextSpan(text: ' · '),
                                      TextSpan(
                                        text: _fmtRemaining(active.$2),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800),
                                      ),
                                    ]),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color:
                                          Colors.white.withValues(alpha: 0.92),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : Text(
                                    'Chưa vào ca hôm nay',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          Colors.white.withValues(alpha: 0.92),
                                    ),
                                  ),
                          ),
                          if (active == null)
                            Icon(Icons.chevron_right_rounded,
                                size: 16,
                                color: Colors.white.withValues(alpha: 0.85)),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
