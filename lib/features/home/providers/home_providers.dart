import 'package:flutter_riverpod/flutter_riverpod.dart';

// Dùng chung giữa HomeScreen (shell — bấm tab, khởi tạo quyền GPS/thông báo)
// và DashboardPage (đọc để hiện banner + tự tắt online khi có vấn đề).
final homeTabProvider = StateProvider<int>((ref) => 0);

// Không điều hướng thẳng bằng index khi mở Chợ đơn từ notification. Tab này
// chỉ tồn tại ở khu vực self-pick, nên index 1 có thể đang là Lịch sử trong
// lúc cấu hình khu vực chưa tải xong. HomeScreen sẽ xử lý yêu cầu sau khi
// backend xác nhận Chợ đơn đang bật.
final orderMarketTabRequestedProvider = StateProvider<bool>((ref) => false);
final notifDeniedProvider = StateProvider<bool>((ref) => false);
// 'service' = GPS tắt, 'permission' = quyền bị từ chối, null = ổn
final locationIssueProvider = StateProvider<String?>((ref) => null);
