import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';

class AppHtmlContentViewer extends StatelessWidget {
  final String htmlContent;

  const AppHtmlContentViewer({
    super.key,
    required this.htmlContent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return HtmlWidget(
      htmlContent,
      textStyle: TextStyle(
        fontSize: 14.sp,
        height: 1.5,
        color: isDark ? AppColors.white : AppColors.black,
      ),
      customStylesBuilder: (element) {
        final styles = <String, String>{};

        final styleAttr = element.attributes['style'];
        if (styleAttr != null && styleAttr.isNotEmpty) {
          for (final pair in styleAttr.split(';')) {
            final parts = pair.split(':');
            if (parts.length == 2) {
              styles[parts[0].trim().toLowerCase()] = parts[1].trim();
            }
          }
        }

        if (element.localName == 'a') {
          styles['text-decoration'] = 'none';

          if (!styles.containsKey('color')) {
            var ancestor = element.parent;
            while (ancestor != null) {
              final ancestorStyle = ancestor.attributes['style'];
              if (ancestorStyle != null && ancestorStyle.isNotEmpty) {
                for (final pair in ancestorStyle.split(';')) {
                  final parts = pair.split(':');
                  if (parts.length == 2 &&
                      parts[0].trim().toLowerCase() == 'color') {
                    styles['color'] = parts[1].trim();
                    break;
                  }
                }
              }
              if (styles.containsKey('color')) break;
              ancestor = ancestor.parent;
            }
          }
        }

        return styles.isNotEmpty ? styles : null;
      },
      onTapUrl: (url) async {
        final uri = Uri.parse(url);
        try {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {
          return false;
        }
      },
    );
  }
}
