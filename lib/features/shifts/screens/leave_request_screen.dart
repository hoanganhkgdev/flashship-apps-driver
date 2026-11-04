import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../auth/providers/auth_provider.dart';

class LeaveRequestScreen extends ConsumerStatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  ConsumerState<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends ConsumerState<LeaveRequestScreen> {
  final _reasonController = TextEditingController();
  List<_LeaveDay> _upcoming = const [];
  late DateTime _fromDate;
  late DateTime _toDate;
  bool _loading = true;
  bool _submitting = false;
  int? _cancellingId;

  @override
  void initState() {
    super.initState();
    final tomorrow = DateUtils.dateOnly(DateTime.now()).add(
      const Duration(days: 1),
    );
    _fromDate = tomorrow;
    _toDate = tomorrow;
    Future.microtask(_loadLeaves);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaves() async {
    try {
      final response =
          await ref.read(apiClientProvider).get('/driver/shifts/leaves');
      final raw = (response.data['data'] as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _upcoming = raw
            .whereType<Map<String, dynamic>>()
            .map(_LeaveDay.fromJson)
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Không tải được lịch nghỉ. Vui lòng thử lại.');
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: isFrom ? today : _fromDate,
      // Backend chỉ cho xin trước tối đa 60 ngày (DriverLeaveService::MAX_AHEAD_DAYS).
      lastDate: today.add(Duration(days: isFrom ? 60 : 73)),
      helpText: isFrom ? 'CHỌN NGÀY BẮT ĐẦU' : 'CHỌN NGÀY KẾT THÚC',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate.isBefore(picked)) _toDate = picked;
      } else {
        _toDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.length < 3) {
      _showMessage('Vui lòng nhập lý do nghỉ ít nhất 3 ký tự.');
      return;
    }

    final days = _toDate.difference(_fromDate).inDays + 1;
    if (days > 14) {
      _showMessage('Mỗi lần chỉ được đăng ký tối đa 14 ngày nghỉ.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final response = await ref.read(apiClientProvider).post(
        '/driver/shifts/leaves',
        data: {
          'from_date': DateFormat('yyyy-MM-dd').format(_fromDate),
          'to_date': DateFormat('yyyy-MM-dd').format(_toDate),
          'note': reason,
        },
      );
      if (!mounted) return;
      _reasonController.clear();
      _showMessage(
        response.data['message'] as String? ??
            'Đã gửi yêu cầu nghỉ, vui lòng chờ admin duyệt.',
        success: true,
      );
      await _loadLeaves();
    } on DioException catch (error) {
      if (!mounted) return;
      _showMessage(
          parseApiError(error, fallback: 'Không thể gửi yêu cầu nghỉ phép.'));
    } catch (_) {
      if (mounted) _showMessage('Không thể gửi yêu cầu nghỉ phép.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmCancel(_LeaveDay leave) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(leave.isPending ? 'Rút yêu cầu nghỉ?' : 'Hủy ngày nghỉ?'),
        content: Text(
          leave.isPending
              ? 'Bạn muốn rút yêu cầu nghỉ ngày ${DateFormat('dd/MM/yyyy').format(leave.date)}?'
              : 'Bạn muốn hủy ngày nghỉ đã duyệt ${DateFormat('dd/MM/yyyy').format(leave.date)}? Bạn sẽ phải đi làm theo ca hôm đó${DateUtils.isSameDay(leave.date, DateTime.now()) ? '; phạt Offline của ca hôm nay tính từ lúc hủy' : ''}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(leave.isPending ? 'Rút yêu cầu' : 'Hủy ngày nghỉ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancellingId = leave.id);
    try {
      final response = await ref
          .read(apiClientProvider)
          .post('/driver/shifts/leaves/${leave.id}/cancel');
      if (!mounted) return;
      _showMessage(
        response.data['message'] as String? ?? 'Đã hủy ngày nghỉ.',
        success: true,
      );
      await _loadLeaves();
    } on DioException catch (error) {
      if (!mounted) return;
      _showMessage(parseApiError(error, fallback: 'Không thể hủy ngày nghỉ.'));
    } catch (_) {
      if (mounted) _showMessage('Không thể hủy ngày nghỉ.');
    } finally {
      if (mounted) setState(() => _cancellingId = null);
    }
  }

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? AppColors.success : AppColors.danger,
        ),
      );
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: const AppScreenHeader(
            title: 'Xin nghỉ phép',
            backgroundColor: AppColors.primarySoft,
          ),
          body: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadLeaves,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xl3,
              ),
              children: [
                const _NoticeCard(),
                const SizedBox(height: AppSpacing.lg),
                _RequestForm(
                  fromDate: _fromDate,
                  toDate: _toDate,
                  reasonController: _reasonController,
                  submitting: _submitting,
                  onPickFrom: () => _pickDate(isFrom: true),
                  onPickTo: () => _pickDate(isFrom: false),
                  onSubmit: _submit,
                ),
                const SizedBox(height: AppSpacing.xl2),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 4,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ngày nghỉ sắp tới',
                          style: TextStyle(
                            fontSize: AppFontSize.md,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Theo dõi trạng thái duyệt, rút yêu cầu khi cần',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  if (_upcoming.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        '${_upcoming.length} ngày',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: AppSpacing.md),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl3),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else if (_upcoming.isEmpty)
                  const _EmptyLeaves()
                else
                  ..._upcoming.map(
                    (leave) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _LeaveCard(
                        leave: leave,
                        cancelling: _cancellingId == leave.id,
                        onCancel: () => _confirmCancel(leave),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.primary.withValues(alpha: .18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.beach_access_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xin nghỉ cần admin duyệt',
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Khi chưa được duyệt hoặc bị từ chối, bạn vẫn cần đi làm theo ca đã đăng ký. Ngày được duyệt bạn sẽ không bật online hay nhận đơn.',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _RequestForm extends StatelessWidget {
  final DateTime fromDate;
  final DateTime toDate;
  final TextEditingController reasonController;
  final bool submitting;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onSubmit;

  const _RequestForm({
    required this.fromDate,
    required this.toDate,
    required this.reasonController,
    required this.submitting,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Đăng ký ngày nghỉ',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sectionTitle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                final from = _DateButton(
                  label: 'Từ ngày',
                  date: fromDate,
                  onTap: onPickFrom,
                );
                final to = _DateButton(
                  label: 'Đến ngày',
                  date: toDate,
                  onTap: onPickTo,
                );
                if (constraints.maxWidth < 300) {
                  return Column(children: [
                    from,
                    const SizedBox(height: AppSpacing.sm),
                    to,
                  ]);
                }
                return Row(children: [
                  Expanded(child: from),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: to),
                ]);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Lý do nghỉ',
              style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: reasonController,
              enabled: !submitting,
              minLines: 3,
              maxLines: 4,
              maxLength: 250,
              textCapitalization: TextCapitalization.sentences,
              decoration: appSheetInputDecoration(
                hint: 'Ví dụ: Có việc gia đình...',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 48),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              height: AppSize.buttonHeight,
              child: FilledButton.icon(
                onPressed: submitting ? null : onSubmit,
                icon: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 19),
                label: Text(submitting ? 'Đang gửi...' : 'Gửi yêu cầu nghỉ'),
              ),
            ),
          ],
        ),
      );
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(date),
                      maxLines: 1,
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _LeaveCard extends StatelessWidget {
  final _LeaveDay leave;
  final bool cancelling;
  final VoidCallback onCancel;

  const _LeaveCard({
    required this.leave,
    required this.cancelling,
    required this.onCancel,
  });

  ({String label, Color color, Color soft, IconData icon}) get _status =>
      leave.isPending
          ? (
              label: 'Chờ duyệt',
              color: AppColors.warning,
              soft: AppColors.warningSoft,
              icon: Icons.hourglass_top_rounded,
            )
          : leave.isRejected
              ? (
                  label: 'Không được duyệt',
                  color: AppColors.danger,
                  soft: AppColors.dangerSoft,
                  icon: Icons.block_rounded,
                )
              : (
                  label: 'Đã duyệt nghỉ',
                  color: AppColors.success,
                  soft: AppColors.successSoft,
                  icon: Icons.check_circle_rounded,
                );

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: leave.isApproved
              ? AppColors.divider.withValues(alpha: .7)
              : status.color.withValues(alpha: .25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 56,
            decoration: BoxDecoration(
              color: status.soft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('dd').format(leave.date),
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: status.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'TH${leave.date.month}',
                  style: AppTextStyles.caption.copyWith(
                    color: status.color,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_weekdayName(leave.date.weekday)}, ${DateFormat('dd/MM/yyyy').format(leave.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(children: [
                  Icon(status.icon, size: 14, color: status.color),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      status.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label.copyWith(
                        color: status.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(
                  leave.isRejected && leave.rejectReason?.isNotEmpty == true
                      ? 'Lý do: ${leave.rejectReason!}'
                      : leave.note?.isNotEmpty == true
                          ? leave.note!
                          : 'Nghỉ phép',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(
                    color: leave.isRejected
                        ? AppColors.danger
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Phiếu bị từ chối không có gì để hủy; tài xế có thể gửi lại yêu cầu mới.
          if (!leave.isRejected) ...[
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              onPressed: cancelling ? null : onCancel,
              tooltip: leave.isPending ? 'Rút yêu cầu' : 'Hủy ngày nghỉ',
              icon: cancelling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.close_rounded,
                      color: AppColors.danger,
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyLeaves extends StatelessWidget {
  const _EmptyLeaves();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl3),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.divider.withValues(alpha: .7)),
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AppColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_available_rounded,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Chưa có yêu cầu nghỉ sắp tới',
              style: AppTextStyles.bodyStrong,
            ),
          ],
        ),
      );
}

class _LeaveDay {
  final int id;
  final DateTime date;
  final String? note;

  /// pending = chờ admin duyệt, approved = được nghỉ, rejected = bị từ chối.
  final String status;
  final String? rejectReason;

  const _LeaveDay({
    required this.id,
    required this.date,
    this.note,
    this.status = 'approved',
    this.rejectReason,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory _LeaveDay.fromJson(Map<String, dynamic> json) => _LeaveDay(
        id: (json['id'] as num).toInt(),
        date: DateTime.parse(json['leave_date'] as String),
        note: json['note'] as String?,
        // Backend cũ chưa có trạng thái: mọi phiếu khi đó đều có hiệu lực.
        status: json['status'] as String? ?? 'approved',
        rejectReason: json['reject_reason'] as String?,
      );
}

String _weekdayName(int weekday) => switch (weekday) {
      DateTime.monday => 'Thứ Hai',
      DateTime.tuesday => 'Thứ Ba',
      DateTime.wednesday => 'Thứ Tư',
      DateTime.thursday => 'Thứ Năm',
      DateTime.friday => 'Thứ Sáu',
      DateTime.saturday => 'Thứ Bảy',
      _ => 'Chủ Nhật',
    };
