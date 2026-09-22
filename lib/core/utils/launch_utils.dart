import 'dart:io';

import 'package:offer_overlay/offer_overlay.dart';
import 'package:url_launcher/url_launcher.dart';

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

Future<void> launchNavigation({
  double? lat,
  double? lng,
  String? address,
}) async {
  final destination =
      lat != null && lng != null ? '$lat,$lng' : address?.trim() ?? '';
  if (destination.isEmpty) return;

  if (Platform.isAndroid && await OfferOverlay.googleMaps(destination)) {
    return;
  }

  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': destination,
    'travelmode': 'driving',
  });
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
