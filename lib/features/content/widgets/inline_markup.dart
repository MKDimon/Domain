import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class InlineMarkupText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const InlineMarkupText({super.key, required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    final defaultStyle = style ?? Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final spans = _parse(text, defaultStyle, Theme.of(context).colorScheme.primary);
    return Text.rich(TextSpan(children: spans));
  }

  static List<InlineSpan> _parse(String text, TextStyle base, Color linkColor) {
    final spans = <InlineSpan>[];
    final regex = RegExp(
      r'\*\*(.+?)\*\*'      // bold
      r'|__(.+?)__'          // bold alt
      r'|\*(.+?)\*'          // italic
      r'|_(.+?)_'            // italic alt
      r'|~~(.+?)~~'          // strikethrough
      r'|`(.+?)`'            // inline code
      r'|\[([^\]]+)\]\(([^)]+)\)', // link
    );

    var lastEnd = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: base));
      }

      if (match.group(1) != null || match.group(2) != null) {
        spans.add(TextSpan(text: match.group(1) ?? match.group(2), style: base.copyWith(fontWeight: FontWeight.bold)));
      } else if (match.group(3) != null || match.group(4) != null) {
        spans.add(TextSpan(text: match.group(3) ?? match.group(4), style: base.copyWith(fontStyle: FontStyle.italic)));
      } else if (match.group(5) != null) {
        spans.add(TextSpan(text: match.group(5), style: base.copyWith(decoration: TextDecoration.lineThrough)));
      } else if (match.group(6) != null) {
        spans.add(TextSpan(
          text: match.group(6),
          style: base.copyWith(fontFamily: 'monospace', backgroundColor: base.color?.withValues(alpha: 0.08)),
        ));
      } else if (match.group(7) != null && match.group(8) != null) {
        final linkText = match.group(7)!;
        final url = match.group(8)!;
        spans.add(TextSpan(
          text: linkText,
          style: base.copyWith(color: linkColor, decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()..onTap = () => launchUrl(Uri.parse(url)),
        ));
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: base));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: base));
    }

    return spans;
  }
}
