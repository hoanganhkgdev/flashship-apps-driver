import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/shift_model.dart';

class ShiftActionResult {
  final bool success;
  final String? message;
  final String? code;
  const ShiftActionResult({required this.success, this.message, this.code});
}

class ShiftState {
  final List<ShiftModel> shifts;
  final List<int> currentShiftIds;
  final ShiftChangeRequestModel? changeRequest;
  final bool loading;
  final bool submitting;
  // "loading == false" đúng cả lúc CHƯA từng fetch lẫn lúc fetch XONG — 2
  // trạng thái đó không phân biệt được. Cờ riêng này chỉ true sau khi fetch()
  // chạy xong lần đầu (dù thành công hay lỗi), dùng để đồng bộ lựa chọn ban
  // đầu ở màn hình đúng 1 lần, đúng lúc.
  final bool hasLoadedOnce;
  // true khi lần fetch() gần nhất lỗi (mất mạng, API lỗi...) — để UI phân
  // biệt với trường hợp khu vực THẬT SỰ chưa có ca nào được thiết lập
  // (2 trường hợp trước đây trả về cùng 1 danh sách rỗng, hiện y hệt nhau).
  final bool loadError;

  const ShiftState({
    this.shifts           = const [],
    this.currentShiftIds  = const [],
    this.changeRequest,
    this.loading          = false,
    this.submitting       = false,
    this.hasLoadedOnce    = false,
    this.loadError        = false,
  });

  bool get isRegistered => currentShiftIds.isNotEmpty;
  bool get hasPendingChangeRequest => changeRequest?.isPending ?? false;

  ShiftState copyWith({
    List<ShiftModel>? shifts,
    List<int>? currentShiftIds,
    ShiftChangeRequestModel? changeRequest,
    bool resetChangeRequest = false,
    bool? loading,
    bool? submitting,
    bool? hasLoadedOnce,
    bool? loadError,
  }) => ShiftState(
        shifts:          shifts          ?? this.shifts,
        currentShiftIds: currentShiftIds ?? this.currentShiftIds,
        changeRequest: resetChangeRequest
            ? null
            : (changeRequest ?? this.changeRequest),
        loading:       loading       ?? this.loading,
        submitting:    submitting    ?? this.submitting,
        hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
        loadError:     loadError     ?? this.loadError,
      );
}

class ShiftNotifier extends StateNotifier<ShiftState> {
  final Ref _ref;
  ShiftNotifier(this._ref) : super(const ShiftState());

  Future<void> fetch() async {
    state = state.copyWith(loading: true);
    try {
      final res  = await _ref.read(apiClientProvider).get('/driver/shifts');
      final list = (res.data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final ids  = (res.data['current_shift_ids'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [];
      state = state.copyWith(
        shifts:          list.map(ShiftModel.fromJson).toList(),
        currentShiftIds: ids,
        loading:         false,
        hasLoadedOnce:   true,
        loadError:       false,
      );
    } catch (_) {
      state = state.copyWith(loading: false, hasLoadedOnce: true, loadError: true);
    }
    await fetchChangeRequestStatus();
  }

  Future<void> fetchChangeRequestStatus() async {
    try {
      final res  = await _ref.read(apiClientProvider)
          .get('/driver/shifts/change-request/status');
      final data = res.data['data'] as Map<String, dynamic>?;
      state = state.copyWith(
        changeRequest: data != null ? ShiftChangeRequestModel.fromJson(data) : null,
        resetChangeRequest: data == null,
      );
    } catch (_) {}
  }

  Future<ShiftActionResult> selectShift(List<int> shiftIds) async {
    state = state.copyWith(submitting: true);
    try {
      final res = await _ref.read(apiClientProvider)
          .post('/driver/shifts/select', data: {'shift_ids': shiftIds});
      state = state.copyWith(submitting: false, currentShiftIds: shiftIds);
      return ShiftActionResult(success: true, message: res.data['message'] as String?);
    } on DioException catch (e) {
      state = state.copyWith(submitting: false);
      final data = e.response?.data;
      return ShiftActionResult(
        success: false,
        message: (data is Map ? data['message'] as String? : null) ?? 'Đăng ký ca thất bại',
        code:    (data is Map ? data['code'] as String? : null),
      );
    } catch (_) {
      state = state.copyWith(submitting: false);
      return const ShiftActionResult(success: false, message: 'Đã xảy ra lỗi. Thử lại sau.');
    }
  }

  Future<ShiftActionResult> submitChangeRequest(List<int> shiftIds) async {
    state = state.copyWith(submitting: true);
    try {
      final res = await _ref.read(apiClientProvider)
          .post('/driver/shifts/change-request', data: {'shift_ids': shiftIds});
      state = state.copyWith(submitting: false);
      await fetchChangeRequestStatus();
      return ShiftActionResult(success: true, message: res.data['message'] as String?);
    } on DioException catch (e) {
      state = state.copyWith(submitting: false);
      final data = e.response?.data;
      return ShiftActionResult(
        success: false,
        message: (data is Map ? data['message'] as String? : null) ?? 'Gửi yêu cầu thất bại',
      );
    } catch (_) {
      state = state.copyWith(submitting: false);
      return const ShiftActionResult(success: false, message: 'Đã xảy ra lỗi. Thử lại sau.');
    }
  }
}

final shiftProvider = StateNotifierProvider<ShiftNotifier, ShiftState>(
  (ref) => ShiftNotifier(ref),
);
