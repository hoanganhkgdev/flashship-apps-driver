import 'package:flutter/material.dart';

import '../../../core/utils/launch_utils.dart';

/// Text hiển thị số điện thoại (bấm để gọi) và đường dẫn, kể cả link Google
/// Maps (bấm để mở) trong nội dung — dùng chung bởi OrderNoteCard (trước đây là 2 bản logic gần như y hệt
/// trong _NoteCard/_NoteRow, chỉ khác style bao quanh).
class PhoneLinkText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const PhoneLinkText({super.key, required this.text, required this.style});

  // Link (http/https hoặc link Google Maps rút gọn không có http) hoặc số điện thoại.
  static final _linkOrPhoneRegex = RegExp(
    r'(https?://[^\s]+|(?:www\.)?(?:maps\.app\.goo\.gl|goo\.gl/maps|maps\.google\.[a-z.]+|google\.[a-z.]+/maps)[^\s]*|0\d{8,10})',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final matches = _linkOrPhoneRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(text, style: style);
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;
    for (final m in matches) {
      if (m.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, m.start)));
      }
      final token = m.group(0)!;
      final isPhone = RegExp(r'^0\d{8,10}$').hasMatch(token);
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: GestureDetector(
          onTap: () => isPhone ? launchPhoneCall(token) : launchLink(token),
          child: Text(isPhone ? token : 'Mở liên kết',
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
