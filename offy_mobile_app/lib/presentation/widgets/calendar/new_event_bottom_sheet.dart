import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../common/custom_back_button.dart';
import '../common/gradient_rect_painter.dart';
import '../common/custom_snackbar.dart';
import '../common/custom_error_text.dart';
import '../../viewmodels/calendar/calendar_provider.dart';
import '../../../data/models/calendar_day_schedule_model.dart';
import '../../../core/constants/error_messages.dart';

class NewEventBottomSheet extends StatefulWidget {
  final CalendarScheduleItemModel? eventToEdit;
  final DateTime? initialDate;

  const NewEventBottomSheet({super.key, this.eventToEdit, this.initialDate});

  @override
  State<NewEventBottomSheet> createState() => _NewEventBottomSheetState();
}

class _NewEventBottomSheetState extends State<NewEventBottomSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _notesFocusNode = FocusNode();
  bool _hasAttemptedSubmit = false;
  bool _isSubmitting = false;
  bool _allDay = true;
  DateTime _startDate = DateTime.now();
  late TimeOfDay _startTime;
  DateTime _endDate = DateTime.now();
  late TimeOfDay _endTime;

  static TimeOfDay _getNextCompleteHour([DateTime? reference]) {
    final now = reference ?? DateTime.now();
    final nextHour = now.minute > 0 ? (now.hour + 1) % 24 : now.hour;
    return TimeOfDay(hour: nextHour, minute: 0);
  }

  static TimeOfDay _addOneHour(TimeOfDay time) {
    return TimeOfDay(hour: (time.hour + 1) % 24, minute: time.minute);
  }

  @override
  void initState() {
    super.initState();
    final now = widget.initialDate ?? DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day);
    _startTime = _getNextCompleteHour(DateTime.now());
    _endTime = _addOneHour(_startTime);

    if (widget.eventToEdit != null) {
      final event = widget.eventToEdit!;
      _titleController.text = event.title;
      _notesController.text = event.subtitle;
      _allDay = event.allDay;

      // 1. Parse Start Date and Start Time directly from start / start_time / startDate
      TimeOfDay? parsedStartTime;
      final startSource = event.startTime.isNotEmpty
          ? event.startTime
          : event.startDate;
      if (startSource.isNotEmpty) {
        final dt = DateTime.tryParse(startSource)?.toLocal();
        if (dt != null) {
          _startDate = DateTime(dt.year, dt.month, dt.day);
          if (startSource.contains('T') ||
              (startSource.contains(' ') && startSource.contains(':'))) {
            parsedStartTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
          }
        }
      }
      final parsedStart = _parseTimeOfDay(event.startTime);
      if (parsedStart != null) {
        parsedStartTime = parsedStart;
      }
      if (parsedStartTime != null) {
        _startTime = parsedStartTime;
      }

      // 2. Parse End Date and End Time directly from end / end_time / endDate
      TimeOfDay? parsedEndTime;
      final endSource = event.endTime.isNotEmpty
          ? event.endTime
          : event.endDate;
      if (endSource.isNotEmpty) {
        final dt = DateTime.tryParse(endSource)?.toLocal();
        if (dt != null) {
          _endDate = DateTime(dt.year, dt.month, dt.day);
          if (endSource.contains('T') ||
              (endSource.contains(' ') && endSource.contains(':'))) {
            parsedEndTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
          }
        }
      }
      final parsedEnd = _parseTimeOfDay(event.endTime);
      if (parsedEnd != null) {
        parsedEndTime = parsedEnd;
      }
      if (parsedEndTime != null) {
        _endTime = parsedEndTime;
      } else if (parsedStartTime != null) {
        _endTime = _addOneHour(_startTime);
      }
    }
  }

  TimeOfDay? _parseTimeOfDay(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    final clean = timeStr.trim();

    // 1. Try DateTime parse if it's ISO datetime string with time
    if (clean.contains(':') && (clean.contains('T') || clean.contains('-'))) {
      final dt = DateTime.tryParse(clean)?.toLocal();
      if (dt != null) {
        return TimeOfDay(hour: dt.hour, minute: dt.minute);
      }
    }

    // 2. 12-hour format: "10:30 AM", "10:30:00 AM", "10:30am", "9:00 PM"
    final amPmMatch = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM|am|pm)$',
      caseSensitive: false,
    ).firstMatch(clean);
    if (amPmMatch != null) {
      int hour = int.parse(amPmMatch.group(1)!);
      final minute = int.parse(amPmMatch.group(2)!);
      final isPm = amPmMatch.group(3)!.toUpperCase() == 'PM';
      if (isPm && hour < 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }

    // 3. 24-hour format: "14:30" or "14:30:00" or "09:15"
    final time24Match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?$',
    ).firstMatch(clean);
    if (time24Match != null) {
      final hour = int.parse(time24Match.group(1)!);
      final minute = int.parse(time24Match.group(2)!);
      if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }

    // 4. Fallback DateTime parse
    if (clean.contains(':')) {
      final dt = DateTime.tryParse(clean)?.toLocal();
      if (dt != null) {
        return TimeOfDay(hour: dt.hour, minute: dt.minute);
      }
    }

    return null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _titleFocusNode.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  void _unfocus() {
    _titleFocusNode.unfocus();
    _notesFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _pickStartDate() async {
    if (_isSubmitting || context.read<CalendarProvider>().isCreatingEvent) {
      return;
    }
    _unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030, 12, 31),
    );
    _unfocus();
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      });
    }
  }

  Future<void> _pickStartTime() async {
    if (_isSubmitting || context.read<CalendarProvider>().isCreatingEvent) {
      return;
    }
    _unfocus();
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    _unfocus();
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndDate() async {
    if (_isSubmitting || context.read<CalendarProvider>().isCreatingEvent) {
      return;
    }
    _unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2030, 12, 31),
    );
    _unfocus();
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _pickEndTime() async {
    if (_isSubmitting || context.read<CalendarProvider>().isCreatingEvent) {
      return;
    }
    _unfocus();
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    _unfocus();
    if (picked != null) setState(() => _endTime = picked);
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = (time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod)
        .toString()
        .padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatDateForApi(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _submitEvent() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_titleController.text.trim().isEmpty) {
      setState(() => _hasAttemptedSubmit = true);
      return;
    }

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final provider = context.read<CalendarProvider>();
    bool success = false;

    if (widget.eventToEdit != null) {
      final item = widget.eventToEdit!;
      final eventId = item.sourceId > 0
          ? item.sourceId
          : (int.tryParse(item.iid.isNotEmpty ? item.iid : item.id) ?? 0);

      success = await provider.updateEvent(
        id: eventId,
        title: _titleController.text.trim(),
        allDay: _allDay,
        startDate: _formatDateForApi(_startDate),
        endDate: _formatDateForApi(_endDate),
        startTime: _allDay ? null : _formatTime(_startTime),
        endTime: _allDay ? null : _formatTime(_endTime),
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );
    } else {
      success = await provider.createEvent(
        title: _titleController.text.trim(),
        allDay: _allDay,
        startDate: _formatDateForApi(_startDate),
        endDate: _formatDateForApi(_endDate),
        startTime: _allDay ? null : _formatTime(_startTime),
        endTime: _allDay ? null : _formatTime(_endTime),
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );
    }

    if (success && mounted) {
      setState(() => _isSubmitting = false);
      Navigator.pop(context, true);
    } else if (!success && mounted) {
      setState(() => _isSubmitting = false);
      if (provider.errorMessage != ErrorMessages.requestCancelled) {
        CustomSnackbar.show(
          context,
          message:
              provider.errorMessage ??
              AppLocalizations.of(context)?.failedToCreateEvent ??
              'Failed to create event',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sectionHeaderStyle = TextStyle(
      fontSize: 12.sp,
      fontWeight: FontWeight.w600,
      height: 16 / 12,
      color: isDark ? const Color(0xFFEAE1D8) : AppColors.tertiary,
    );

    final isSubmitting =
        _isSubmitting || context.watch<CalendarProvider>().isCreatingEvent;

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
              maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                body: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkTopCard : AppColors.light,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20.r),
                      topRight: Radius.circular(20.r),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AbsorbPointer(
                          absorbing: isSubmitting,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 0),
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
                                Text(
                                  widget.eventToEdit != null
                                      ? (AppLocalizations.of(
                                              context,
                                            )?.editEvent ??
                                            'Edit Event')
                                      : (AppLocalizations.of(
                                              context,
                                            )?.newEventTitle ??
                                            'New Event'),
                                  style: TextStyle(
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.w600,
                                    height: 28 / 20,
                                    color: isDark
                                        ? AppColors.white
                                        : AppColors.black,
                                  ),
                                ),
                                const Spacer(),
                                if (widget.eventToEdit != null &&
                                    widget.eventToEdit!.isDeletable)
                                  GestureDetector(
                                    onTap: () async {
                                      if (_isSubmitting) return;
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: Text(
                                            AppLocalizations.of(context)?.delete ??
                                                'Delete',
                                          ),
                                          content: Text(
                                            AppLocalizations.of(
                                                  context,
                                                )?.deleteEventConfirmation ??
                                                'Are you sure you want to delete this event?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: Text(
                                                AppLocalizations.of(context)?.cancel ??
                                                    'Cancel',
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: Text(
                                                AppLocalizations.of(context)?.delete ??
                                                    'Delete',
                                                style: TextStyle(color: Colors.red),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true && context.mounted) {
                                        setState(() => _isSubmitting = true);
                                        final provider = context
                                            .read<CalendarProvider>();
                                        final eventIdStr =
                                            widget.eventToEdit!.iid.isNotEmpty
                                            ? widget.eventToEdit!.iid
                                            : widget.eventToEdit!.id;
                                        final match = RegExp(
                                          r'\d+',
                                        ).firstMatch(eventIdStr);
                                        final eventId = match != null
                                            ? int.tryParse(match.group(0)!) ?? 0
                                            : 0;
                                        final nav = Navigator.of(context);
                                        final success = await provider
                                            .deleteEvent(eventId);
                                        if (success) {
                                          nav.pop(); // close bottom sheet
                                          nav.pop(); // close schedule log page
                                        } else if (!success && context.mounted) {
                                          setState(() => _isSubmitting = false);
                                          if (provider.errorMessage !=
                                              ErrorMessages.requestCancelled) {
                                            CustomSnackbar.show(
                                              context,
                                              message:
                                                  provider.errorMessage ??
                                                  AppLocalizations.of(
                                                    context,
                                                  )?.failedToDeleteEvent ??
                                                  'Failed to delete event',
                                              isError: true,
                                            );
                                          }
                                        }
                                      }
                                    },
                                    behavior: HitTestBehavior.opaque,
                                    child: CustomPaint(
                                      painter: GradientRectPainter(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: isDark
                                              ? [
                                                  Colors.white.withValues(
                                                    alpha: 0.3,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: 0.0,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: 0.3,
                                                  ),
                                                ]
                                              : [
                                                  Colors.white,
                                                  Colors.white.withValues(
                                                    alpha: 0.0,
                                                  ),
                                                  Colors.white,
                                                ],
                                          stops: const [0.0, 0.5, 1.0],
                                        ),
                                        strokeWidth: 1.5.w,
                                        radius: 100.r,
                                      ),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 14.w,
                                          vertical: 8.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? AppColors.darkCard
                                              : AppColors.white.withValues(alpha: 0.6),
                                          borderRadius: BorderRadius.circular(
                                            100.r,
                                          ),
                                          border: Border.all(
                                            color: AppColors.red.withValues(alpha: 0.1),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SvgPicture.asset(
                                              AppAssets.delete,
                                              width: 18.w,
                                              height: 18.w,
                                              colorFilter:
                                                  const ColorFilter.mode(
                                                    AppColors.red,
                                                    BlendMode.srcIn,
                                                  ),
                                            ),
                                            SizedBox(width: 4.w),
                                            Text(
                                              AppLocalizations.of(
                                                context,
                                              )?.delete ??
                                              'Delete',
                                              style: TextStyle(
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w400,
                                                color: AppColors.red,
                                                height: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 26.h),

                            // Scrollable content
                            Expanded(
                              child: SingleChildScrollView(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Event title section
                                    Text(
                                      AppLocalizations.of(
                                            context,
                                          )?.eventTitleLabel ??
                                          'Event title',
                                      style: sectionHeaderStyle,
                                    ),
                                    SizedBox(height: 10.5.h),
                                    TextField(
                                      controller: _titleController,
                                      focusNode: _titleFocusNode,
                                      onChanged: (val) {
                                        if (_hasAttemptedSubmit) {
                                          setState(() {});
                                        }
                                      },
                                      textAlignVertical:
                                          TextAlignVertical.center,
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w400,
                                        height: 20 / 14,
                                        color: isDark
                                            ? AppColors.white
                                            : AppColors.black,
                                      ),
                                      decoration: InputDecoration(
                                        hintText:
                                            AppLocalizations.of(
                                              context,
                                            )?.enterEventTitle ??
                                            'Enter event title...',
                                        hintStyle: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w400,
                                          height: 20 / 14,
                                          color: isDark
                                              ? const Color(0xFFA49D95)
                                              : AppColors.navColor,
                                        ),
                                        filled: true,
                                        fillColor:
                                            _hasAttemptedSubmit &&
                                                _titleController.text
                                                    .trim()
                                                    .isEmpty
                                            ? (isDark
                                                  ? const Color(0x26FD2323)
                                                  : const Color(0xFFFFEFEF))
                                            : isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.1,
                                              )
                                            : const Color(0xFFF6F3F2),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16.w,
                                          vertical: 16.h,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8.r,
                                          ),
                                          borderSide: BorderSide(
                                            color:
                                                _hasAttemptedSubmit &&
                                                    _titleController.text
                                                        .trim()
                                                        .isEmpty
                                                ? const Color(0xFFFD2323)
                                                : isDark
                                                ? Colors.transparent
                                                : const Color(0xFFD1C7B0),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8.r,
                                          ),
                                          borderSide: BorderSide(
                                            color:
                                                _hasAttemptedSubmit &&
                                                    _titleController.text
                                                        .trim()
                                                        .isEmpty
                                                ? const Color(0xFFFD2323)
                                                : isDark
                                                ? Colors.transparent
                                                : const Color(0xFFD1C7B0),
                                          ),
                                        ),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                    if (_hasAttemptedSubmit &&
                                        _titleController.text.trim().isEmpty)
                                      CustomErrorText(
                                        errorText:
                                            AppLocalizations.of(
                                              context,
                                            )?.enterEventTitleCorrectly ??
                                            '*Please enter a valid title',
                                      ),
                                    SizedBox(height: 26.h),

                                    // Date/Time card
                                    Container(
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.darkCard
                                            : Colors.white,
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(
                                                  0x4DE4BEB4,
                                                ).withValues(alpha: 0.3)
                                              : AppColors.shade,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                      ),
                                      padding: EdgeInsets.all(16.w),
                                      child: Column(
                                        children: [
                                          // All day row
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                AppLocalizations.of(
                                                      context,
                                                    )?.allDay ??
                                                    'All day',
                                                style: TextStyle(
                                                  fontSize: 14.sp,
                                                  fontWeight: FontWeight.w500,
                                                  height: 20 / 14,
                                                  color: isDark
                                                      ? AppColors.white
                                                      : AppColors.black,
                                                ),
                                              ),
                                              Switch(
                                                value: _allDay,
                                                onChanged: (v) {
                                                  FocusScope.of(
                                                    context,
                                                  ).unfocus();
                                                  setState(() => _allDay = v);
                                                },
                                                activeThumbColor:
                                                    AppColors.main,
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 12.h),
                                          Divider(
                                            height: 1,
                                            thickness: 0.5,
                                            color: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.15,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.3,
                                                  ),
                                          ),
                                          SizedBox(height: 12.h),

                                          // Starts row
                                          _buildDateTimeRow(
                                            context: context,
                                            label:
                                                AppLocalizations.of(
                                                  context,
                                                )?.starts ??
                                                'Starts',
                                            date: _startDate,
                                            time: _startTime,
                                            showTime: !_allDay,
                                            onDateTap: _pickStartDate,
                                            onTimeTap: _pickStartTime,
                                          ),
                                          SizedBox(height: 12.h),
                                          Divider(
                                            height: 1,
                                            thickness: 0.5,
                                            color: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.15,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.3,
                                                  ),
                                          ),
                                          SizedBox(height: 12.h),

                                          // Ends row
                                          _buildDateTimeRow(
                                            context: context,
                                            label:
                                                AppLocalizations.of(
                                                  context,
                                                )?.ends ??
                                                'Ends',
                                            date: _endDate,
                                            time: _endTime,
                                            showTime: !_allDay,
                                            onDateTap: _pickEndDate,
                                            onTimeTap: _pickEndTime,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 26.h),

                                    // Notes section
                                    Text(
                                      AppLocalizations.of(context)?.notes ??
                                          'Notes',
                                      style: sectionHeaderStyle,
                                    ),
                                    SizedBox(height: 10.5.h),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.1,
                                              )
                                            : Colors.white.withValues(
                                                alpha: 0.8,
                                              ),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.transparent
                                              : Colors.white,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                      ),
                                      padding: EdgeInsets.all(16.w),
                                      child: TextField(
                                        controller: _notesController,
                                        focusNode: _notesFocusNode,
                                        minLines: 4,
                                        maxLines: 4,
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w400,
                                          height: 20 / 14,
                                          color: isDark
                                              ? AppColors.white
                                              : AppColors.black,
                                        ),
                                        decoration: InputDecoration(
                                          hintText:
                                              AppLocalizations.of(
                                                context,
                                              )?.addNotes ??
                                              'Add notes...',
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

                    // Create event button (login button style)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        16.w,
                        10.h,
                        16.w,
                        MediaQuery.of(context).padding.bottom > 0
                            ? 5.73.h
                            : 16.h,
                      ),
                      color: isDark
                          ? AppColors.darkTopCard
                          : AppColors.midLight,
                      child: Consumer<CalendarProvider>(
                        builder: (context, provider, child) {
                          final isBusy =
                              provider.isCreatingEvent || _isSubmitting;
                          return InkWell(
                            onTap: isBusy ? null : _submitEvent,
                            borderRadius: BorderRadius.circular(8.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  transform: GradientRotation(11.57),
                                  colors: [
                                    Color(0xFFFF5722),
                                    Color(0xFFFF8A65),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0x40FF5722),
                                    blurRadius: 15.r,
                                    offset: Offset(0, 8.h),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  isBusy
                                      ? SizedBox(
                                          width: 24.w,
                                          height: 24.w,
                                          child:
                                              const CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                        )
                                      : Text(
                                          widget.eventToEdit != null
                                              ? (AppLocalizations.of(
                                                      context,
                                                    )?.saveChanges ??
                                                    'Save changes')
                                              : (AppLocalizations.of(
                                                      context,
                                                    )?.createEvent ??
                                                    'Create event'),
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w400,
                                            height: 24 / 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildDateTimeRow({
    required BuildContext context,
    required String label,
    required DateTime date,
    required TimeOfDay time,
    required bool showTime,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            height: 20 / 14,
            color: isDark ? AppColors.white : AppColors.black,
          ),
        ),
        Row(
          children: [
            _buildPickerPill(
              context: context,
              text: _formatDate(date),
              onTap: onDateTap,
            ),
            if (!showTime) const SizedBox.shrink(),
            if (showTime) ...[
              SizedBox(width: 10.w),
              _buildPickerPill(
                context: context,
                text: _formatTime(time),
                onTap: onTimeTap,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPickerPill({
    required BuildContext context,
    required String text,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBusy =
        _isSubmitting || context.watch<CalendarProvider>().isCreatingEvent;
    return GestureDetector(
      onTap: isBusy ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : const Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(7.r),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            height: 20 / 14,
            color: isDark ? AppColors.white : AppColors.black,
          ),
        ),
      ),
    );
  }
}
