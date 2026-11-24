import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/timeoff_response_model.dart';

class LeaveItem extends StatelessWidget {
  final String? month;
  final String? day;
  final String? title;
  final String? durationText;
  final bool isApproved;
  final VoidCallback? onTap;
  final TimeOffLeaveItemModel? leave;
  final bool isLast;

  const LeaveItem({
    super.key,
    this.month,
    this.day,
    this.title,
    this.durationText,
    this.isApproved = false,
    this.onTap,
    this.leave,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final TimeOffLeaveStage stage =
        leave?.stageEnum ??
        TimeOffLeaveStage.fromString(isApproved ? 'approved' : 'pending');

    final Color borderLeftColor;
    final Color dateContainerBg;
    final Color dateTextColor;
    final Color statusBgColor;
    final Color statusTextColor;

    switch (stage) {
      case TimeOffLeaveStage.rejected:
        borderLeftColor = const Color(0xFFFF5722);
        dateContainerBg = isDark
            ? const Color(0xFFFFB5A0).withValues(alpha: 0.1)
            : const Color(0x4DFFB5A0);
        dateTextColor = const Color(0xFFB02F00);
        statusBgColor = const Color(0xFFFFDBD0);
        statusTextColor = isDark
            ? const Color(0xFFE61E1E)
            : const Color(0xFF7F2A0D);
        break;

      case TimeOffLeaveStage.approved:
        borderLeftColor = const Color(0xFFCCFFD3);
        dateContainerBg = isDark
            ? const Color(0xFFCCFFD3).withValues(alpha: 0.1)
            : const Color(0xFFCCFFD3);
        dateTextColor = const Color(0xFF625E50);
        statusBgColor = isDark
            ? const Color(0x6698FFA6)
            : const Color(0xFFCCFFD3);
        statusTextColor = isDark
            ? const Color(0xFF51FF45)
            : const Color(0xFF1F611B);
        break;

      case TimeOffLeaveStage.pending:
      case TimeOffLeaveStage.custom:
        borderLeftColor = const Color(0xFF969181);
        dateContainerBg = isDark
            ? const Color(0xFFE9E2CF).withValues(alpha: 0.1)
            : const Color(0x80E9E2CF);
        dateTextColor = const Color(0xFF625E50);
        statusBgColor = isDark
            ? const Color(0x4DFFDE59)
            : const Color(0x33FFCC00);
        statusTextColor = isDark
            ? const Color(0xFFFFD52E)
            : const Color(0xFFAB8D13);
        break;
    }

    final String rawStatusText = leave?.stageDisplay ?? '';
    final String fallbackStatusText = (leave?.stage.isNotEmpty == true)
        ? '${leave!.stage[0].toUpperCase()}${leave!.stage.substring(1)}'
        : '';
    final statusText = rawStatusText.trim().isNotEmpty
        ? rawStatusText
        : fallbackStatusText;

    final dateFrom =
        leave != null ? DateTime.tryParse(leave!.dateFrom) : null;

    final displayMonth =
        month ??
        (dateFrom != null ? AppDateFormatter.mmmUppercase(dateFrom) : '');
    final displayDay =
        day ?? (dateFrom != null ? AppDateFormatter.dd(dateFrom) : '');
    final displayTitle = title ?? leave?.name ?? '';
    final displayDuration =
        durationText ??
        (leave != null
            ? '${leave!.days} Day${leave!.days > 1 ? 's' : ''} · ${leave!.leaveType?.name ?? 'Leave'}'
            : '');

    return GestureDetector(
      onTap:
          onTap ??
          () {
            if (leave != null) {
              Navigator.pushNamed(
                context,
                AppRouter.timeOffLog,
                arguments: leave,
              );
            }
          },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: isLast ? EdgeInsets.zero : EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1004) : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0x0F2A2A2A),
              offset: const Offset(0, 4),
              blurRadius: 20.r,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: borderLeftColor, width: 4.w),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52.w,
                    height: 52.w,
                    decoration: BoxDecoration(
                      color: dateContainerBg,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          displayMonth.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w400,
                            height: 15 / 10,
                            color: dateTextColor,
                          ),
                        ),
                        Text(
                          displayDay,
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w400,
                            height: 28 / 18,
                            color: dateTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Row 1: Title and Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                displayTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  height: 24 / 16,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1B1C1C),
                                ),
                              ),
                            ),
                            if (statusText.trim().isNotEmpty) ...[
                              SizedBox(width: 8.w),
                              ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: 110.w),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBgColor,
                                    borderRadius: BorderRadius.circular(9999.r),
                                  ),
                                  child: Text(
                                    statusText,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w600,
                                      height: 16 / 10,
                                      color: statusTextColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 4.h),
                        // Row 2: Duration
                        Text(
                          displayDuration,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w400,
                            height: 24 / 16,
                            color: isDark
                                ? const Color(0xFFEAE1D8)
                                : const Color(0xFF5B4039),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
