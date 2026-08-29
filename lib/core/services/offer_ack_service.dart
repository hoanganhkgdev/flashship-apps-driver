import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// ACK idempotent cho biết chính tiến trình app trên thiết bị đã nhận và xử
/// lý payload offer. Backend vẫn kiểm tra offer đang thuộc đúng tài xế trước
/// khi ghi received_at, nên ACK trễ/cũ không thể làm phát sinh phạt oan.
class OfferAckService {
  static final Set<int> _ackedInProcess = <int>{};

  static Future<void> received(int orderId, {String? receiptUrl}) async {
    if (orderId <= 0 || _ackedInProcess.contains(orderId)) return;

    try {
      final signedUrl = receiptUrl?.trim();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);
      if ((signedUrl == null || signedUrl.isEmpty) &&
          (token == null || token.isEmpty)) {
        return;
      }

      final dio = Dio(BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));
      if (signedUrl != null && signedUrl.isNotEmpty) {
        await dio.post(signedUrl);
      } else {
        await dio.post('/orders/$orderId/receive-offer');
      }
      _ackedInProcess.add(orderId);
    } catch (_) {
      // RTDB và FCM có thể cùng retry. Không đánh dấu local khi request lỗi
      // để nguồn còn lại hoặc lần resume kế tiếp gửi lại được.
    }
  }
}
