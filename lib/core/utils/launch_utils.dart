import 'dart:io';

import 'package:offer_overlay/offer_overlay.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../providers/app_container.dart';

/// Gọi điện thoại — gộp lại vì logic `Uri.parse('tel:...')` + guard
/// `canLaunchUrl` bị lặp lại ở nhiều nơi (pending_screen, active_order_screen,
/// batch_stops_card, phone_link_text).
Future<void> launchPhoneCall(String phone) async {
  final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (normalized.isEmpty) return;
  final uri = Uri(scheme: 'tel', path: normalized);
  // Gọi launch trực tiếp: canLaunchUrl có thể trả false trên ROM tùy biến dù
  // trình quay số vẫn xử lý được intent. launchUrl tự trả kết quả chính xác.
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Mở một đường dẫn trong ghi chú (vd. link Google Maps) bằng app/trình duyệt
/// ngoài — link Google Maps sẽ mở thẳng app Google Maps nếu máy có cài.
Future<void> launchLink(String raw) async {
  var url = raw.trim().replaceAll(RegExp(r'[.,;:!?)\]]+$'), '');
  if (url.isEmpty) return;
  if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(url)) {
    url = 'https://$url';
  }
  final uri = Uri.tryParse(url);
  // Ghi chú do khách/shop nhập (không tin được): chỉ mở web, không mở
  // intent://, sms:, hay đường dẫn kích hoạt app khác.
  if (uri == null || !const {'http', 'https'}.contains(uri.scheme)) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> launchNavigation({
  double? lat,
  double? lng,
  String? address,
}) async {
  final destination =
      lat != null && lng != null ? '$lat,$lng' : address?.trim() ?? '';
  if (destination.isEmpty) return;

  // Tài xế xe máy dùng chỉ đường xe máy của Google Maps (đường đi, thời gian
  // khác ô tô). Chỉ tài xế đăng ký ô tô mới dùng chế độ ô tô.
  final twoWheeler = appContainer.read(authProvider).user?.vehicleType != 'car';

  if (Platform.isAndroid &&
      await OfferOverlay.googleMaps(destination, twoWheeler: twoWheeler)) {
    return;
  }

  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': destination,
    'travelmode': twoWheeler ? 'two-wheeler' : 'driving',
  });
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
