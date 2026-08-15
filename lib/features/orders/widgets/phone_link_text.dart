import 'package:flutter/material.dart';

import '../../../core/utils/launch_utils.dart';

/// Text hiển thị số điện thoại trong nội dung dạng link bấm gọi được —
/// dùng chung bởi OrderNoteCard (trước đây là 2 bản logic gần như y hệt
/// trong _NoteCard/_NoteRow, chỉ khác style bao quanh).
class PhoneLinkText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const PhoneLinkText({super.key, required this.text, required this.style});

  static final _phoneRegex = RegExp(r'(0\d{8,10})');

  @override
  Widget build(BuildContext context) {
    final matches = _phoneRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(text, style: style);
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;
    for (final m in matches) {
      if (m.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, m.start)));
      }
      final phone = m.group(0)!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: GestureDetector(
          onTap: () => launchPhoneCall(phone),
          child: Text(phone,
              style: style.copyWith(
                color: Colors.blue,
                decoration: TextDecoration.underline,
                decorationColor: Colors.blue,
              )),
        ),
      ));
      lastEnd = m.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    return RichText(text: TextSpan(style: style, children: spans));
  }
}
