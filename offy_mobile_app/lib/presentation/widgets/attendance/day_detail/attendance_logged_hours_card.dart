import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/attendance_log_response_model.dart';
import '../../../../l10n/app_localizations.dart';
import 'attendance_circular_progress.dart';

class AttendanceLoggedHoursCard extends StatelessWidget {
  final AttendanceLogEntryModel log;

  const AttendanceLoggedHoursCard({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxTargetTextWidth = constraints.maxWidth.isFinite
            ? (constraints.maxWidth / 2)
            : 167.w;

        return Container(
          padding: EdgeInsets.fromLTRB(20.w, 13.h, 14.74.w, 13.h),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.white,
            border: Border.all(
              color: isDark ? const Color(0xFF4A3423) : const Color(0xFFFAE1C9),
              width: 1.w,
            ),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Info Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loc?.loggedHours ?? 'LOGGED HOURS',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.5,
                        color: isDark
                            ? AppColors.white.withValues(alpha: 0.7)
                            : AppColors.tertiary,
                        height: 16 / 12,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          log.loggedHours,
                          style: GoogleFonts.inter(
                            fontSize: 32.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.64,
                            color: isDark ? AppColors.white : AppColors.black,
                            height: 40 / 32,
                          ),
                        ),
                        Text(
                          'h ',
                          style: GoogleFonts.inter(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.64,
                            color: isDark
                                ? AppColors.white.withValues(alpha: 0.75)
                                : AppColors.tertiary,
                            height: 28 / 20,
                          ),
                        ),
                        Text(
                          log.loggedMinutes,
                          style: GoogleFonts.inter(
                            fontSize: 32.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.64,
                            color: isDark ? AppColors.white : AppColors.black,
                            height: 40 / 32,
                          ),
                        ),
                        Text(
                          'm',
                          style: GoogleFonts.inter(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.64,
                            color: isDark
                                ? AppColors.white.withValues(alpha: 0.75)
                                : AppColors.tertiary,
                            height: 28 / 20,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    // Target & Completion Text
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxTargetTextWidth),
                      child: Builder(
                        builder: (context) {
                          final trimmedTarget = log.targetDuration?.trim();
                          final bool hasTarget = trimmedTarget != null &&
                              trimmedTarget.isNotEmpty &&
                              trimmedTarget != '-' &&
                              trimmedTarget != '00h 00m' &&
                              trimmedTarget != '0h 0m' &&
                              trimmedTarget != '00h 00' &&
                              trimmedTarget != '0h' &&
                              trimmedTarget != '0';

                          final String displayText;
                          if (hasTarget) {
                            final targetPrefix = loc?.target ?? 'Target';
                            final targetText = log.targetHoursText;
                            final completionText = log.completionPercentageText;
                            displayText = completionText != null
                                ? '$targetPrefix: $targetText • $completionText'
                                : '$targetPrefix: $targetText';
                          } else {
                            final hasReasonMessage =
                                log.targetReasonMessage != null &&
                                    log.targetReasonMessage!.trim().isNotEmpty;
                            displayText = hasReasonMessage
                                ? 'No Target • ${log.targetReasonMessage!.trim()}'
                                : 'No Target';
                          }

                          TextStyle styleFor(double fontSize) =>
                              GoogleFonts.inter(
                                fontSize: fontSize,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppColors.white.withValues(alpha: 0.75)
                                    : AppColors.tertiary,
                                height: 18 / 13,
                              );

                          if (maxTargetTextWidth <= 0 ||
                              maxTargetTextWidth.isInfinite) {
                            return Text(
                              displayText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: styleFor(13.sp),
                            );
                          }

                          final textDirection = Directionality.of(context);
                          bool fitsWithinLines(double fontSize, int maxLines) {
                            final tp = TextPainter(
                              text: TextSpan(
                                text: displayText,
                                style: styleFor(fontSize),
                              ),
                              textDirection: textDirection,
                              maxLines: maxLines,
                            )..layout(maxWidth: maxTargetTextWidth);
                            return !tp.didExceedMaxLines;
                          }

                          // 1. Fits within 2 lines at default 13.sp
                          if (fitsWithinLines(13.sp, 2)) {
                            return Text(
                              displayText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: styleFor(13.sp),
                            );
                          }

                          // 2. Fits within 2 lines at 12.sp (-1 size)
                          if (fitsWithinLines(12.sp, 2)) {
                            return Text(
                              displayText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: styleFor(12.sp),
                            );
                          }

                          // 3. Fallback: -2 sizes down (11.sp) with ellipsis if still overflowing
                          return Text(
                            displayText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: styleFor(11.sp),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              // Right: Circular Progress Ring
              AttendanceCircularProgress(
                progress: log.completionProgress ?? 0.0,
                isCompleted: (log.completionProgress ?? 0.0) >= 1.0,
              ),
            ],
          ),
        );
      },
    );
  }
}
