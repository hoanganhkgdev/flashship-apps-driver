import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Container Riverpod dùng chung cho cả app (gắn vào cây widget qua
/// UncontrolledProviderScope trong main.dart).
///
/// Dành cho code chạy ngoài vòng đời widget — listener FCM, bấm thông báo —
/// để không phải giữ `WidgetRef` của một màn hình có thể đã bị huỷ.
final appContainer = ProviderContainer();
