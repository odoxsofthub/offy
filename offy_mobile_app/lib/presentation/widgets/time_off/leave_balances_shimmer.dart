import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';

class LeaveBalancesShimmer extends StatelessWidget {
  const LeaveBalancesShimmer({super.key});

  Widget _buildLeaveBalanceItem({
    required String label,
    required num value,
    required num total,
    required Color color,
    required String unit,
    required bool isDark,
  }) {
    final valueStr = value % 1 == 0 ? value.toInt().toString() : value.toString();
    final totalStr = total % 1 == 0 ? total.toInt().toString() : total.toString();

    return SizedBox(
      width: 80.w,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 64.08.w,
            height: 64.08.w,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 54.w,
                  height: 54.w,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 8.w,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark
                          ? const Color(0xFFEAE1D8)
                          : const Color(0xFFE4E2E1),
                    ),
                  ),
                ),
                SizedBox(
                  width: 54.w,
                  height: 54.w,
                  child: CircularProgressIndicator(
                    value: total > 0 ? value / total : 0,
                    strokeWidth: 8.w,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(13.w),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      valueStr,
                      style: TextStyle(
                        fontSize: 15.11.sp,
                        fontWeight: FontWeight.w700,
                        height: 21.58 / 15.11,
                        color: isDark
                            ? AppColors.white
                            : const Color(0xFF1B1C1C),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              height: 16.18 / 12,
              color: isDark ? AppColors.white : const Color(0xFF5B4039),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            '$valueStr/$totalStr $unit'.trim().toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.79.sp,
              fontWeight: FontWeight.w400,
              height: 16.18 / 10.79,
              color: isDark
                  ? const Color(0xFFEAE1D8)
                  : const Color(0xFF5B4039),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mockColor = isDark
        ? const Color(0xFFEAE1D8)
        : const Color(0xFFE4E2E1);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.95.r),
        border: Border.all(
          color: const Color(0x4DE4BEB4),
          width: 1.08.w,
        ),
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFB9A2),
                  Color(0xFF000000),
                  Color(0xFFF9AE64),
                ],
                stops: [0.0, 0.4886, 1.0],
              )
            : const LinearGradient(
                begin: Alignment(-0.41, -0.91),
                end: Alignment(0.41, 0.91),
                colors: [
                  Color(0xFFFFE1D7),
                  Color(0xFFFFFFFF),
                  Color(0xFFFFFFFF),
                  Color(0xFFFAE1C8),
                ],
                stops: [0.0, 0.4, 0.6, 1.0],
              ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0F2A2A2A),
            offset: Offset(0, 4.32.h),
            blurRadius: 21.58.r,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 21.58.w),
      child: Shimmer.fromColors(
        baseColor: AppColors.shimmerBase(isDark),
        highlightColor: AppColors.shimmerHighlight(isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Leave Balances',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 20.sp,
                    height: 28 / 20,
                    color: isDark ? AppColors.white : const Color(0xFF1B1C1C),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLeaveBalanceItem(
                  label: 'Casual Leave',
                  value: 0,
                  total: 0,
                  color: mockColor,
                  unit: 'Days',
                  isDark: isDark,
                ),
                _buildLeaveBalanceItem(
                  label: 'Sick Leave',
                  value: 0,
                  total: 0,
                  color: mockColor,
                  unit: 'Days',
                  isDark: isDark,
                ),
                _buildLeaveBalanceItem(
                  label: 'Annual Leave',
                  value: 0,
                  total: 0,
                  color: mockColor,
                  unit: 'Days',
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
