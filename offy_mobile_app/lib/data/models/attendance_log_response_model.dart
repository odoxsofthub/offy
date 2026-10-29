import '../../core/utils/api_parser_utils.dart';
import 'expense_response_model.dart' show PaginationModel;

enum AttendanceLogStatus { active, completed, none }

enum AttendanceSessionType { checkIn, checkOut }

class AttendanceTimelineSessionModel {
  final int? id;
  final AttendanceSessionType type;
  final String time;
  final String? location;
  final DateTime? at;

  const AttendanceTimelineSessionModel({
    this.id,
    required this.type,
    required this.time,
    this.location,
    this.at,
  });

  factory AttendanceTimelineSessionModel.fromJson(Map<String, dynamic> json) {
    final typeStr = parseField<String>(json['type'])?.toLowerCase();
    final atStr = parseField<String>(json['at']);
    return AttendanceTimelineSessionModel(
      id: parseField<int>(json['id']),
      type: typeStr == 'checkout' || typeStr == 'check_out'
          ? AttendanceSessionType.checkOut
          : AttendanceSessionType.checkIn,
      time: parseField<String>(json['time']) ?? '',
      location: parseField<String>(json['location']),
      at: atStr != null ? DateTime.tryParse(atStr)?.toLocal() : null,
    );
  }
}

class AttendanceLogResponseModel {
  final List<AttendanceLogEntryModel> logs;
  final String avgInTime;
  final String avgWorkedHour;
  final PaginationModel pagination;

  AttendanceLogResponseModel({
    required this.logs,
    required this.avgInTime,
    required this.avgWorkedHour,
    required this.pagination,
  });

  factory AttendanceLogResponseModel.fromJson(Map<String, dynamic> json) {
    return AttendanceLogResponseModel(
      logs: json['logs'] != null
          ? List<AttendanceLogEntryModel>.from(
              json['logs'].map((x) => AttendanceLogEntryModel.fromJson(x)))
          : [],
      avgInTime: parseField<String>(json['avg_in_time']) ?? '-',
      avgWorkedHour: parseField<String>(json['avg_worked_hour']) ?? '-',
      pagination: json['pagination'] != null
          ? PaginationModel.fromJson(json['pagination'])
          : PaginationModel(
              page: 1, limit: 10, total: 0, hasNext: false, hasPrevious: false),
    );
  }
}

class AttendanceLogEntryModel {
  final String date;
  final String? workDate;
  final String timeInfo;
  final AttendanceLogStatus status;
  final String? rawStatus;
  final String? shiftDuration;
  final String? shiftStatus;
  final int? sessionCount;
  final List<AttendanceTimelineSessionModel>? sessions;
  final String? targetDuration;
  final double? completionPercentage;
  final String? rawCompletionPercentage;
  final String? targetReason;
  final String? targetReasonMessage;

  AttendanceLogEntryModel({
    required this.date,
    this.workDate,
    required this.timeInfo,
    required this.status,
    this.rawStatus,
    this.shiftDuration,
    this.shiftStatus,
    this.sessionCount,
    this.sessions,
    this.targetDuration,
    this.completionPercentage,
    this.rawCompletionPercentage,
    this.targetReason,
    this.targetReasonMessage,
  });

  factory AttendanceLogEntryModel.fromJson(Map<String, dynamic> json) {
    final rawStatus = parseField<String>(json['status']);
    final statusStr = rawStatus?.toLowerCase();
    AttendanceLogStatus parsedStatus = AttendanceLogStatus.none;
    if (statusStr == 'active') {
      parsedStatus = AttendanceLogStatus.active;
    } else if (statusStr == 'completed') {
      parsedStatus = AttendanceLogStatus.completed;
    }

    final sessionsJson = json['sessions'];
    List<AttendanceTimelineSessionModel>? parsedSessions;
    if (sessionsJson is List) {
      parsedSessions = sessionsJson
          .whereType<Map<String, dynamic>>()
          .map((x) => AttendanceTimelineSessionModel.fromJson(x))
          .toList();
    }

    final rawTarget = parseField<String>(json['targetDuration']) ??
        parseField<String>(json['target_duration']);

    final rawCompletionPct =
        parseField<String>(json['completionPercentage']) ??
            parseField<String>(json['completion_percentage']);

    double? parsedCompletionPercentage =
        parseField<double>(json['completionPercentage']) ??
            parseField<double>(json['completion_percentage']);

    if (parsedCompletionPercentage == null &&
        rawCompletionPct != null &&
        rawCompletionPct.isNotEmpty) {
      final sanitized =
          rawCompletionPct.replaceAll('%', '').trim().split(' ').first;
      parsedCompletionPercentage = double.tryParse(sanitized);
    }

    final rawReason = parseField<String>(json['targetReason']) ??
        parseField<String>(json['target_reason']);

    final rawReasonMessage =
        parseField<String>(json['targetReasonMessage']) ??
            parseField<String>(json['target_reason_message']);

    return AttendanceLogEntryModel(
      date: parseField<String>(json['date']) ?? '',
      workDate: parseField<String>(json['work_date']),
      timeInfo: parseField<String>(json['time_info']) ?? '',
      status: parsedStatus,
      rawStatus: rawStatus,
      shiftDuration: parseField<String>(json['shift_duration']),
      shiftStatus: parseField<String>(json['shift_status']),
      sessionCount: parseField<int>(json['session_count']),
      sessions: parsedSessions,
      targetDuration: rawTarget,
      completionPercentage: parsedCompletionPercentage,
      rawCompletionPercentage: rawCompletionPct,
      targetReason: rawReason,
      targetReasonMessage: rawReasonMessage,
    );
  }

  /// Returns the formatted status string coming directly from the API.
  String get displayStatus {
    if (shiftStatus != null && shiftStatus!.trim().isNotEmpty) {
      return shiftStatus!.trim();
    }
    if (rawStatus != null && rawStatus!.trim().isNotEmpty) {
      final s = rawStatus!.trim();
      return s[0].toUpperCase() + s.substring(1);
    }
    switch (status) {
      case AttendanceLogStatus.active:
        return 'Active';
      case AttendanceLogStatus.completed:
        return 'Completed';
      case AttendanceLogStatus.none:
        return '–';
    }
  }

  /// Returns explicit sessions or derives them from [timeInfo] and [status].
  List<AttendanceTimelineSessionModel> get effectiveSessions {
    if (sessions != null && sessions!.isNotEmpty) {
      return sessions!;
    }

    final List<AttendanceTimelineSessionModel> result = [];
    if (timeInfo.isEmpty || timeInfo == '–' || timeInfo == '-') {
      return result;
    }

    final rawTimes = timeInfo.split(RegExp(r'\s*[–-]\s*'));
    if (rawTimes.isEmpty || rawTimes[0].trim().isEmpty) {
      return result;
    }

    result.add(
      AttendanceTimelineSessionModel(
        type: AttendanceSessionType.checkIn,
        time: rawTimes[0].trim(),
        location: null,
      ),
    );

    if (status == AttendanceLogStatus.completed && rawTimes.length > 1) {
      final secondPart = rawTimes[1].trim();
      if (secondPart.toLowerCase() != 'present' &&
          secondPart.toLowerCase() != 'clock out') {
        result.add(
          AttendanceTimelineSessionModel(
            type: AttendanceSessionType.checkOut,
            time: secondPart,
            location: null,
          ),
        );
      }
    }

    return result;
  }

  /// Extracts the hours portion of the logged time, defaulting to '00'.
  String get loggedHours {
    if (shiftDuration != null && shiftDuration!.isNotEmpty) {
      final match = RegExp(r'(\d+)\s*h', caseSensitive: false).firstMatch(shiftDuration!);
      if (match != null) {
        return match.group(1)!.padLeft(2, '0');
      }
    }
    return '00';
  }

  /// Extracts the minutes portion of the logged time, defaulting to '00'.
  String get loggedMinutes {
    if (shiftDuration != null && shiftDuration!.isNotEmpty) {
      final match = RegExp(r'(\d+)\s*m', caseSensitive: false).firstMatch(shiftDuration!);
      if (match != null) {
        return match.group(1)!.padLeft(2, '0');
      }
    }
    return '00';
  }

  /// Target duration string for the shift, falling back to '-' if missing/empty.
  String get targetHoursText =>
      (targetDuration != null && targetDuration!.trim().isNotEmpty)
          ? targetDuration!.trim()
          : '-';

  /// Completion percentage normalized from 0.0 to 1.0, or null if not provided.
  double? get completionProgress {
    if (completionPercentage == null) return null;
    return (completionPercentage! / 100.0).clamp(0.0, 1.0);
  }

  /// Exact completion percentage string with % symbol, or null if missing.
  String? get completionPercentageText {
    if (rawCompletionPercentage != null &&
        rawCompletionPercentage!.trim().isNotEmpty) {
      final trimmed = rawCompletionPercentage!.trim();
      return trimmed.endsWith('%') ? trimmed : '$trimmed%';
    }
    if (completionPercentage != null) {
      final val = completionPercentage!;
      final str = (val % 1 == 0) ? val.toInt().toString() : val.toString();
      return '$str%';
    }
    return null;
  }
}

