import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/navigation/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/attendance_log_response_model.dart';
import '../../viewmodels/attendance/attendance_log_provider.dart';
import '../../../../l10n/app_localizations.dart';
import 'attendance_log_shimmer.dart';

class AttendanceLogList extends StatelessWidget {
  final List<AttendanceLogEntryModel> logs;
  final bool isTopCardLoading;

  const AttendanceLogList({
    super.key,
    required this.logs,
    this.isTopCardLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: logs.asMap().entries.map((entry) {
        final index = entry.key;
        final log = entry.value;
        final isLast = index == logs.length - 1;

        if (index == 0 && isTopCardLoading) {
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0.0 : 12.h),
            child: const AttendanceLogShimmer(itemCount: 1),
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0.0 : 12.h),
          child: _AttendanceLogCard(log: log),
        );
      }).toList(),
    );
  }
}

class _AttendanceLogCard extends StatelessWidget {
  final AttendanceLogEntryModel log;

  const _AttendanceLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final bool isActive = log.status == AttendanceLogStatus.active;
    final bool isCompleted = log.status == AttendanceLogStatus.completed;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0F2A2A2A),
            blurRadius: 20.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Material(
          color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: () {
            if (context.read<AttendanceLogProvider>().isLoading) return;
            Navigator.pushNamed(
              context,
              AppRouter.attendanceDayDetail,
              arguments: log,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: log.status == AttendanceLogStatus.none
                      ? const Color(0x66E4E2E1)
                    : isActive
                    ? AppColors.main
                    : const Color(0XFFE4E2E1),
                width: 4.w,
              ),
            ),
          ),
          padding: EdgeInsets.all(16.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // First Column: contains the icon container
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48.w,
                    height: 48.w,
                    decoration: BoxDecoration(
                      color: log.status == AttendanceLogStatus.none
                          ? (isDark
                                ? const Color(0x1AE4E2E1)
                                : const Color(0x66E4E2E1))
                          : isActive
                          ? AppColors.main.withValues(alpha: 0.12)
                          : (isDark
                                ? const Color(0x1AE4E2E1)
                                : const Color(0XFFE4E2E1)),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isActive ? Icons.login_outlined : Icons.logout_outlined,
                        color: log.status == AttendanceLogStatus.none
                            ? (isDark
                                  ? const Color(0xFFA17265)
                                  : const Color(0x995B4039))
                            : isActive
                            ? AppColors.main
                            : (isDark
                                  ? AppColors.main
                                  : const Color(0xFF1B1C1C)),
                        size: 18.w,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 16.w),
              // Second Column: details
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // First row: has date and status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final maxWidth = constraints.maxWidth;

                                  TextStyle dateStyle(double fontSize) =>
                                      TextStyle(
                                        fontSize: fontSize,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.white
                                            : (log.status ==
                                                    AttendanceLogStatus.none
                                                ? const Color(0xB21B1C1C)
                                                : const Color(0xFF1B1C1C)),
                                        height: 24 / 16,
                                      );

                                  if (maxWidth <= 0 || maxWidth.isInfinite) {
                                    return Text(
                                      log.date,
                                      style: dateStyle(16.sp),
                                    );
                                  }

                                  final textDirection =
                                      Directionality.of(context);

                                  bool checkFits(
                                    double fontSize,
                                    int maxLines,
                                  ) {
                                    final tp = TextPainter(
                                      text: TextSpan(
                                        text: log.date,
                                        style: dateStyle(fontSize),
                                      ),
                                      textDirection: textDirection,
                                      maxLines: maxLines,
                                    )..layout(maxWidth: maxWidth);
                                    return !tp.didExceedMaxLines;
                                  }

                                  final bool fits1Line16 =
                                      checkFits(16.sp, 1);
                                  if (fits1Line16) {
                                    return Text(
                                      log.date,
                                      maxLines: 1,
                                      style: dateStyle(16.sp),
                                    );
                                  }

                                  final bool fits1Line14 =
                                      checkFits(14.sp, 1);
                                  if (fits1Line14) {
                                    return FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        log.date,
                                        maxLines: 1,
                                        style: dateStyle(16.sp),
                                      ),
                                    );
                                  }

                                  final bool fits2Lines16 =
                                      checkFits(16.sp, 2);
                                  if (fits2Lines16) {
                                    return Text(
                                      log.date,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: dateStyle(16.sp),
                                    );
                                  }

                                  return Text(
                                    log.date,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: dateStyle(14.sp),
                                  );
                                },
                              ),
                            ),
                            if (log.status != AttendanceLogStatus.none) ...[
                              SizedBox(width: 8.w),
                              _buildStatusBadge(context, log.status),
                            ],
                          ],
                        ),
                        SizedBox(height: 4.h),
                        // Second row: has a column with time and shift duration
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      if (isActive)
                                        Padding(
                                          padding: EdgeInsets.only(right: 6.w),
                                          child: Container(
                                            width: 8.w,
                                            height: 8.w,
                                            decoration: const BoxDecoration(
                                              color: AppColors.main,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      Expanded(
                                        child: Text(
                                          log.timeInfo,
                                          style: TextStyle(
                                            fontSize: 13.sp,
                                            color: isDark
                                                ? AppColors.white
                                                : (log.status ==
                                                          AttendanceLogStatus
                                                              .none
                                                      ? const Color(0xB25B4039)
                                                      : const Color(
                                                          0xFFA49D95,
                                                        )),
                                            fontWeight: FontWeight.w500,
                                            height: 18 / 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isCompleted &&
                                      log.shiftDuration != null) ...[
                                    SizedBox(height: 4.h),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            AppLocalizations.of(
                                                  context,
                                                )?.shiftDuration ??
                                                'SHIFT DURATION',
                                            style: TextStyle(
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.w400,
                                              color: isDark
                                                  ? AppColors.main
                                                  : const Color(0xFF9F4122),
                                              height: 15 / 10,
                                            ),
                                          ),
                                          SizedBox(width: 6.w),
                                          Text(
                                            log.shiftDuration!,
                                            style: TextStyle(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? AppColors.white
                                                  : const Color(0xFF1B1C1C),
                                              height: 20 / 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildStatusBadge(BuildContext context, AttendanceLogStatus status) {
    final bool isActive = status == AttendanceLogStatus.active;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.main
            : (isDark ? const Color(0x33E4E2E1) : const Color(0x80E4E2E1)),
        borderRadius: BorderRadius.circular(100.r),
        border: isActive
            ? null
            : (isDark ? null : Border.all(color: AppColors.shade, width: 1.w)),
      ),
      child: Text(
        isActive
            ? AppLocalizations.of(context)?.active ?? 'ACTIVE'
            : AppLocalizations.of(context)?.completed ?? 'COMPLETED',
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w400,
          height: 15 / 10,
          letterSpacing: 0.5,
          color: isActive
              ? Colors.white
              : (isDark ? AppColors.white : const Color(0xFF1B1C1C)),
        ),
      ),
    );
  }
}
