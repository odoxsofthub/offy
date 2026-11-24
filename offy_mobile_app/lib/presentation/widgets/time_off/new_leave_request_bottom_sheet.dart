import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/utils/date_formatter.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../viewmodels/time_off/time_off_provider.dart';
import '../common/custom_back_button.dart';
import '../common/custom_snackbar.dart';
import '../common/action_failure_dialog.dart';
import '../../../core/constants/app_globals.dart';
import '../../../core/constants/error_messages.dart';
import '../../../data/models/timeoff_response_model.dart';
import '../../../core/network/mock_api_data.dart';
import 'leave_type_selector_field.dart';
import '../../../../l10n/app_localizations.dart';

class NewLeaveRequestBottomSheet extends StatefulWidget {
  final DateTime? initialDate;

  const NewLeaveRequestBottomSheet({super.key, this.initialDate});

  @override
  State<NewLeaveRequestBottomSheet> createState() =>
      _NewLeaveRequestBottomSheetState();
}

class _NewLeaveRequestBottomSheetState
    extends State<NewLeaveRequestBottomSheet> {
  int? _selectedLeaveTypeId;
  late DateTime _startDate;
  late DateTime _endDate;
  final TextEditingController _reasonController = TextEditingController();
  final FocusNode _reasonFocusNode = FocusNode();
  bool _hasAttemptedSubmit = false;
  bool _isSubmitting = false;

  int get _totalDays {
    return _endDate.difference(_startDate).inDays + 1;
  }

  List<TimeOffTypeModel> _getAvailableTypes(TimeOffProvider provider) {
    if (provider.availableTypes.isEmpty && AppGlobals.isDesignMode) {
      final mockData = MockApiData.getMockResponse(
        'GET',
        '/api/mobile/v1/timeoff/types',
      )['data'];
      if (mockData is List) {
        return mockData
            .map((e) => TimeOffTypeModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return provider.availableTypes;
  }

  @override
  void initState() {
    super.initState();
    final baseDate = widget.initialDate ?? DateTime.now();
    _startDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
    _endDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TimeOffProvider>().clearCalculatedDuration();
      _triggerDurationCalculation();
    });
  }

  void _triggerDurationCalculation() {
    final provider = context.read<TimeOffProvider>();
    final types = _getAvailableTypes(provider);
    if (types.isEmpty) return;
    if (_selectedLeaveTypeId == null) return;

    final selectedType = types.firstWhere((t) => t.id == _selectedLeaveTypeId);

    provider.calculateDuration(
      typeId: selectedType.id,
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _reasonFocusNode.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    if (_isSubmitting || context.read<TimeOffProvider>().isSubmittingRequest) {
      return;
    }
    _reasonFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime(2030, 12, 31),
    );
    _reasonFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
      _triggerDurationCalculation();
    }
  }

  Future<void> _selectEndDate() async {
    if (_isSubmitting || context.read<TimeOffProvider>().isSubmittingRequest) {
      return;
    }
    _reasonFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2030, 12, 31),
    );
    _reasonFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
      _triggerDurationCalculation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final titleStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 20.sp,
      height: 28 / 20,
      color: isDark ? AppColors.white : AppColors.black,
    );

    final sectionHeaderStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 12.sp,
      height: 16 / 12,
      color: isDark ? const Color(0xFFEAE1D8) : const Color(0xFF5B4039),
    );

    final dateValueStyle = TextStyle(
      fontWeight: FontWeight.w400,
      fontSize: 14.sp,
      height: 20 / 14,
      color: isDark ? AppColors.white : const Color(0xFF1B1C1C),
    );

    final inputBgColor = isDark ? const Color(0xFF7B5C38) : Colors.white;
    final inputBorderColor = isDark
        ? const Color(0xFF7B5C38)
        : const Color(0xFFCAC3C0);
    final inputIconColor = isDark ? Colors.white : const Color(0xFF5B4039);

    final bannerBgColor = isDark ? AppColors.darkCard : const Color(0xFFFFDBD0);
    final bannerIconTextColor = isDark
        ? const Color(0xFFEC7474)
        : const Color(0xFF7F2A0D);
    final bannerValueColor = isDark
        ? const Color(0xFFEC7474)
        : const Color(0xFF722104);

    final isSubmitting =
        _isSubmitting || context.watch<TimeOffProvider>().isSubmittingRequest;

    return PopScope(
      canPop: !isSubmitting,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: isDark
              ? AppColors.darkTopCard
              : AppColors.midLight,
          systemNavigationBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
        child: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkTopCard : AppColors.midLight,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20.r),
                topRight: Radius.circular(20.r),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Scaffold(
                backgroundColor: Colors.transparent,
                resizeToAvoidBottomInset: true,
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header and Scrollable Content (padded)
                    Expanded(
                      child: AbsorbPointer(
                        absorbing: isSubmitting,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(15.w, 20.h, 15.w, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            // Header Row
                            Row(
                              children: [
                                CustomBackButton(
                                  onTap: isSubmitting
                                      ? null
                                      : () => Navigator.pop(context),
                                ),
                              SizedBox(width: 19.w),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(
                                        context,
                                      )?.newLeaveRequest ??
                                      'New leave request',
                                  style: titleStyle,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 26.h),

                          // Scrollable Content
                          Expanded(
                            child: SingleChildScrollView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 1. Choose leave type
                                  Text(
                                    AppLocalizations.of(
                                          context,
                                        )?.chooseLeaveType ??
                                        'Choose leave type',
                                    style: sectionHeaderStyle,
                                  ),
                                  SizedBox(height: 12.h),
                                  Consumer<TimeOffProvider>(
                                    builder: (context, provider, child) {
                                      return LeaveTypeSelectorField(
                                        types: _getAvailableTypes(provider),
                                        selectedTypeId: _selectedLeaveTypeId,
                                        hasError:
                                            _hasAttemptedSubmit &&
                                            _selectedLeaveTypeId == null,
                                        errorText:
                                            AppLocalizations.of(
                                              context,
                                            )?.pleaseSelectLeaveType ??
                                            'Please select a leave type',
                                        isLoading:
                                          provider.isLoading &&
                                          _getAvailableTypes(provider).isEmpty,
                                        onTypeSelected: (selectedType) {
                                          setState(() {
                                            _selectedLeaveTypeId =
                                                selectedType.id;
                                            _hasAttemptedSubmit = false;
                                          });
                                          _triggerDurationCalculation();
                                        },
                                      );
                                    },
                                  ),
                                  SizedBox(height: 26.h),

                                  // 2. Start Date & End Date Row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              AppLocalizations.of(
                                                    context,
                                                  )?.startDate ??
                                                  'Start Date',
                                              style: sectionHeaderStyle,
                                            ),
                                            SizedBox(height: 8.h),
                                            GestureDetector(
                                              onTap: context
                                                      .watch<TimeOffProvider>()
                                                      .isSubmittingRequest
                                                  ? null
                                                  : () => _selectStartDate(),
                                              child: Container(
                                                padding: EdgeInsets.all(16.w),
                                                decoration: BoxDecoration(
                                                  color: inputBgColor,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        12.r,
                                                      ),
                                                  border: Border.all(
                                                    color: inputBorderColor,
                                                    width: 1.w,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .calendar_today_outlined,
                                                      color: inputIconColor,
                                                      size: 15.w,
                                                    ),
                                                    SizedBox(width: 8.w),
                                                    Expanded(
                                                      child: Text(
                                                        AppDateFormatter.mmmDdYyyy(
                                                          _startDate,
                                                        ),
                                                        style: dateValueStyle,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 14.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              AppLocalizations.of(
                                                    context,
                                                  )?.endDate ??
                                                  'End Date',
                                              style: sectionHeaderStyle,
                                            ),
                                            SizedBox(height: 8.h),
                                            GestureDetector(
                                              onTap: context
                                                      .watch<TimeOffProvider>()
                                                      .isSubmittingRequest
                                                  ? null
                                                  : () => _selectEndDate(),
                                              child: Container(
                                                padding: EdgeInsets.all(16.w),
                                                decoration: BoxDecoration(
                                                  color: inputBgColor,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        12.r,
                                                      ),
                                                  border: Border.all(
                                                    color: inputBorderColor,
                                                    width: 1.w,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .calendar_today_outlined,
                                                      color: inputIconColor,
                                                      size: 15.w,
                                                    ),
                                                    SizedBox(width: 8.w),
                                                    Expanded(
                                                      child: Text(
                                                        AppDateFormatter.mmmDdYyyy(
                                                          _endDate,
                                                        ),
                                                        style: dateValueStyle,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16.h),

                                  // 3. Duration Calculation Banner
                                  Container(
                                    padding: EdgeInsets.fromLTRB(
                                      16.w,
                                      8.h,
                                      16.w,
                                      8.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bannerBgColor,
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.access_time_outlined,
                                                color: bannerIconTextColor,
                                                size: 20.w,
                                              ),
                                              SizedBox(width: 8.w),
                                              Flexible(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Text(
                                                    AppLocalizations.of(
                                                          context,
                                                        )?.durationCalculation ??
                                                        'Duration Calculation',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w400,
                                                      fontSize: 14.sp,
                                                      height: 20 / 14,
                                                      color:
                                                          bannerIconTextColor,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 12.w),
                                        Expanded(
                                          child: Consumer<TimeOffProvider>(
                                            builder: (context, provider, child) {
                                              if (provider
                                                  .isCalculatingDuration) {
                                                return Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: SizedBox(
                                                    width: 16.w,
                                                    height: 16.w,
                                                    child: const CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(Color(0xFF722104)),
                                                    ),
                                                  ),
                                                );
                                              }

                                              final totalDaysStr = '$_totalDays ${_totalDays == 1 ? (AppLocalizations.of(context)?.day ?? "Day") : (AppLocalizations.of(context)?.days ?? "Days")}';
                                              final displayStr =
                                                  provider
                                                      .calculatedDuration
                                                      ?.display ??
                                                  totalDaysStr;

                                              return FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Text(
                                                  '${AppLocalizations.of(context)?.total ?? 'Total'}: $displayStr',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16.sp,
                                                    height: 28 / 16,
                                                    color: bannerValueColor,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 28.h),

                                  // 4. Reason (Optional)
                                  Text(
                                    AppLocalizations.of(
                                          context,
                                        )?.reasonOptional ??
                                        'Reason (Optional)',
                                    style: sectionHeaderStyle,
                                  ),
                                  SizedBox(height: 8.h),
                                  Container(
                                    padding: EdgeInsets.all(16.w),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.1)
                                          : const Color(0xCCFFFFFF),
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.transparent
                                            : Colors.white,
                                        width: 1.w,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _reasonController,
                                      focusNode: _reasonFocusNode,
                                      minLines: 4,
                                      maxLines: 4,
                                      maxLength: 500,
                                      buildCounter:
                                          (
                                            context, {
                                            required currentLength,
                                            required isFocused,
                                            maxLength,
                                          }) => null,
                                      decoration: InputDecoration(
                                        hintText:
                                            AppLocalizations.of(
                                              context,
                                            )?.brieflyExplainLeave ??
                                            'Briefly explain the purpose of your leave...',
                                        hintStyle: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w400,
                                          height: 20 / 14,
                                          color: isDark
                                              ? const Color(0xFFA49D95)
                                              : AppColors.navColor,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w400,
                                        height: 20 / 14,
                                        color: isDark
                                            ? AppColors.white
                                            : AppColors.black,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 26.h),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                  // 5. Bottom Request Button Container
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                      16.w,
                      10.h,
                      16.w,
                      // Fallback for notchless devices without system navigation bars
                      MediaQuery.of(context).padding.bottom > 0 ? 5.73.h : 16.h,
                    ),
                    color: isDark ? AppColors.darkTopCard : AppColors.midLight,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.r),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5722), Color(0xFFFF8A65)],
                          // begin: Alignment(-0.2, -1.0),
                          // end: Alignment(1.2, 1.0),
                          transform: GradientRotation(10.57 * pi / 180),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x4DFF5722),
                            offset: Offset(0, -8),
                            blurRadius: 15,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          _reasonFocusNode.unfocus();
                          FocusScope.of(context).unfocus();

                          final provider = context.read<TimeOffProvider>();
                          if (_isSubmitting || provider.isSubmittingRequest) return;

                          setState(() {
                            _hasAttemptedSubmit = true;
                            _isSubmitting = true;
                          });

                          final types = _getAvailableTypes(provider);
                          if (types.isEmpty) {
                            setState(() => _isSubmitting = false);
                            CustomSnackbar.show(
                              context,
                              message:
                                  AppLocalizations.of(context)?.noLeaveTypesAvailable ??
                                  'No leave types available',
                              isError: true,
                            );
                            return;
                          }

                          if (_selectedLeaveTypeId == null) {
                            setState(() => _isSubmitting = false);
                            return;
                          }

                          final selectedType = types.firstWhere(
                            (t) => t.id == _selectedLeaveTypeId,
                          );

                          final navigator = Navigator.of(context);

                          final success = await provider.submitLeaveRequest(
                            typeId: selectedType.id,
                            startDate: _startDate,
                            endDate: _endDate,
                            reason: _reasonController.text.trim(),
                          );

                          if (!context.mounted) return;

                          if (success) {
                            provider.clearCalculatedDuration();
                            if (mounted) {
                              setState(() => _isSubmitting = false);
                            }
                            navigator.pop();
                            CustomSnackbar.show(
                              context,
                              message:
                                  AppLocalizations.of(
                                    context,
                                  )?.leaveRequestSubmittedSuccessfully ??
                                  'Leave request submitted successfully',
                              isSuccess: true,
                            );
                          } else {
                            setState(() => _isSubmitting = false);
                            _reasonFocusNode.unfocus();
                            FocusScope.of(context).unfocus();
                            if (provider.errorMessage != ErrorMessages.requestCancelled) {
                              await showDialog(
                              context: context,
                              builder: (_) => ActionFailureDialog(
                                errorMessage: provider.errorMessage,
                              ),
                            );
                            }
                            if (context.mounted) {
                              _reasonFocusNode.unfocus();
                              FocusScope.of(context).unfocus();
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          elevation: 0,
                        ),
                        child: Consumer<TimeOffProvider>(
                          builder: (context, provider, child) {
                            if (provider.isSubmittingRequest) {
                              return SizedBox(
                                width: 24.w,
                                height: 24.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              );
                            }
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  AppLocalizations.of(context)?.requestLeave ??
                                      'Request leave',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w400,
                                    height: 24 / 16,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 8.01.w),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 16.w,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
