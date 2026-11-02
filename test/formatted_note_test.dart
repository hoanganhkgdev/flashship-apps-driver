import 'package:flashship_driver/features/orders/widgets/formatted_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('formats the call-center delivery note', (tester) async {
    const note = '''Điểm lấy đơn: 11 Lý Thường Kiệt
☎️ 0942526271

Điểm giao đơn: 355 Nguyễn Trung Trực
☎️ 0942373073

Phí ship: 15''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormattedNote(
            note: note,
            style: TextStyle(fontSize: 14),
          ),
        ),
      ),
    );

    expect(find.text('ĐIỂM LẤY ĐƠN'), findsOneWidget);
    expect(find.text('ĐIỂM GIAO ĐƠN'), findsOneWidget);
    expect(find.text('PHÍ SHIP'), findsOneWidget);
    expect(find.text('0942526271'), findsOneWidget);
    expect(find.text('0942373073'), findsOneWidget);
    expect(find.text('15.000 đ'), findsOneWidget);
    expect(find.textContaining('☎'), findsNothing);
  });

  testWidgets('hides the missing delivery instruction added by call center',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormattedNote(
            note: '[Chưa có điểm giao — hỏi shop khi lấy hàng] Mang 2 phần cơm',
            style: TextStyle(fontSize: 14),
          ),
        ),
      ),
    );

    expect(find.textContaining('Chưa có điểm giao'), findsNothing);
    expect(find.textContaining('hỏi shop'), findsNothing);
    expect(find.text('Mang 2 phần cơm'), findsOneWidget);
  });

  testWidgets('hides the missing delivery instruction from shopping notes',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormattedNote(
            note:
                '[Chưa có điểm giao — liên hệ khách để bổ sung] Mua một phần cơm',
            style: TextStyle(fontSize: 14),
          ),
        ),
      ),
    );

    expect(find.textContaining('Chưa có điểm giao'), findsNothing);
    expect(find.textContaining('liên hệ khách để bổ sung'), findsNothing);
    expect(find.text('Mua một phần cơm'), findsOneWidget);
  });

  testWidgets('formats the call-center shopping note', (tester) async {
    const note =
        '''MUA HỘ - GỌI KHÁCH: Hộp cơm gà xối mỡ lấy đùi chiên nước mắm ở huỳnh trân 3/2
Điểm Giao: dãy trọ paradise phòng 16
Ship: 15
☎️ 0898416718''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormattedNote(
            note: note,
            style: TextStyle(fontSize: 14),
          ),
        ),
      ),
    );

    expect(find.text('MUA HỘ - GỌI KHÁCH'), findsOneWidget);
    expect(
      find.text('Hộp cơm gà xối mỡ lấy đùi chiên nước mắm ở huỳnh trân 3/2'),
      findsOneWidget,
    );
    expect(find.text('ĐIỂM GIAO'), findsOneWidget);
    expect(find.text('dãy trọ paradise phòng 16'), findsOneWidget);
    expect(find.text('SHIP'), findsOneWidget);
    expect(find.text('15.000 đ'), findsOneWidget);
    expect(find.text('0898416718'), findsOneWidget);
    expect(find.textContaining('☎'), findsNothing);
  });

  testWidgets('formats the call-center bike note written on one line',
      (tester) async {
    const note =
        'Điểm Rước: 48 Lạc Long Quân Điểm Đến: chung cư sophia Tiền Xe: 35 ☎️  0944424964';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormattedNote(
            note: note,
            style: TextStyle(fontSize: 14),
          ),
        ),
      ),
    );

    expect(find.text('ĐIỂM RƯỚC'), findsOneWidget);
    expect(find.text('48 Lạc Long Quân'), findsOneWidget);
    expect(find.text('ĐIỂM ĐẾN'), findsOneWidget);
    expect(find.text('chung cư sophia'), findsOneWidget);
    expect(find.text('TIỀN XE'), findsOneWidget);
    expect(find.text('35.000 đ'), findsOneWidget);
    expect(find.text('0944424964'), findsOneWidget);
    expect(find.textContaining('☎'), findsNothing);
  });

  testWidgets('formats the call-center motor driving note', (tester) async {
    const note =
        'Lái Hộ Xe Máy: Bê Thui Đất Việt Về: 123 Nguyễn Trung Trực Cước: 70 ☎️ 0909383999';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormattedNote(
            note: note,
            style: TextStyle(fontSize: 14),
          ),
        ),
      ),
    );

    expect(find.text('LÁI HỘ XE MÁY'), findsOneWidget);
    expect(find.text('Bê Thui Đất Việt'), findsOneWidget);
    expect(find.text('VỀ'), findsOneWidget);
    expect(find.text('123 Nguyễn Trung Trực'), findsOneWidget);
    expect(find.text('CƯỚC'), findsOneWidget);
    expect(find.text('70.000 đ'), findsOneWidget);
    expect(find.text('0909383999'), findsOneWidget);
    expect(find.textContaining('☎'), findsNothing);
  });

  testWidgets('formats the call-center car driving note', (tester) async {
    const note =
        'Lái Xe Ô Tô: Bê Thui Đất Việt Về: 123 Nguyễn Trung Trực Cước: 100 ☎️ 0909383999';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormattedNote(
            note: note,
            style: TextStyle(fontSize: 14),
          ),
        ),
      ),
    );

    expect(find.text('LÁI XE Ô TÔ'), findsOneWidget);
    expect(find.text('Bê Thui Đất Việt'), findsOneWidget);
    expect(find.text('VỀ'), findsOneWidget);
    expect(find.text('123 Nguyễn Trung Trực'), findsOneWidget);
    expect(find.text('CƯỚC'), findsOneWidget);
    expect(find.text('100.000 đ'), findsOneWidget);
    expect(find.text('0909383999'), findsOneWidget);
    expect(find.textContaining('☎'), findsNothing);
  });

  testWidgets('formats the call-center top-up note', (tester) async {
    const note =
        'Nạp Tiền: 2 triệu Điểm Nạp: 113 Nguyễn Thị Định Phí: 20 ☎️ 0947333595';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormattedNote(
            note: note,
            style: TextStyle(fontSize: 14),
          ),
        ),
      ),
    );

    expect(find.text('NẠP TIỀN'), findsOneWidget);
    expect(find.text('2.000.000 đ'), findsOneWidget);
    expect(find.text('ĐIỂM NẠP'), findsOneWidget);
    expect(find.text('113 Nguyễn Thị Định'), findsOneWidget);
    expect(find.text('PHÍ'), findsOneWidget);
    expect(find.text('20.000 đ'), findsOneWidget);
    expect(find.text('0947333595'), findsOneWidget);
    expect(find.textContaining('☎'), findsNothing);
  });
}
