import 'package:flutter/material.dart';

class TwoLinesScaledText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final int maxLines;
  final double minFontSize;

  const TwoLinesScaledText({
    super.key,
    required this.text,
    required this.style,
    this.textAlign = TextAlign.start,
    this.maxLines = 2,
    this.minFontSize = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        double currentFontSize = style.fontSize ?? 14.0;

        while (currentFontSize >= minFontSize) {
          final testStyle = style.copyWith(fontSize: currentFontSize);
          final textPainter = TextPainter(
            text: TextSpan(text: text, style: testStyle),
            textDirection: TextDirection.ltr,
            maxLines: maxLines,
          )..layout(maxWidth: maxWidth);

          if (!textPainter.didExceedMaxLines) {
            break;
          }
          currentFontSize -= 1.0;
        }

        return Text(
          text,
          style: style.copyWith(fontSize: currentFontSize),
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
