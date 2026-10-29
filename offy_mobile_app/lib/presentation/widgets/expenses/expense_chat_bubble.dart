import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/log_note_model.dart';

class ExpenseChatBubble extends StatelessWidget {
  final LogNoteModel log;
  final bool isSelected;
  final bool showSenderName;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ExpenseChatBubble({
    super.key,
    required this.log,
    this.isSelected = false,
    this.showSenderName = true,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = log.isUser ?? false;

    // Time string formatting (e.g. 10:45 AM)
    final timeDisplay = log.timeDisplay;
    final String timeStr;
    if (timeDisplay != null && timeDisplay.isNotEmpty) {
      timeStr = timeDisplay;
    } else if (log.timestamp != null) {
      final ts = log.timestamp!;
      final hour = ts.hour % 12 == 0 ? 12 : ts.hour % 12;
      final minute = ts.minute.toString().padLeft(2, '0');
      final period = ts.hour >= 12 ? 'PM' : 'AM';
      timeStr = '$hour:$minute $period';
    } else {
      timeStr = '';
    }

    final bubbleBg = isUser
        ? AppColors.main
        : (isDark ? const Color(0xFF2A1605) : const Color(0xFFF3E9E0));

    final rowSelectionBg = isSelected
        ? (isDark
            ? AppColors.main.withValues(alpha: 0.28)
            : AppColors.main.withValues(alpha: 0.15))
        : Colors.transparent;

    final textColor = isUser
        ? Colors.white
        : (isDark ? const Color(0xFFF3E9E0) : AppColors.black);

    final subTextColor = isUser
        ? const Color.fromRGBO(255, 255, 255, 0.75)
        : (isDark ? const Color(0xFFA49D95) : const Color(0xFF6B7280));

    final senderName = log.senderName ?? '';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: isUser ? onLongPress : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        color: rowSelectionBg,
        padding: EdgeInsets.symmetric(
          horizontal: 14.w,
          vertical: showSenderName ? 3.h : 1.5.h,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender name tag (only rendered if showSenderName is true and senderName is not empty)
            if (showSenderName && senderName.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                child: Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFFA49D95)
                        : const Color(0xFF8C8479),
                  ),
                ),
              ),
            ],

            // Compact Chat Bubble Body
            Material(
              color: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(maxWidth: 280.w),
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: bubbleBg,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12.r),
                    topRight: Radius.circular(12.r),
                    bottomLeft: Radius.circular(isUser ? 12.r : 2.r),
                    bottomRight: Radius.circular(isUser ? 2.r : 12.r),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (log.tracking.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: log.isTrackingOnly ? 0 : 6.h,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final change in log.tracking)
                              Padding(
                                padding: EdgeInsets.only(bottom: 2.h),
                                child: Text(
                                  change.display,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w400,
                                    height: 1.3,
                                    fontStyle: FontStyle.italic,
                                    color: subTextColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 8.w,
                      runSpacing: 2.h,
                      children: [
                        if (!log.isTrackingOnly)
                          Text(
                            log.message ?? '',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w400,
                              height: 1.3,
                              color: textColor,
                            ),
                          ),
                        if (timeStr.isNotEmpty)
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w400,
                              color: subTextColor,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
