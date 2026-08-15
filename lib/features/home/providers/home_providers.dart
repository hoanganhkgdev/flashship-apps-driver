import 'package:flutter_riverpod/flutter_riverpod.dart';

// Dùng chung giữa HomeScreen (shell — bấm tab, khởi tạo quyền GPS/thông báo)
// và DashboardPage (đọc để hiện banner + tự tắt online khi có vấn đề).
final homeTabProvider = StateProvider<int>((ref) => 0);
final notifDeniedProvider = StateProvider<bool>((ref) => false);
// 'service' = GPS tắt, 'permission' = quyền bị từ chối, null = ổn
final locationIssueProvider = StateProvider<String?>((ref) => null);
