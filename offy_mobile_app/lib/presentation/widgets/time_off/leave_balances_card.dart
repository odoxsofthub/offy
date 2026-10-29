import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:office_app/core/constants/app_assets.dart';
import '../../viewmodels/time_off/time_off_provider.dart';
import '../../../data/models/timeoff_response_model.dart';
import '../../../core/theme/app_colors.dart';
import 'leave_balances_shimmer.dart';
import '../common/two_lines_scaled_text.dart';
import '../../../../l10n/app_localizations.dart';

class LeaveBalancesCard extends StatefulWidget {
  const LeaveBalancesCard({super.key});

  @override
  State<LeaveBalancesCard> createState() => _LeaveBalancesCardState();
}

class _LeaveBalancesCardState extends State<LeaveBalancesCard> {
  bool _isExpanded = false;

  List<Widget> _buildBalancesGrid(
    List<TimeOffBalanceModel> balances,
    TimeOffProvider provider,
  ) {
    final displayBalances = _isExpanded ? balances : balances.take(3).toList();
    final List<Widget> rows = [];

    for (int i = 0; i < displayBalances.length; i += 3) {
      final end = i + 3 > displayBalances.length
          ? displayBalances.length
          : i + 3;
      final chunk = displayBalances.sublist(i, end);

      final List<Widget> rowItems = chunk.map((balance) {
        // Match type from provider availableTypes
        TimeOffTypeModel? matchingType;
        for (final type in provider.availableTypes) {
          if (type.id == balance.id) {
            matchingType = type;
            break;
          }
        }

        // Determine color
        Color color = AppColors.main;
        if (matchingType != null && matchingType.color.isNotEmpty) {
          final hex = matchingType.color.replaceFirst('#', '');
          int? colorValue;
          if (hex.length == 6) {
            colorValue = int.tryParse('FF$hex', radix: 16);
          } else if (hex.length == 8) {
            colorValue = int.tryParse(hex, radix: 16);
          }
          if (colorValue != null) {
            color = Color(colorValue);
          }
        }

        final unit = matchingType?.unit ?? balance.unit;

        return Expanded(
          child: _buildLeaveBalanceItem(
            label: balance.name,
            value: balance.remaining,
            total: balance.totalAllocated,
            color: color,
            unit: unit,
          ),
        );
      }).toList();

      while (rowItems.length < 3) {
        rowItems.add(const Expanded(child: SizedBox.shrink()));
      }

      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowItems,
        ),
      );

      if (i + 3 < displayBalances.length) {
        rows.add(SizedBox(height: 20.h));
      }
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimeOffProvider>();
    final balances = provider.timeOffData?.balances ?? [];
    final hasLoadedAllInitialData =
        provider.timeOffData != null && provider.availableTypes.isNotEmpty;

    if (provider.isLoading && !hasLoadedAllInitialData) {
      return const LeaveBalancesShimmer();
    }

    if (balances.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.95.r),
        border: Border.all(
          color: isDark ? const Color(0x4DE4BEB4) : const Color(0x4DE4BEB4),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)?.leaveBalances ?? 'Leave Balances',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 20.sp,
                  height: 28 / 20,
                  color: isDark ? AppColors.white : const Color(0xFF1B1C1C),
                ),
              ),
              if (balances.length > 3)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 8.h,
                    ),
                    child: SvgPicture.asset(
                      _isExpanded ? AppAssets.minimize : AppAssets.maximize,
                      colorFilter: ColorFilter.mode(
                        isDark ? AppColors.white : AppColors.darkNav,
                        BlendMode.srcIn,
                      ),
                      width: 24.r,
                      height: 24.r,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 20.h),
          if (balances.isEmpty)
            Center(
              child: Text(
                AppLocalizations.of(context)?.noBalancesAvailable ??
                    'No balances available',
                style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
              ),
            )
          else
            ..._buildBalancesGrid(balances, provider),
        ],
      ),
    );
  }

  Widget _buildLeaveBalanceItem({
    required String label,
    required num value,
    required num total,
    required Color color,
    required String unit,
  }) {
    // Format values nicely
    final valueStr = value % 1 == 0
        ? value.toInt().toString()
        : value.toString();
    final totalStr = total % 1 == 0
        ? total.toInt().toString()
        : total.toString();

    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Column(
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
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.w),
              child: TwoLinesScaledText(
                text: label.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 3,
                minFontSize: 9.sp,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  height: 16.18 / 12,
                  color: isDark ? AppColors.white : const Color(0xFF5B4039),
                ),
              ),
            ),
            SizedBox(height: 2.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.w),
              child: TwoLinesScaledText(
                text: '$valueStr/$totalStr $unit'.trim().toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                minFontSize: 8.sp,
                style: TextStyle(
                  fontSize: 10.79.sp,
                  fontWeight: FontWeight.w400,
                  height: 16.18 / 10.79,
                  color: isDark
                      ? const Color(0xFFEAE1D8)
                      : const Color(0xFF5B4039),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
