import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

/// Persistent inline error for form failures. Use instead of a snackbar, which a route change can
/// dismiss before it is seen. Renders nothing when [message] is null or empty.
class InlineErrorBanner extends StatelessWidget {
  const InlineErrorBanner({
    super.key,
    required this.message,
    this.onDismiss,
  });

  /// The message to display. Null or empty renders an empty box.
  final String? message;

  /// Optional dismiss handler. When null, no close affordance is shown.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null || text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      liveRegion: true,
      container: true,
      label: 'Error: $text',
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: isDark ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: AppColors.red.withValues(alpha: isDark ? 0.55 : 0.35),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 18.sp, color: AppColors.red),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13.sp,
                  height: 18 / 13,
                  letterSpacing: 0.2,
                  color: AppColors.red,
                ),
              ),
            ),
            if (onDismiss != null) ...[
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: onDismiss,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  // Pads the 16sp glyph out to the 44x44pt iOS minimum.
                  padding: EdgeInsets.all(8.w),
                  child: Icon(Icons.close, size: 16.sp, color: AppColors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
