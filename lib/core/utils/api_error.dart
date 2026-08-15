import 'package:dio/dio.dart';

/// Đọc message lỗi an toàn từ response backend — ưu tiên `message`, sau đó
/// lỗi validate đầu tiên trong `errors` (kiểu Laravel:
/// `{"errors": {"phone": ["..."]}}`), cuối cùng mới dùng [fallback]. Gộp về
/// 1 chỗ dùng chung cho mọi API call trong app — trước đây mỗi màn tự viết
/// lại logic này, chỉ bản ở forgot_password_screen đọc `errors`, các màn
/// khác (login/register/otp) hiện message chung chung dù backend đã trả
/// lỗi cụ thể.
String parseApiError(
  Object e, {
  String fallback = 'Có lỗi xảy ra. Vui lòng thử lại.',
}) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty && first.first is String) {
          return first.first as String;
        }
      }
    }
  }
  return fallback;
}
