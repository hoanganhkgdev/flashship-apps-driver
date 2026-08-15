import 'package:url_launcher/url_launcher.dart';

/// Gọi điện thoại — gộp lại vì logic `Uri.parse('tel:...')` + guard
/// `canLaunchUrl` bị lặp lại ở nhiều nơi (pending_screen, active_order_screen,
/// batch_stops_card, phone_link_text).
Future<void> launchPhoneCall(String phone) async {
  final uri = Uri.parse('tel:$phone');
  if (await canLaunchUrl(uri)) launchUrl(uri);
}

/// Mở 1 URI bất kỳ đã dựng sẵn (tel/mailto/https...) — dùng cho các kênh
/// liên hệ động (SupportItem.uri) không biết trước scheme là gì.
Future<void> launchExternal(Uri uri) async {
  if (await canLaunchUrl(uri)) launchUrl(uri);
}
