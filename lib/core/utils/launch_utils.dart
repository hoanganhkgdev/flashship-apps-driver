import 'package:url_launcher/url_launcher.dart';

/// Gọi điện thoại — gộp lại vì logic `Uri.parse('tel:...')` + guard
/// `canLaunchUrl` bị lặp lại ở nhiều nơi (pending_screen, active_order_screen,
/// batch_stops_card, phone_link_text).
Future<void> launchPhoneCall(String phone) async {
  final uri = Uri.parse('tel:$phone');
  if (await canLaunchUrl(uri)) launchUrl(uri);
}
