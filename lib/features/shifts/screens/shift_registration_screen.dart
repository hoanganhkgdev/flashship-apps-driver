import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_screen_header.dart';
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
        'morning' => AppColors.amber,
        'afternoon' => AppColors.info,
        'evening' => const Color(0xFF6366F1),
        _ => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: AppColors.background,
        appBar: const AppScreenHeader(
          title: 'Lịch làm việc',
          backgroundColor: AppColors.primarySoft,
        ),
        body: state.loading && state.shifts.isEmpty
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => ref.read(shiftProvider.notifier).fetch(),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl3),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isRegistered &&
                              state.currentShiftIds.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.card),
                                border: Border.all(
                                  color:
                                      AppColors.success.withValues(alpha: .22),
                                ),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppColors.successSoft,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: const Icon(
                                    Icons.event_available_rounded,
                                    color: AppColors.success,
                                    size: 21,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Ca đang áp dụng',
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                    color: AppColors.success,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                        const SizedBox(height: 2),
                                        Text(
                                          currentNames,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              AppTextStyles.bodyStrong.copyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ]),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    color: AppColors.successSoft,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_rounded,
                                      size: 17, color: AppColors.success),
                                ),
                              ]),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          if (hasPending) ...[
                            PendingBanner(
                                request: state.changeRequest!,
                                shifts: state.shifts),
                            const SizedBox(height: AppSpacing.lg),
                          ] else if (state.changeRequest?.isRecentlyRejected ??
                              false) ...[
                            RejectedBanner(request: state.changeRequest!),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 4,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.full),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isRegistered
                                          ? 'Thay đổi ca'
                                          : 'Chọn ca làm việc',
                                      style:
                                          AppTextStyles.sectionTitle.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isRegistered
                                          ? 'Chọn ca mới và gửi yêu cầu để quản lý duyệt'
                                          : 'Chọn ca phù hợp với thời gian của bạn',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (state.shifts.isEmpty && state.loadError)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.xl3),
                              child: Center(
                                child: Column(children: [
                                  const Icon(Icons.wifi_off_rounded,
                                      color: AppColors.textSecondary, size: 28),
                                  const SizedBox(height: AppSpacing.sm),
                                  const Text(
                                      'Không tải được danh sách ca làm việc',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: AppFontSize.base)),
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
                              padding: EdgeInsets.symmetric(
                                  vertical: AppSpacing.xl3),
                              child: Center(
                                child: Text(
                                    'Khu vực của bạn chưa có ca nào được thiết lập',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: AppFontSize.base)),
                              ),
                            )
                          else
                            ...state.shifts.map((s) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
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
            : Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    MediaQuery.paddingOf(context).bottom + AppSpacing.md),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    const Icon(Icons.checklist_rounded,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _selectedIds.isEmpty
                          ? 'Chưa chọn ca nào'
                          : 'Đã chọn ${_selectedIds.length} ca',
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: (canSubmit && !state.submitting)
                          ? () => _submit(isRegistered)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha: 0.35),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md)),
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
                              style: AppTextStyles.sectionTitle.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ]),
              ),
      ),
    );
  }
}
