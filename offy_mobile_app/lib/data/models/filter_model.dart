import 'package:flutter/material.dart';
import '../../core/utils/api_parser_utils.dart';

enum FilterSource {
  timeoff('timeoff'),
  expense('expense'),
  payslip('payslip');

  final String value;
  const FilterSource(this.value);

  static FilterSource fromString(String raw) {
    return FilterSource.values.firstWhere(
      (e) => e.value.toLowerCase() == raw.trim().toLowerCase(),
      orElse: () => FilterSource.expense,
    );
  }
}

enum FilterOption {
  month('month'),
  category('category'),
  leaveType('leave_type'),
  status('status'),
  dateRange('date_range');

  final String value;
  const FilterOption(this.value);

  static FilterOption fromString(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'month':
        return FilterOption.month;
      case 'category':
      case 'categories':
        return FilterOption.category;
      case 'leave_type':
      case 'leave_types':
      case 'type':
      case 'types':
        return FilterOption.leaveType;
      case 'status':
      case 'statuses':
        return FilterOption.status;
      case 'date_range':
      case 'daterange':
        return FilterOption.dateRange;
      default:
        return FilterOption.month;
    }
  }

  static FilterOption? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return fromString(raw);
  }
}

class FilterOptionsResponseModel {
  final bool success;
  final String message;
  final FilterOptionsDataModel? data;

  FilterOptionsResponseModel({
    required this.success,
    required this.message,
    this.data,
  });

  factory FilterOptionsResponseModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? dataMap =
        (json.containsKey('data') && json['data'] is Map<String, dynamic>)
            ? json['data'] as Map<String, dynamic>
            : (json.containsKey('options') || json.containsKey('source')
                ? json
                : null);
    return FilterOptionsResponseModel(
      success: parseField<bool>(json['success']) ?? (dataMap != null),
      message: parseField<String>(json['message']) ?? '',
      data: dataMap != null ? FilterOptionsDataModel.fromJson(dataMap) : null,
    );
  }
}

class FilterOptionsDataModel {
  final String source;
  final List<FilterOptionItemModel> options;
  final String applyUrl;
  final ActiveFilterModel? active;

  FilterSource get filterSource => FilterSource.fromString(source);

  FilterOptionsDataModel({
    required this.source,
    required this.options,
    required this.applyUrl,
    this.active,
  });

  factory FilterOptionsDataModel.fromJson(Map<String, dynamic> json) {
    final rawOptions = parseField<List>(json['options']);
    return FilterOptionsDataModel(
      source: parseField<String>(json['source']) ?? '',
      options: rawOptions != null
          ? rawOptions
              .whereType<Map<String, dynamic>>()
              .map((e) => FilterOptionItemModel.fromJson(e))
              .toList()
          : [],
      applyUrl: parseField<String>(json['apply_url']) ?? '',
      active: json['active'] != null && json['active'] is Map<String, dynamic>
          ? ActiveFilterModel.fromJson(json['active'] as Map<String, dynamic>)
          : null,
    );
  }
}

class FilterOptionItemModel {
  final String option;
  final String label;
  final String selection;
  final String url;

  FilterOption get filterOption => FilterOption.fromString(option);

  FilterOptionItemModel({
    required this.option,
    required this.label,
    required this.selection,
    required this.url,
  });

  factory FilterOptionItemModel.fromJson(Map<String, dynamic> json) {
    return FilterOptionItemModel(
      option: parseField<String>(json['option']) ?? '',
      label: parseField<String>(json['label']) ?? '',
      selection: parseField<String>(json['selection']) ?? 'multi',
      url: parseField<String>(json['url']) ?? '',
    );
  }
}

class ActiveFilterModel {
  final List<int> categoryIds;
  final List<int> typeIds;
  final List<String> monthIds;
  final List<String> statusIds;
  final dynamic dateRange;

  ActiveFilterModel({
    required this.categoryIds,
    this.typeIds = const [],
    required this.monthIds,
    this.statusIds = const [],
    this.dateRange,
  });

  factory ActiveFilterModel.fromJson(Map<String, dynamic> json) {
    final rawCatIds = parseField<List>(json['category_ids']);
    final rawTypeIds = parseField<List>(json['type_ids']) ??
        parseField<List>(json['leave_type_ids']) ??
        parseField<List>(json['types']) ??
        rawCatIds;
    final rawMonthIds = parseField<List>(json['month_ids']);
    final rawStatusIds = parseField<List>(json['status_ids']) ??
        parseField<List>(json['statuses']);
    return ActiveFilterModel(
      categoryIds: rawCatIds != null
          ? rawCatIds
              .map((e) => parseField<int>(e) ?? int.tryParse(e.toString()) ?? 0)
              .where((id) => id > 0)
              .toList()
          : [],
      typeIds: rawTypeIds != null
          ? rawTypeIds
              .map((e) => parseField<int>(e) ?? int.tryParse(e.toString()) ?? 0)
              .where((id) => id > 0)
              .toList()
          : [],
      monthIds: rawMonthIds != null
          ? rawMonthIds
              .map((e) => parseField<String>(e) ?? e.toString())
              .where((m) => m.isNotEmpty)
              .toList()
          : [],
      statusIds: rawStatusIds != null
          ? rawStatusIds
              .map((e) => parseField<String>(e) ?? e.toString())
              .where((s) => s.isNotEmpty)
              .toList()
          : [],
      dateRange: json['date_range'],
    );
  }

  DateTimeRange? get parsedDateRange {
    if (dateRange is Map) {
      final map = Map<String, dynamic>.from(dateRange as Map);
      final fromStr = map['from_date'] ?? map['from'] ?? map['start'];
      final toStr = map['to_date'] ?? map['to'] ?? map['end'];
      if (fromStr != null && toStr != null) {
        final from = DateTime.tryParse(fromStr.toString());
        final to = DateTime.tryParse(toStr.toString());
        if (from != null && to != null) {
          return DateTimeRange(start: from, end: to);
        }
      }
    }
    return null;
  }
}

class FilterContentResponseModel {
  final bool success;
  final String message;
  final FilterContentDataModel? data;

  FilterContentResponseModel({
    required this.success,
    required this.message,
    this.data,
  });

  factory FilterContentResponseModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? dataMap =
        (json.containsKey('data') && json['data'] is Map<String, dynamic>)
            ? json['data'] as Map<String, dynamic>
            : (json.containsKey('option') ||
                    json.containsKey('items') ||
                    json.containsKey('buckets')
                ? json
                : null);
    return FilterContentResponseModel(
      success: parseField<bool>(json['success']) ?? (dataMap != null),
      message: parseField<String>(json['message']) ?? '',
      data: dataMap != null ? FilterContentDataModel.fromJson(dataMap) : null,
    );
  }
}

class FilterContentDataModel {
  final String option;
  final String source;
  final String selection;
  final String? level;
  final String? bucket;
  final bool customRangeAvailable;
  final List<FilterBucketModel> buckets;
  final List<FilterItemModel> items;

  FilterContentDataModel({
    required this.option,
    required this.source,
    required this.selection,
    this.level,
    this.bucket,
    this.customRangeAvailable = false,
    required this.buckets,
    required this.items,
  });

  factory FilterContentDataModel.fromJson(Map<String, dynamic> json) {
    final rawBuckets = parseField<List>(json['buckets']);
    final rawItems = parseField<List>(json['items']);
    return FilterContentDataModel(
      option: parseField<String>(json['option']) ?? '',
      source: parseField<String>(json['source']) ?? '',
      selection: parseField<String>(json['selection']) ?? 'multi',
      level: parseField<String>(json['level']),
      bucket: parseField<String>(json['bucket']),
      customRangeAvailable:
          parseField<bool>(json['custom_range_available']) ?? false,
      buckets: rawBuckets != null
          ? rawBuckets
              .whereType<Map<String, dynamic>>()
              .map((e) => FilterBucketModel.fromJson(e))
              .toList()
          : [],
      items: rawItems != null
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map((e) => FilterItemModel.fromJson(e))
              .toList()
          : [],
    );
  }
}

class FilterBucketModel {
  final String key;
  final String label;

  FilterBucketModel({
    required this.key,
    required this.label,
  });

  factory FilterBucketModel.fromJson(Map<String, dynamic> json) {
    return FilterBucketModel(
      key: parseField<String>(json['key']) ?? '',
      label: parseField<String>(json['label']) ?? '',
    );
  }
}

class FilterItemModel {
  final dynamic id;
  final String label;

  FilterItemModel({
    required this.id,
    required this.label,
  });

  factory FilterItemModel.fromJson(Map<String, dynamic> json) {
    return FilterItemModel(
      id: json['id'],
      label: parseField<String>(json['label']) ?? '',
    );
  }

  int get idAsInt =>
      id is int ? (id as int) : (int.tryParse(id?.toString() ?? '') ?? 0);
  String get idAsString => id?.toString() ?? '';
}

class FilterApplyResponseModel {
  final bool success;
  final String message;
  final FilterApplyDataModel? data;

  FilterApplyResponseModel({
    required this.success,
    required this.message,
    this.data,
  });

  factory FilterApplyResponseModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? dataMap =
        (json.containsKey('data') && json['data'] is Map<String, dynamic>)
            ? json['data'] as Map<String, dynamic>
            : (json.containsKey('source') ||
                    json.containsKey('active') ||
                    json.containsKey('cleared')
                ? json
                : null);
    return FilterApplyResponseModel(
      success: parseField<bool>(json['success']) ?? (dataMap != null),
      message: parseField<String>(json['message']) ?? '',
      data: dataMap != null ? FilterApplyDataModel.fromJson(dataMap) : null,
    );
  }
}

class FilterApplyDataModel {
  final String source;
  final String option;
  final bool cleared;
  final ActiveFilterModel? active;

  FilterApplyDataModel({
    required this.source,
    required this.option,
    required this.cleared,
    this.active,
  });

  factory FilterApplyDataModel.fromJson(Map<String, dynamic> json) {
    return FilterApplyDataModel(
      source: parseField<String>(json['source']) ?? '',
      option: parseField<String>(json['option']) ?? '',
      cleared: parseField<bool>(json['cleared']) ?? false,
      active: json['active'] != null && json['active'] is Map<String, dynamic>
          ? ActiveFilterModel.fromJson(json['active'] as Map<String, dynamic>)
          : null,
    );
  }
}
