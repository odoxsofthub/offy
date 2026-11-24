import 'package:flutter/material.dart';
import '../../core/utils/api_parser_utils.dart';

class TimeOffResponseModel {
  final bool? success;
  final String? message;
  final TimeOffDataModel? data;

  TimeOffResponseModel({this.success, this.message, this.data});

  factory TimeOffResponseModel.fromJson(Map<String, dynamic> json) {
    // Parse `data` when present, otherwise the map itself.
    final dataMap =
        json.containsKey('data') && json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    return TimeOffResponseModel(
      success: parseField<bool>(json['success']),
      message: parseField<String>(json['message']),
      data: TimeOffDataModel.fromJson(dataMap),
    );
  }

  // Convenience getters for backward compatibility
  List<TimeOffBalanceModel>? get balances => data?.balances;
  num? get totalRemainingLeave => data?.totalRemainingLeave;
  List<TimeOffLeaveItemModel>? get upcoming => data?.upcoming;
  bool? get moreUpcoming => data?.moreUpcoming;
  List<TimeOffLeaveItemModel>? get history => data?.history;
}

class TimeOffDataModel {
  final List<TimeOffBalanceModel>? balances;
  final num? totalRemainingLeave;
  final List<TimeOffLeaveItemModel>? upcoming;
  final bool? moreUpcoming;
  final List<TimeOffLeaveItemModel>? history;

  TimeOffDataModel({
    this.balances,
    this.totalRemainingLeave,
    this.upcoming,
    this.moreUpcoming,
    this.history,
  });

  factory TimeOffDataModel.fromJson(Map<String, dynamic> json) {
    final rawBalances = parseField<List>(json['balances']);
    final rawUpcoming = parseField<List>(json['upcoming']);
    final rawHistory = parseField<List>(json['history']);

    return TimeOffDataModel(
      balances: rawBalances
          ?.whereType<Map<String, dynamic>>()
          .map((e) => TimeOffBalanceModel.fromJson(e))
          .toList(),
      totalRemainingLeave: parseField<num>(json['total_remaining_leave']),
      upcoming: rawUpcoming
          ?.whereType<Map<String, dynamic>>()
          .map((e) => TimeOffLeaveItemModel.fromJson(e))
          .toList(),
      moreUpcoming: parseField<bool>(json['more_upcoming']),
      history: rawHistory
          ?.whereType<Map<String, dynamic>>()
          .map((e) => TimeOffLeaveItemModel.fromJson(e))
          .toList(),
    );
  }
}

class TimeOffBalanceModel {
  final int id;
  final String name;
  final num remaining;
  final num totalAllocated;
  final num taken;
  final num pending;
  final String unit;

  TimeOffBalanceModel({
    required this.id,
    required this.name,
    required this.remaining,
    required this.totalAllocated,
    required this.taken,
    required this.pending,
    required this.unit,
  });

  factory TimeOffBalanceModel.fromJson(Map<String, dynamic> json) {
    return TimeOffBalanceModel(
      id: parseField<int>(json['id']) ?? 0,
      name: parseField<String>(json['name']) ?? '',
      remaining: parseField<num>(json['remaining']) ?? 0,
      totalAllocated: parseField<num>(json['total_allocated']) ?? 0,
      taken: parseField<num>(json['taken']) ?? 0,
      pending: parseField<num>(json['pending']) ?? 0,
      unit: parseField<String>(json['unit']) ?? '',
    );
  }
}

enum TimeOffLeaveStage {
  approved,
  rejected,
  pending,
  custom;

  static TimeOffLeaveStage fromString(String? stage) {
    switch (stage?.toLowerCase()) {
      case 'approved' || 'validate' || 'validated':
        return TimeOffLeaveStage.approved;
      case 'rejected' || 'refuse' || 'refused':
        return TimeOffLeaveStage.rejected;
      case 'pending' || 'confirm' || 'confirmed':
        return TimeOffLeaveStage.pending;
      default:
        return TimeOffLeaveStage.custom;
    }
  }

  Color getColor({bool isDark = false}) {
    switch (this) {
      case TimeOffLeaveStage.approved:
        return isDark ? const Color(0xFF51FF45) : const Color(0xFF076330);
      case TimeOffLeaveStage.pending:
      case TimeOffLeaveStage.custom:
        return isDark ? const Color(0xFFFFD52E) : const Color(0xFFAB8D13);
      case TimeOffLeaveStage.rejected:
        return isDark ? const Color(0xFFE61E1E) : const Color(0xFFFF5722);
    }
  }
}

class TimeOffLeaveModel {
  final String timeline;
  final List<TimeOffLeaveItemModel> leaves;

  TimeOffLeaveModel({
    required this.timeline,
    this.leaves = const [],
  });

  factory TimeOffLeaveModel.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('timeline') || json.containsKey('leaves')) {
      final rawLeaves = parseField<List>(json['leaves']);
      return TimeOffLeaveModel(
        timeline: parseField<String>(json['timeline']) ?? '',
        leaves: rawLeaves != null
            ? rawLeaves
                .whereType<Map<String, dynamic>>()
                .map((e) => TimeOffLeaveItemModel.fromJson(e))
                .toList()
            : const [],
      );
    }
    return TimeOffLeaveModel(
      timeline: '',
      leaves: [TimeOffLeaveItemModel.fromJson(json)],
    );
  }
}

class TimeOffLeaveItemModel {
  final int id;
  final String name;
  final LeaveTypeModel? leaveType;
  final String dateFrom;
  final String dateTo;
  final num days;
  final String stage;
  final String stageDisplay;

  TimeOffLeaveItemModel({
    required this.id,
    required this.name,
    this.leaveType,
    required this.dateFrom,
    required this.dateTo,
    required this.days,
    required this.stage,
    this.stageDisplay = '',
  });

  TimeOffLeaveStage get stageEnum => TimeOffLeaveStage.fromString(stage);

  factory TimeOffLeaveItemModel.fromJson(Map<String, dynamic> json) {
    final stageVal = parseField<String>(json['stage']) ?? '';
    final rawStageDisplay = parseField<String>(json['stage_display']);
    final fallbackDisplay = stageVal.isNotEmpty
        ? '${stageVal[0].toUpperCase()}${stageVal.substring(1)}'
        : '';
    final rawLeaveType = parseField<Map>(json['leave_type']);

    return TimeOffLeaveItemModel(
      id: parseField<int>(json['id']) ?? 0,
      name: parseField<String>(json['name']) ?? '',
      leaveType: rawLeaveType != null
          ? LeaveTypeModel.fromJson(Map<String, dynamic>.from(rawLeaveType))
          : null,
      dateFrom: parseField<String>(json['date_from']) ?? '',
      dateTo: parseField<String>(json['date_to']) ?? '',
      days: parseField<num>(json['days']) ?? 0,
      stage: stageVal,
      stageDisplay:
          (rawStageDisplay != null && rawStageDisplay.trim().isNotEmpty)
          ? rawStageDisplay
          : fallbackDisplay,
    );
  }
}

class LeaveTypeModel {
  final int id;
  final String name;

  LeaveTypeModel({required this.id, required this.name});

  factory LeaveTypeModel.fromJson(Map<String, dynamic> json) {
    return LeaveTypeModel(
      id: parseField<int>(json['id']) ?? 0,
      name: parseField<String>(json['name']) ?? '',
    );
  }
}

class TimeOffTypeModel {
  final int id;
  final String name;
  final String code;
  final num? remaining;
  final String remainingDisplay;
  final String unit;
  final bool isUnlimited;
  final bool canApply;
  final bool requiresAllocation;
  final bool supportsNegative;
  final String color;

  TimeOffTypeModel({
    required this.id,
    required this.name,
    required this.code,
    this.remaining,
    required this.remainingDisplay,
    required this.unit,
    required this.isUnlimited,
    required this.canApply,
    required this.requiresAllocation,
    required this.supportsNegative,
    required this.color,
  });

  factory TimeOffTypeModel.fromJson(Map<String, dynamic> json) {
    return TimeOffTypeModel(
      id: parseField<int>(json['id']) ?? 0,
      name: parseField<String>(json['name']) ?? '',
      code: parseField<String>(json['code']) ?? '',
      remaining: parseField<num>(json['remaining']),
      remainingDisplay: parseField<String>(json['remaining_display']) ?? '',
      unit: parseField<String>(json['unit']) ?? '',
      isUnlimited: parseField<bool>(json['is_unlimited']) ?? false,
      canApply: parseField<bool>(json['can_apply']) ?? false,
      requiresAllocation:
          parseField<bool>(json['requires_allocation']) ?? false,
      supportsNegative: parseField<bool>(json['supports_negative']) ?? false,
      color: parseField<String>(json['color']) ?? '#FFFFFF',
    );
  }
}

class TimeOffPaginationModel {
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  TimeOffPaginationModel({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  factory TimeOffPaginationModel.fromJson(Map<String, dynamic> json) {
    return TimeOffPaginationModel(
      page: parseField<int>(json['page']) ?? 1,
      pageSize: parseField<int>(json['page_size']) ?? 10,
      total: parseField<int>(json['total']) ?? 0,
      totalPages: parseField<int>(json['total_pages']) ?? 1,
    );
  }

  bool get hasNext => page < totalPages;
}

class TimeOffHistoryResponseModel {
  final List<TimeOffLeaveModel> leaves;
  final TimeOffPaginationModel pagination;

  TimeOffHistoryResponseModel({required this.leaves, required this.pagination});

  factory TimeOffHistoryResponseModel.fromList(List<dynamic> list) {
    final parsedLeaves = list
        .whereType<Map<String, dynamic>>()
        .map((x) => TimeOffLeaveModel.fromJson(x))
        .toList();
    return TimeOffHistoryResponseModel(
      leaves: parsedLeaves,
      pagination: TimeOffPaginationModel(
        page: 1,
        pageSize: parsedLeaves.isNotEmpty ? parsedLeaves.length : 10,
        total: parsedLeaves.length,
        totalPages: 1,
      ),
    );
  }

  factory TimeOffHistoryResponseModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> target =
        (json.containsKey('data') && json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;
    final rawLeaves =
        parseField<List>(target['leaves']) ??
        parseField<List>(target['items']) ??
        parseField<List>(target['records']) ??
        parseField<List>(target['upcoming']) ??
        parseField<List>(target['history']) ??
        (json.containsKey('data') && json['data'] is List
            ? json['data'] as List
            : null);

    final paginationMap =
        target['pagination'] != null &&
            target['pagination'] is Map<String, dynamic>
        ? target['pagination'] as Map<String, dynamic>
        : (json['pagination'] != null &&
                  json['pagination'] is Map<String, dynamic>
              ? json['pagination'] as Map<String, dynamic>
              : null);

    final parsedLeaves = rawLeaves != null
        ? rawLeaves
              .whereType<Map<String, dynamic>>()
              .map((i) => TimeOffLeaveModel.fromJson(i))
              .toList()
        : <TimeOffLeaveModel>[];

    return TimeOffHistoryResponseModel(
      leaves: parsedLeaves,
      pagination: paginationMap != null
          ? TimeOffPaginationModel.fromJson(paginationMap)
          : TimeOffPaginationModel(
              page: 1,
              pageSize: 10,
              total: parsedLeaves.length,
              totalPages: 1,
            ),
    );
  }
}

class TimeOffDurationModel {
  final num duration;
  final String unit;
  final String display;
  final String startDate;
  final String endDate;
  final bool canApply;
  final String? warning;

  TimeOffDurationModel({
    required this.duration,
    required this.unit,
    required this.display,
    required this.startDate,
    required this.endDate,
    required this.canApply,
    this.warning,
  });

  factory TimeOffDurationModel.fromJson(Map<String, dynamic> json) {
    return TimeOffDurationModel(
      duration: parseField<num>(json['duration']) ?? 0,
      unit: parseField<String>(json['unit']) ?? '',
      display: parseField<String>(json['display']) ?? '',
      startDate: parseField<String>(json['start_date']) ?? '',
      endDate: parseField<String>(json['end_date']) ?? '',
      canApply: parseField<bool>(json['can_apply']) ?? false,
      warning: parseField<String>(json['warning']),
    );
  }
}
