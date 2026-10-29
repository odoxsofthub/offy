import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../common/two_lines_scaled_text.dart';

class PayslipHistoryItem extends StatelessWidget {
  final String monthLabel;
  final String yearLabel;
  final String title;
  final String subtitle;
  final String amount;
  final bool hasTopBorder;
  final VoidCallback? onTap;

  const PayslipHistoryItem({
    super.key,
    required this.monthLabel,
    required this.yearLabel,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.hasTopBorder,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final titleTextStyle = TextStyle(
      fontSize: 16.sp,
      fontWeight: FontWeight.w700,
      height: 24 / 16,
      color: isDark ? const Color(0xFFF3E9E0) : const Color(0xFF1B1C1C),
    );

    final subtitleTextStyle = TextStyle(
      fontSize: 13.sp,
      fontWeight: FontWeight.w500,
      height: 18 / 13,
      color: isDark ? const Color(0xFFEAE1D8) : const Color(0xFF5B4039),
    );

    final amountTextStyle = TextStyle(
      fontSize: 16.sp,
      fontWeight: FontWeight.w600,
      height: 24 / 16,
      color: isDark ? const Color(0xFFF3E9E0) : const Color(0xFF1B1C1C),
    );

    return InkWell(
      onTap: onTap,
      child: Container(
      decoration: BoxDecoration(
        border: hasTopBorder
            ? Border(
                top: BorderSide(
                  color: isDark ? const Color(0x1AEAE0C7) : const Color(0xFFEAE0C7),
                  width: 1.h,
                ),
              )
            : null,
      ),
      padding: EdgeInsets.all(16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Badge & Text Column
          Expanded(
            child: Row(
              children: [
                // Icon Badge
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFEAE7E7),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icons/payslip_receipt.svg',
                      width: 24.w,
                      height: 24.w,
                    ),
                  ),
                ),
                SizedBox(width: 16.w),

                // Title and Subtitle Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TwoLinesScaledText(
                        text: title,
                        style: titleTextStyle,
                        maxLines: 1,
                      ),
                      if (subtitle.isNotEmpty)
                        TwoLinesScaledText(
                          text: subtitle,
                          style: subtitleTextStyle,
                          maxLines: 2,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),

          // Right side: Amount
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(amount, style: amountTextStyle),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  }
}
