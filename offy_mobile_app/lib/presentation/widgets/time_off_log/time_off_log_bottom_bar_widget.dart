import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import 'time_off_log_send_icon_widget.dart';

class TimeOffLogBottomBarWidget extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onAddAttachment;

  const TimeOffLogBottomBarWidget({
    super.key,
    required this.controller,
    required this.onSend,
    this.onAddAttachment,
  });

  @override
  State<TimeOffLogBottomBarWidget> createState() =>
      _TimeOffLogBottomBarWidgetState();
}

class _TimeOffLogBottomBarWidgetState extends State<TimeOffLogBottomBarWidget> {
  int _lineCount = 1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateLineCount);
  }

  @override
  void didUpdateWidget(covariant TimeOffLogBottomBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_updateLineCount);
      widget.controller.addListener(_updateLineCount);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateLineCount);
    super.dispose();
  }

  void _updateLineCount() {
    final text = widget.controller.text;
    if (text.isEmpty) {
      if (_lineCount != 1) {
        setState(() => _lineCount = 1);
      }
      return;
    }

    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      maxLines: 3,
      textDirection: TextDirection.ltr,
    );

    // Approximate width available for text inside input box
    final maxTextWidth = 270.w - 32.w;
    textPainter.layout(maxWidth: maxTextWidth > 0 ? maxTextWidth : 200);
    final count = textPainter.computeLineMetrics().length.clamp(1, 3);

    if (_lineCount != count) {
      setState(() {
        _lineCount = count;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double radius = 62.r;
    EdgeInsets padding = EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h);

    if (_lineCount == 2) {
      radius = 24.r;
      padding = EdgeInsets.symmetric(horizontal: 20.w, vertical: 5.h);
    } else if (_lineCount >= 3) {
      radius = 12.r;
      padding = EdgeInsets.symmetric(horizontal: 27.w, vertical: 6.h);
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.midLight,
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attachment Plus Button (Rectangle 1295 left)
              GestureDetector(
                onTap: widget.onAddAttachment,
                child: Container(
                  width: 46.w,
                  height: 46.h,
                  decoration: const BoxDecoration(
                    color: AppColors.navColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.add,
                    color: AppColors.white,
                    size: 24.r,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              // Dynamic Message Input Field (Rectangle 1294)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  constraints: BoxConstraints(minHeight: 46.h),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBg : AppColors.white,
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: isDark ? AppColors.darkNav : AppColors.shade,
                      width: 1.0,
                    ),
                  ),
                  padding: padding,
                  alignment: Alignment.centerLeft,
                  child: TextField(
                    controller: widget.controller,
                    minLines: 1,
                    maxLines: 3,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText:
                          AppLocalizations.of(context)?.typeAMessage ??
                          'Type a message...',
                      hintStyle: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                        height: 20 / 14,
                        color: AppColors.navColor,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      height: 20 / 14,
                      color: isDark ? AppColors.white : const Color(0xFF252525),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              // Action / Send Button (Rectangle 1295 right)
              GestureDetector(
                onTap: widget.onSend,
                child: Container(
                  width: 46.w,
                  height: 46.h,
                  decoration: const BoxDecoration(
                    color: AppColors.main,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: TimeOffLogSendIconWidget(
                    size: 20.r,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
