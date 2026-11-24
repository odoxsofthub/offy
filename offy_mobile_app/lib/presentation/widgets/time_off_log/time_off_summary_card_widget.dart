import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class TimeOffSummaryCardWidget extends StatefulWidget {
  final String dateRange;
  final String leaveType;
  final String reason;
  final bool isForceCollapsed;
  final double? maxExpandedContentHeight;

  const TimeOffSummaryCardWidget({
    super.key,
    required this.dateRange,
    required this.leaveType,
    required this.reason,
    this.isForceCollapsed = false,
    this.maxExpandedContentHeight,
  });

  @override
  State<TimeOffSummaryCardWidget> createState() =>
      _TimeOffSummaryCardWidgetState();
}

class _TimeOffSummaryCardWidgetState extends State<TimeOffSummaryCardWidget> {
  bool _userExpandedState = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isExpanded = widget.isForceCollapsed ? false : _userExpandedState;

    return GestureDetector(
      onTap: () {
        setState(() {
          _userExpandedState = !_userExpandedState;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  SvgPicture.asset(
                    AppAssets.logCalendar,
                    width: 24.r,
                    height: 24.r,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      widget.dateRange,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                        color: isDark ? AppColors.white : AppColors.black,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.secondary,
                      size: 28.r,
                    ),
                  ),
                ],
              ),
            ),
            if (isExpanded) ...[
              SizedBox(height: 4.h),
              Divider(
                height: 1,
                thickness: 0.6,
                color: isDark ? AppColors.darkNav : AppColors.navColor,
              ),
              SizedBox(height: 2.h),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: widget.maxExpandedContentHeight ?? 140.h,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 10.h,
                      horizontal: 17.w,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)?.typeOfLeave ??
                              'Type of leave',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            height: 16 / 12,
                            color: AppColors.secondary,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          widget.leaveType,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            height: 20 / 14,
                            color: isDark ? AppColors.white : AppColors.black,
                          ),
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          AppLocalizations.of(context)?.reason ?? 'Reason',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            height: 16 / 12,
                            color: AppColors.secondary,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          widget.reason,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            height: 20 / 14,
                            color: isDark ? AppColors.white : AppColors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
