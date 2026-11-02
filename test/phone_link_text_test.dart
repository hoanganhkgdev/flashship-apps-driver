import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flashship_driver/features/orders/widgets/phone_link_text.dart';

void main() {
  testWidgets('phone numbers and map links become tappable', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PhoneLinkText(
          text: 'Gọi 0901234567 rồi xem https://maps.app.goo.gl/abc123 nhé',
          style: TextStyle(fontSize: 14),
        ),
      ),
    ));
    expect(find.text('0901234567'), findsOneWidget);
    expect(find.text('Mở liên kết'), findsOneWidget);
  });
}
