import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class MonthYearPickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime maxDate;
  final ValueChanged<DateTime> onDateSelected;

  const MonthYearPickerDialog({
    super.key,
    required this.initialDate,
    required this.maxDate,
    required this.onDateSelected,
  });

  static Future<DateTime?> show({
    required BuildContext context,
    required DateTime initialDate,
    DateTime? maxDate,
  }) {
    final effectiveMaxDate = maxDate ?? DateTime.now();
    return showDialog<DateTime>(
      context: context,
      builder: (context) => MonthYearPickerDialog(
        initialDate: initialDate,
        maxDate: effectiveMaxDate,
        onDateSelected: (selectedDate) {
          Navigator.of(context).pop(selectedDate);
        },
      ),
    );
  }

  @override
  State<MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<MonthYearPickerDialog> {
  late int _selectedYear;
  late int _selectedMonth;

  static const List<String> _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
  }

  bool _isMonthSelectable(int year, int month) {
    if (year > widget.maxDate.year) return false;
    if (year == widget.maxDate.year && month > widget.maxDate.month) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canGoNextYear = _selectedYear < widget.maxDate.year;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Title & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)?.selectMonthAndYear ??
                      'Select Month & Year',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.white : AppColors.black,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.all(10.r),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20.w,
                      color: isDark ? AppColors.white : const Color(0xFF5B4039),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Year Navigator: < 2026 >
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedYear--;
                    });
                  },
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    size: 24.w,
                    color: isDark ? AppColors.white : AppColors.black,
                  ),
                ),
                Text(
                  '$_selectedYear',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.main : AppColors.secondary,
                  ),
                ),
                IconButton(
                  onPressed: canGoNextYear
                      ? () {
                          setState(() {
                            _selectedYear++;
                            if (_selectedMonth > widget.maxDate.month &&
                                _selectedYear == widget.maxDate.year) {
                              _selectedMonth = widget.maxDate.month;
                            }
                          });
                        }
                      : null,
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    size: 24.w,
                    color: canGoNextYear
                        ? (isDark ? AppColors.white : AppColors.black)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.2)),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // 12 Months Grid (3 columns)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 12,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10.h,
                crossAxisSpacing: 10.w,
                childAspectRatio: 2.2,
              ),
              itemBuilder: (context, index) {
                final monthNumber = index + 1;
                final isSelectable =
                    _isMonthSelectable(_selectedYear, monthNumber);
                final isSelected = _selectedYear == widget.initialDate.year &&
                    monthNumber == _selectedMonth;

                Color tileBgColor;
                Color textColor;

                if (isSelected) {
                  tileBgColor = AppColors.main;
                  textColor = Colors.white;
                } else if (!isSelectable) {
                  tileBgColor = isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF3E9E0).withValues(alpha: 0.4);
                  textColor = isDark
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.25);
                } else {
                  tileBgColor = isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : const Color(0xFFF3E9E0);
                  textColor = isDark ? AppColors.white : AppColors.black;
                }

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isSelectable
                        ? () {
                            setState(() {
                              _selectedMonth = monthNumber;
                            });
                            widget.onDateSelected(
                              DateTime(_selectedYear, monthNumber),
                            );
                          }
                        : null,
                    borderRadius: BorderRadius.circular(8.r),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tileBgColor,
                        borderRadius: BorderRadius.circular(8.r),
                        border: isSelected
                            ? Border.all(color: AppColors.main, width: 1.w)
                            : null,
                      ),
                      child: Text(
                        _months[index],
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
