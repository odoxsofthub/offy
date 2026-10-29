import '../../core/utils/api_parser_utils.dart';

class CalendarMonthDataModel {
  final int year;
  final int month;
  final String? monthLabel;
  final bool? isSuccess;
  final List<CalendarDayModel> days;

  CalendarMonthDataModel({
    required this.year,
    required this.month,
    this.monthLabel,
    this.isSuccess,
    required this.days,
  });

  factory CalendarMonthDataModel.fromJson(Map<String, dynamic> json) {
    final map = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final daysList = map['days'] as List<dynamic>? ?? [];
    return CalendarMonthDataModel(
      year: parseField<int>(map['year']) ?? 0,
      month: parseField<int>(map['month']) ?? 0,
      monthLabel: parseField<String>(map['month_label']),
      isSuccess: parseField<bool>(json['success']) ?? parseField<bool>(map['success']),
      days: daysList
          .map((e) => CalendarDayModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CalendarDayModel {
  final String date;
  final int day;
  final int itemCount;
  final List<String> types;
  final List<String> colors;

  CalendarDayModel({
    required this.date,
    required this.day,
    required this.itemCount,
    required this.types,
    this.colors = const [],
  });

  factory CalendarDayModel.fromJson(Map<String, dynamic> json) {
    final rawTypes = (json['types'] ?? json['leave_types']) as List<dynamic>? ?? [];
    final List<String> parsedTypes = [];
    final List<String> parsedColors = [];

    for (final item in rawTypes) {
      if (item is Map<String, dynamic>) {
        final code = parseField<String>(item['code']) ??
            parseField<String>(item['leave_type_code']) ??
            parseField<String>(item['type']) ??
            parseField<String>(item['leave_type']) ??
            parseField<String>(item['name']) ??
            parseField<int>(item['id'])?.toString();
        if (code != null && code.isNotEmpty) {
          parsedTypes.add(code);
        }
        final color = parseField<String>(item['color']) ??
            parseField<String>(item['accent_color']);
        if (color != null && color.isNotEmpty) {
          parsedColors.add(color);
        }
      } else {
        final str = parseField<String>(item) ?? '';
        if (str.isNotEmpty) {
          parsedTypes.add(str);
        }
      }
    }

    final rawColors = json['colors'] as List<dynamic>? ?? [];
    for (final item in rawColors) {
      final colorStr = parseField<String>(item) ?? '';
      if (colorStr.isNotEmpty) {
        parsedColors.add(colorStr);
      }
    }

    return CalendarDayModel(
      date: parseField<String>(json['date']) ?? '',
      day: parseField<int>(json['day']) ?? 0,
      itemCount: parseField<int>(json['item_count']) ?? parsedTypes.length,
      types: parsedTypes,
      colors: parsedColors,
    );
  }
}
