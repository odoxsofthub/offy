import 'package:flutter/material.dart';
import '../../core/utils/api_parser_utils.dart';

class CalendarDayScheduleModel {
  final String date;
  final String dateLabel;
  final bool? isSuccess;
  final List<CalendarScheduleItemModel> items;

  CalendarDayScheduleModel({
    required this.date,
    this.dateLabel = '',
    this.isSuccess,
    required this.items,
  });

  factory CalendarDayScheduleModel.fromJson(Object? json) {
    if (json == null) {
      return CalendarDayScheduleModel(date: '', dateLabel: '', items: []);
    }

    if (json is List) {
      return CalendarDayScheduleModel(
        date: '',
        dateLabel: '',
        items: json
            .map(
              (e) => CalendarScheduleItemModel.fromJson(
                e is Map<String, dynamic> ? e : {},
              ),
            )
            .toList(),
      );
    }

    if (json is Map<String, dynamic>) {
      final map = json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : json;

      final String dateStr = parseField<String>(map['date']) ?? '';
      final String labelStr = parseField<String>(map['date_label']) ??
          parseField<String>(map['day_label']) ??
          '';
      final bool? successBool =
          parseField<bool>(json['success']) ?? parseField<bool>(map['success']);
      final rawItems = (map['items'] ??
              map['schedules'] ??
              map['events'] ??
              map['days'] ??
              []) as List<dynamic>;

      return CalendarDayScheduleModel(
        date: dateStr,
        dateLabel: labelStr,
        isSuccess: successBool,
        items: rawItems
            .map(
              (e) => CalendarScheduleItemModel.fromJson(
                e is Map<String, dynamic> ? e : {},
              ),
            )
            .toList(),
      );
    }

    return CalendarDayScheduleModel(date: '', dateLabel: '', items: []);
  }
}

class CalendarScheduleItemModel {
  final String id;
  final String iid;
  final String sourceModel;
  final int sourceId;
  final String title;
  final String subtitle;
  final String reason;
  final String leaveType;
  final String leaveTypeCode;
  final String type;
  final String startDate;
  final String endDate;
  final String startTime;
  final String endTime;
  final num duration;
  final String durationDisplay;
  final String summaryDisplay;
  final String status;
  final String statusDisplay;
  final bool? isLeave;
  final bool? isApproved;
  final Color accentColor;
  final bool allDay;
  final String timeDisplay;
  final bool isDeletable;
  final bool isEditable;

  CalendarScheduleItemModel({
    required this.id,
    required this.iid,
    this.sourceModel = '',
    this.sourceId = 0,
    required this.title,
    required this.subtitle,
    this.reason = '',
    this.leaveType = '',
    this.leaveTypeCode = '',
    this.type = '',
    this.startDate = '',
    this.endDate = '',
    this.startTime = '',
    this.endTime = '',
    this.duration = 0,
    this.durationDisplay = '',
    this.summaryDisplay = '',
    this.status = '',
    this.statusDisplay = '',
    this.isLeave,
    this.isApproved,
    required this.accentColor,
    this.allDay = false,
    this.timeDisplay = '',
    this.isDeletable = false,
    this.isEditable = false,
  });

  factory CalendarScheduleItemModel.fromJson(Map<String, dynamic> json) {
    final String rawTitle = parseField<String>(json['title']) ??
        parseField<String>(json['name']) ??
        'Event';

    final String rawSummaryDisplay =
        parseField<String>(json['summary_display']) ?? '';

    final String rawSubtitle = rawSummaryDisplay.isNotEmpty
        ? rawSummaryDisplay
        : (parseField<String>(json['subtitle']) ??
            parseField<String>(json['description']) ??
            parseField<String>(json['duration_display']) ??
            parseField<String>(json['display_time']) ??
            parseField<String>(json['time']) ??
            '');

    final bool parsedAllDay = parseField<bool>(json['all_day']) ?? false;

    final String parsedTimeDisplay =
        parseField<String>(json['time_display']) ??
        parseField<String>(json['display_time']) ??
        parseField<String>(json['time']) ??
        '';

    final String parsedType = parseField<String>(json['type']) ?? '';
    final String rawType = parseField<String>(json['leave_type']) ??
        parsedType;

    final String? colorHex = parseField<String>(json['color']) ??
        parseField<String>(json['accent_color']);

    Color resolvedColor;
    if (colorHex != null && colorHex.isNotEmpty) {
      resolvedColor = _parseHexColor(colorHex);
    } else {
      final typeLower = rawType.toLowerCase();
      if (typeLower.contains('leave') || typeLower.contains('timeoff')) {
        resolvedColor = const Color(0xFF076330);
      } else {
        resolvedColor = const Color(0xFFFF5722);
      }
    }

    return CalendarScheduleItemModel(
      id: parseField<String>(json['id']) ?? '',
      iid: parseField<String>(json['iid']) ?? '',
      sourceModel: parseField<String>(json['source_model']) ?? '',
      sourceId: parseField<int>(json['source_id']) ?? 0,
      title: rawTitle,
      subtitle: rawSubtitle,
      reason: parseField<String>(json['reason']) ?? '',
      leaveType: parseField<String>(json['leave_type']) ?? '',
      leaveTypeCode: parseField<String>(json['leave_type_code']) ?? '',
      type: parsedType.isNotEmpty
          ? parsedType
          : (parseField<String>(json['leave_type']) ?? ''),
      startDate: parseField<String>(json['start']) ??
          parseField<String>(json['start_date']) ??
          '',
      endDate: parseField<String>(json['end']) ??
          parseField<String>(json['end_date']) ??
          '',
      startTime: parseField<String>(json['start']) ??
          parseField<String>(json['start_time']) ??
          parseField<String>(json['startTime']) ??
          '',
      endTime: parseField<String>(json['end']) ??
          parseField<String>(json['end_time']) ??
          parseField<String>(json['endTime']) ??
          '',
      duration: parseField<num>(json['duration']) ?? 0,
      durationDisplay: parseField<String>(json['duration_display']) ?? '',
      summaryDisplay: rawSummaryDisplay,
      status: parseField<String>(json['status']) ?? '',
      statusDisplay: parseField<String>(json['status_display']) ?? '',
      isLeave: parseField<bool>(json['is_leave']),
      isApproved: parseField<bool>(json['is_approved']),
      accentColor: resolvedColor,
      allDay: parsedAllDay,
      timeDisplay: parsedTimeDisplay,
      isDeletable: parseField<bool>(json['is_deletable']) ?? false,
      isEditable: parseField<bool>(json['is_editable']) ?? false,
    );
  }

  CalendarScheduleItemModel copyWith({
    String? title,
    String? subtitle,
    String? type,
    String? sourceModel,
    int? sourceId,
    String? startDate,
    String? endDate,
    String? startTime,
    String? endTime,
    bool? allDay,
    String? timeDisplay,
    bool? isEditable,
  }) {
    return CalendarScheduleItemModel(
      id: id,
      iid: iid,
      sourceModel: sourceModel ?? this.sourceModel,
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      reason: reason,
      leaveType: leaveType,
      leaveTypeCode: leaveTypeCode,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration,
      durationDisplay: durationDisplay,
      summaryDisplay: summaryDisplay,
      status: status,
      statusDisplay: statusDisplay,
      isLeave: isLeave,
      isApproved: isApproved,
      accentColor: accentColor,
      allDay: allDay ?? this.allDay,
      timeDisplay: timeDisplay ?? this.timeDisplay,
      isDeletable: isDeletable,
      isEditable: isEditable ?? this.isEditable,
    );
  }

  static Color _parseHexColor(String hexString) {
    final String cleanHex = hexString.replaceAll('#', '').trim();
    if (cleanHex.length == 6) {
      final int value = int.parse('FF$cleanHex', radix: 16);
      return Color(value);
    } else if (cleanHex.length == 8) {
      final int value = int.parse(cleanHex, radix: 16);
      return Color(value);
    }
    return const Color(0xFFFF5722);
  }
}
