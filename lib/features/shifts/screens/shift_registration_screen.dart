import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_back_button.dart';
import '../providers/shift_provider.dart';
import '../widgets/pending_banner.dart';
import '../widgets/rejected_banner.dart';
import '../widgets/shift_card.dart';

class ShiftRegistrationScreen extends ConsumerStatefulWidget {
  const ShiftRegistrationScreen({super.key});

  @override
  ConsumerState<ShiftRegistrationScreen> createState() =>
      _ShiftRegistrationScreenState();
}

class _ShiftRegistrationScreenState
    extends ConsumerState<ShiftRegistrationScreen> {
  final Set<int> _selectedIds = {};
  bool _selectionInitialized = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(shiftProvider.notifier).fetch());
  }

  void _toggle(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  bool _sameAsCurrent(List<int> current) {
    if (_selectedIds.length != current.length) return false;
    final a = _selectedIds.toList()..sort();
    final b = [...current]..sort();
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _submit(bool isRegistered) async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Chọn ít nhất 1 ca'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    final ids = _selectedIds.toList();
    final notifier = ref.read(shiftProvider.notifier);
    final result = isRegistered
        ? await notifier.submitChangeRequest(ids)
        : await notifier.selectShift(ids);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(result.message ?? (result.success ? 'Thành công' : 'Thất bại')),
      backgroundColor: result.success ? AppColors.success : AppColors.danger,
    ));
  }

  IconData _iconFor(String code) => switch (code) {
        'morning' => Icons.wb_sunny_rounded,
        'afternoon' => Icons.light_mode_rounded,
        'evening' => Icons.nights_stay_rounded,
        _ => Icons.schedule_rounded,
      };

  Color _colorFor(String code) => switch (code) {
        'morning' => const Color(0xFFF59E0B),
        'afternoon' => const Color(0xFF3B82F6),
        'evening' => const Color(0xFF6366F1),
        _ => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final state = ref.watch(shiftProvider);

    // Đồng bộ lựa chọn ban đầu với ca đã đăng ký — chỉ chạy 1 lần, đúng lúc
    // fetch() thật sự đã xong (không dùng "!state.loading" — giá trị đó
    // đúng cả lúc CHƯA từng fetch, khiến lần build đầu tiên vô tình khớp
    // điều kiện trước khi Future.microtask trong initState() kịp chạy).
    if (!_selectionInitialized && state.hasLoadedOnce) {
      _selectionInitialized = true;
      _selectedIds.addAll(state.currentShiftIds);
    }

    final isRegistered = state.isRegistered;
    final hasPending = state.hasPendingChangeRequest;
    final canSubmit = _selectedIds.isNotEmpty &&
        !hasPending &&
        (!isRegistered || !_sameAsCurrent(state.currentShiftIds));

    String? nameFor(int id) {
      for (final s in state.shifts) {
        if (s.id == id) return s.name;
      }
      return null;
    }

    final currentNames =
        state.currentShiftIds.map(nameFor).whereType<String>().join(', ');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8F5),
        body: state.loading && state.shifts.isEmpty
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => ref.read(shiftProvider.notifier).fetch(),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 100),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Container(
                      width: double.infinity,
                      color: const Color(0xFFFFFEFD),
                      padding: EdgeInsets.fromLTRB(16, top + 16, 16, 16),
                      child: Row(children: [
                        AppBackButton(
                            onTap: () => Navigator.of(context).maybePop()),
                        const Expanded(
                          child: Text('Ca làm việc',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1B1411),
                                  letterSpacing: -0.2)),
                        ),
                        const SizedBox(width: 40),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isRegistered &&
                              state.currentShiftIds.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEAE3),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(children: [
                                const Icon(Icons.check_circle_outline_rounded,
                                    color: Color(0xFF17110F), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Đang đăng ký',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFFFF6035))),
                                        const SizedBox(height: 2),
                                        Text(
                                          currentNames,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textPrimary),
                                        ),
                                      ]),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (hasPending) ...[
                            PendingBanner(
                                request: state.changeRequest!,
                                shifts: state.shifts),
                            const SizedBox(height: 16),
                          ] else if (state.changeRequest?.isRejected ??
                              false) ...[
                            RejectedBanner(request: state.changeRequest!),
                            const SizedBox(height: 16),
                          ],
                          Text(
                            isRegistered
                                ? 'Ca hiện tại của bạn'
                                : 'Chọn ca làm việc',
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1B1411)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isRegistered
                                ? 'Muốn đổi ca, chọn lại bên dưới rồi gửi yêu cầu để quản lý duyệt.'
                                : 'Đăng ký ca phù hợp với bạn, áp dụng ngay và lặp lại mỗi ngày cho tới khi bạn đổi ca.',
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                                height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          if (state.shifts.isEmpty && state.loadError)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: Column(children: [
                                  const Icon(Icons.wifi_off_rounded,
                                      color: AppColors.textSecondary, size: 28),
                                  const SizedBox(height: 8),
                                  const Text(
                                      'Không tải được danh sách ca làm việc',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13)),
                                  const SizedBox(height: 10),
                                  TextButton(
                                    onPressed: () => ref
                                        .read(shiftProvider.notifier)
                                        .fetch(),
                                    child: const Text('Thử lại'),
                                  ),
                                ]),
                              ),
                            )
                          else if (state.shifts.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: Text(
                                    'Khu vực của bạn chưa có ca nào được thiết lập',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13)),
                              ),
                            )
                          else
                            ...state.shifts.map((s) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: ShiftCard(
                                    shift: s,
                                    selected: _selectedIds.contains(s.id),
                                    icon: _iconFor(s.code),
                                    color: _colorFor(s.code),
                                    enabled: !hasPending,
                                    onTap: () => _toggle(s.id),
                                  ),
                                )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: state.shifts.isEmpty
            ? null
            : SafeArea(
                child: Container(
                  color: const Color(0xFFFFFEFD),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: (canSubmit && !state.submitting)
                          ? () => _submit(isRegistered)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6035),
                        disabledBackgroundColor:
                            const Color(0xFFFF6035).withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26)),
                      ),
                      child: state.submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(
                              hasPending
                                  ? 'Đang chờ duyệt yêu cầu đổi ca'
                                  : (isRegistered
                                      ? 'Gửi yêu cầu đổi ca'
                                      : 'Đăng ký ca làm việc'),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
