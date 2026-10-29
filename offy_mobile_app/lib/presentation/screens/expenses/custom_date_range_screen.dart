import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/common/custom_screen_header.dart';
import '../../widgets/expenses/custom_date_range/custom_date_range_bottom_cta.dart';
import '../../widgets/expenses/custom_date_range/custom_date_range_calendar.dart';
import '../../widgets/expenses/custom_date_range/custom_date_range_indicator.dart';

class CustomDateRangeScreen extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const CustomDateRangeScreen({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  State<CustomDateRangeScreen> createState() => _CustomDateRangeScreenState();
}

class _CustomDateRangeScreenState extends State<CustomDateRangeScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  ActiveDateSelection _activeSelection = ActiveDateSelection.start;
  late DateTime _displayedMonth;
  bool _hasReset = false;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;

    if (_startDate != null) {
      _displayedMonth = DateTime(_startDate!.year, _startDate!.month);
      _activeSelection = _endDate == null
          ? ActiveDateSelection.end
          : ActiveDateSelection.start;
    } else {
      final now = DateTime.now();
      _displayedMonth = DateTime(now.year, now.month);
    }
  }

  void _onPreviousMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month - 1,
      );
    });
  }

  void _onNextMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
      );
    });
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _hasReset = false;
      final cleanDate = DateTime(date.year, date.month, date.day);

      if (_activeSelection == ActiveDateSelection.start) {
        _startDate = cleanDate;
        if (_endDate != null && cleanDate.isAfter(_endDate!)) {
          _endDate = null;
        }
        _activeSelection = ActiveDateSelection.end;
      } else {
        if (_startDate == null || cleanDate.isBefore(_startDate!)) {
          _startDate = cleanDate;
          _endDate = null;
          _activeSelection = ActiveDateSelection.end;
        } else {
          _endDate = cleanDate;
        }
      }
    });
  }

  void _onSelectionBoxChanged(ActiveDateSelection selection) {
    setState(() {
      _activeSelection = selection;
    });
  }

  void _onReset() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _activeSelection = ActiveDateSelection.start;
      _hasReset = true;
    });
  }

  void _handleBack() {
    if (_hasReset && _startDate == null) {
      Navigator.pop(context, false);
    } else {
      Navigator.pop(context);
    }
  }

  void _onConfirm() {
    if (_startDate != null) {
      final end = _endDate ?? _startDate!;
      Navigator.pop(
        context,
        DateTimeRange(start: _startDate!, end: end),
      );
    } else {
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: isDark ? AppColors.darkTopCard : AppColors.midLight,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isDark ? AppColors.darkBg : Colors.white,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleBack();
        },
        child: Scaffold(
          backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFFBF8F5),
          body: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                CustomScreenHeader(
                  title: l10n?.customDateRange ?? 'Custom Date Range',
                  onBackTap: _handleBack,
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 20.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CustomDateRangeIndicator(
                        startDate: _startDate,
                        endDate: _endDate,
                        activeSelection: _activeSelection,
                        onSelectionChanged: _onSelectionBoxChanged,
                      ),
                      SizedBox(height: 24.h),
                      CustomDateRangeCalendar(
                        displayedMonth: _displayedMonth,
                        startDate: _startDate,
                        endDate: _endDate,
                        onDateSelected: _onDateSelected,
                        onPreviousMonth: _onPreviousMonth,
                        onNextMonth: _onNextMonth,
                      ),
                    ],
                  ),
                ),
              ),
              CustomDateRangeBottomCta(
                onReset: _onReset,
                onConfirm: _onConfirm,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
