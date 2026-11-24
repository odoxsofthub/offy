import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/attendance_log_response_model.dart';

class AttendanceTimelineItem extends StatelessWidget {
  final AttendanceTimelineSessionModel session;
  final bool isLast;

  const AttendanceTimelineItem({
    super.key,
    required this.session,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCheckIn = session.type == AttendanceSessionType.checkIn;

    final Color circleBg = isCheckIn ? const Color(0xFFFFB5A0) : const Color(0xFFB02F00);
    final Color iconColor = isCheckIn ? const Color(0xFF3B0900) : AppColors.white;
    final String title = isCheckIn ? 'Check-In' : 'Check-Out';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Circle node + Connecting line
          SizedBox(
            width: 32.w,
            child: Column(
              children: [
                // Circular Indicator Node
                Container(
                  width: 32.w,
                  height: 32.w,
                  decoration: BoxDecoration(
                    color: circleBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFB02F00).withValues(alpha: 0.3),
                        offset: Offset(0, 2.h),
                        blurRadius: 8.r,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
                      size: 14.sp,
                      color: iconColor,
                    ),
                  ),
                ),
                // Vertical connecting line to next item
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.w,
                      color: isDark
                          ? const Color(0xFF5E4230)
                          : const Color(0xFFD3B599),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          // Right Column: Event Detail Card
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0.0 : 24.h),
              child: Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.white,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Row: Title & Time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.white : AppColors.black,
                            height: 20 / 14,
                          ),
                        ),
                        Text(
                          session.time,
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFB02F00),
                            height: 20 / 14,
                          ),
                        ),
                      ],
                    ),
                    if (session.location != null &&
                        session.location!.trim().isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      // Bottom Row: Location
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            AppAssets.headquarters,
                            width: 9.w,
                            height: 12.h,
                            fit: BoxFit.contain,
                            colorFilter: ColorFilter.mode(
                              isDark
                                  ? AppColors.white.withValues(alpha: 0.75)
                                  : AppColors.tertiary,
                              BlendMode.srcIn,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Flexible(
                            child: Text(
                              session.location!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppColors.white.withValues(alpha: 0.75)
                                    : AppColors.tertiary,
                                height: 18 / 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
