import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';

class AppDateFormatter {
  // Private DateFormat instances (Hidden from external usage)
  static final DateFormat _dmyDash = DateFormat('dd-MM-yyyy');
  static final DateFormat _dmySlash = DateFormat('dd/MM/yyyy');
  static final DateFormat _ymdSlash = DateFormat('yyyy-MM-dd');
  static final DateFormat _mmmDdYyyy = DateFormat('MMM dd, yyyy');
  static final DateFormat _mmmmDdYyyy = DateFormat('MMMM dd, yyyy');
  static final DateFormat _mmmmDd = DateFormat('MMMM dd');
  static final DateFormat _mmmDd = DateFormat('MMM dd');
  static final DateFormat _mmm = DateFormat('MMM');
  static final DateFormat _dd = DateFormat('dd');
  static final DateFormat _mmmYyyy = DateFormat('MMM yyyy');
  static final DateFormat _dMmmmYyyy = DateFormat('d MMMM yyyy');
  static final DateFormat _dMmmYyyy = DateFormat('d MMM yyyy');
  static final DateFormat _hhMmA = DateFormat('hh:mm a');
  static final DateFormat _hhMmADMmmYyyy = DateFormat('hh:mm a, d MMM yyyy');


  /// Formats a DateTime to "dd-MM-yyyy" (e.g., "09-07-2026")
  static String dmyDash(DateTime date) => _dmyDash.format(date);

  /// Formats a DateTime to "dd/MM/yyyy" (e.g., "09/07/2026")
  static String dmySlash(DateTime date) => _dmySlash.format(date);

  /// Formats a DateTime to "yyyy-MM-dd" (e.g., "2026-07-09")
  static String ymdSlash(DateTime date) => _ymdSlash.format(date);

  /// Formats a DateTime to "MMM dd, yyyy" (e.g., "Jul 09, 2026")
  static String mmmDdYyyy(DateTime date) => _mmmDdYyyy.format(date);

  /// Formats a DateTime to "MMMM dd, yyyy" (e.g., "July 09, 2026")
  static String mmmmDdYyyy(DateTime date) => _mmmmDdYyyy.format(date);

  /// Formats a DateTime to uppercase "MMM" (e.g., "JUL")
  static String mmmUppercase(DateTime date) => _mmm.format(date).toUpperCase();

  /// Formats a DateTime to "dd" (e.g., "09")
  static String dd(DateTime date) => _dd.format(date);

  /// Formats a DateTime to "MMM yyyy" (e.g., "Jul 2026")
  static String mmmYyyy(DateTime date) => _mmmYyyy.format(date);

  /// Formats a DateTime to "MMM dd" (e.g., "Jul 09")
  static String mmmDd(DateTime date) => _mmmDd.format(date);

  /// Formats current date for home header (e.g., "9 July 2026")
  static String homeHeader(DateTime dateTime) => _dMmmmYyyy.format(dateTime);

  /// Formats a time directly (e.g., "09:30 AM")
  static String time(DateTime dateTime) => _hhMmA.format(dateTime);

  /// Formats an ISO string time, returns '--:--' on parse error (e.g., "09:30 AM")
  static String formatTimeStr(String? isoTime) {
    if (isoTime == null) return '--:--';
    try {
      final dateTime = DateTime.parse(isoTime).toLocal();
      return time(dateTime);
    } catch (_) {
      return '--:--';
    }
  }

  /// Formats an ISO string time and date, returns '--:--' on parse error (e.g., "09:30 AM, 12 Dec 2026")
  static String formatDateTimeStr(String? isoTime) {
    if (isoTime == null) return '--:--';
    try {
      final dateTime = DateTime.parse(isoTime).toLocal();
      return _hhMmADMmmYyyy.format(dateTime);
    } catch (_) {
      return '--:--';
    }
  }

  /// Formats an ISO string date, returns empty string on parse error (e.g., "12 Dec 2026")
  static String formatDateStr(String? isoTime) {
    if (isoTime == null) return '';
    try {
      final dateTime = DateTime.parse(isoTime).toLocal();
      return _dMmmYyyy.format(dateTime);
    } catch (_) {
      return '';
    }
  }

  /// Formats any single digit hour time in string to 2-digit "00:00" format (e.g., "9:00 AM" -> "09:00 AM", "9:00 - 1:30" -> "09:00 - 01:30")
  static String formatTimeDisplay(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return '';
    return timeStr.replaceAllMapped(
      RegExp(r'(^|\D)(\d):(\d{2})'),
      (match) => '${match.group(1)}0${match.group(2)}:${match.group(3)}',
    );
  }

  /// Formats a time range from start, end, or fallback time display string into "00:00 AM - 00:00 PM" format
  static String formatTimeRange({
    String? start,
    String? end,
    String? fallbackTimeDisplay,
  }) {
    final sTime = _parseAndFormatSingleTime(start);
    final eTime = _parseAndFormatSingleTime(end);

    if (sTime.isNotEmpty && eTime.isNotEmpty) {
      return '$sTime - $eTime';
    }

    if (fallbackTimeDisplay != null && fallbackTimeDisplay.trim().isNotEmpty) {
      return _formatRangeString(fallbackTimeDisplay.trim());
    }

    if (sTime.isNotEmpty) return sTime;
    if (eTime.isNotEmpty) return eTime;

    return '';
  }

  static String _formatRangeString(String rangeStr) {
    if (!rangeStr.contains('-') && !rangeStr.contains('–')) {
      return _parseAndFormatSingleTime(rangeStr);
    }

    final delimiter = rangeStr.contains('–') ? '–' : '-';
    final parts = rangeStr.split(delimiter);
    if (parts.length != 2) return formatTimeDisplay(rangeStr);

    final startPart = parts[0].trim();
    final endPart = parts[1].trim();

    final startHasExplicitPeriod = startPart.toUpperCase().contains('AM') ||
        startPart.toUpperCase().contains('PM');
    final endFormatted = _parseAndFormatSingleTime(endPart);
    var startFormatted = _parseAndFormatSingleTime(startPart);

    if (!startHasExplicitPeriod &&
        (endFormatted.contains('AM') || endFormatted.contains('PM'))) {
      final endIsPm = endFormatted.contains('PM');
      final startHourMatch =
          RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(startPart);
      final endHourMatch =
          RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(endFormatted);
      if (startHourMatch != null && endHourMatch != null) {
        final startH = int.parse(startHourMatch.group(1)!);
        final startM = startHourMatch.group(2)!;
        final endH = int.parse(endHourMatch.group(1)!);
        String period;
        if (endIsPm) {
          if (startH > endH && startH != 12) {
            period = 'AM';
          } else {
            period = 'PM';
          }
        } else {
          period = 'AM';
        }
        final start12H = (startH % 12 == 0 ? 12 : startH % 12)
            .toString()
            .padLeft(2, '0');
        startFormatted = '$start12H:$startM $period';
      }
    }

    if (startFormatted.isNotEmpty && endFormatted.isNotEmpty) {
      return '$startFormatted - $endFormatted';
    }
    return formatTimeDisplay(rangeStr);
  }

  static String _parseAndFormatSingleTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final clean = raw.trim();

    if (clean.contains(':') &&
        (clean.contains('T') || clean.contains('-') || clean.contains(' '))) {
      final dt = DateTime.tryParse(clean)?.toLocal();
      if (dt != null) {
        return time(dt);
      }
    }

    final amPmMatch = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM|am|pm)$',
      caseSensitive: false,
    ).firstMatch(clean);
    if (amPmMatch != null) {
      final hour = int.parse(amPmMatch.group(1)!).toString().padLeft(2, '0');
      final minute = amPmMatch.group(2)!;
      final period = amPmMatch.group(3)!.toUpperCase();
      return '$hour:$minute $period';
    }

    final time24Match =
        RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(clean);
    if (time24Match != null) {
      int hour = int.parse(time24Match.group(1)!);
      final minute = time24Match.group(2)!;
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 =
          (hour % 12 == 0 ? 12 : hour % 12).toString().padLeft(2, '0');
      return '$hour12:$minute $period';
    }

    return formatTimeDisplay(clean);
  }


  /// Formats history range (e.g., "July 14, 2026" or "July 14 - July 18, 2026")
  static String leaveHistoryRangeLong(DateTime dateFrom, DateTime dateTo) {
    if (dateFrom.year == dateTo.year &&
        dateFrom.month == dateTo.month &&
        dateFrom.day == dateTo.day) {
      return _mmmmDdYyyy.format(dateFrom);
    }
    return '${_mmmmDd.format(dateFrom)} - ${_mmmmDdYyyy.format(dateTo)}';
  }

  /// Formats history range from strings, returns empty string on error
  static String formatLeaveHistoryRangeLongStr(String start, String end) {
    try {
      if (start.isEmpty || end.isEmpty) return '';
      return leaveHistoryRangeLong(DateTime.parse(start), DateTime.parse(end));
    } catch (_) {
      return '';
    }
  }

  /// Formats history range (e.g., "Jul 14, 2026" or "Jul 14 - Jul 18, 2026")
  static String leaveHistoryRangeShort(DateTime dateFrom, DateTime dateTo) {
    if (dateFrom.year == dateTo.year &&
        dateFrom.month == dateTo.month &&
        dateFrom.day == dateTo.day) {
      return _mmmDdYyyy.format(dateFrom);
    }
    return '${_mmmDd.format(dateFrom)} - ${_mmmDdYyyy.format(dateTo)}';
  }

  /// Formats history range from strings, returns empty string on error
  static String formatLeaveHistoryRangeShortStr(String start, String end) {
    try {
      if (start.isEmpty || end.isEmpty) return '';
      return leaveHistoryRangeShort(DateTime.parse(start), DateTime.parse(end));
    } catch (_) {
      return '';
    }
  }

  /// Formats date range for calendar log: "MMM startdate, - MMM enddate, yyyy" (e.g., "Jul 09, - Jul 12, 2026")
  static String calendarLogRange(DateTime dateFrom, DateTime dateTo) {
    if (dateFrom.year == dateTo.year &&
        dateFrom.month == dateTo.month &&
        dateFrom.day == dateTo.day) {
      return _mmmDdYyyy.format(dateFrom);
    }
    if (dateFrom.year == dateTo.year) {
      return '${_mmmDd.format(dateFrom)} - ${_mmmDd.format(dateTo)}, ${dateTo.year}';
    }
    return '${_mmmDdYyyy.format(dateFrom)} - ${_mmmDdYyyy.format(dateTo)}';
  }

  /// Formats range from strings for calendar log
  static String formatCalendarLogRangeStr(String start, String end) {
    try {
      final s = start.trim();
      final e = end.trim();
      if (s.isEmpty && e.isEmpty) return '';
      if (s.isNotEmpty && e.isEmpty) {
        return _mmmDdYyyy.format(DateTime.parse(s));
      }
      if (s.isEmpty && e.isNotEmpty) {
        return _mmmDdYyyy.format(DateTime.parse(e));
      }
      final dtStart = DateTime.parse(s);
      final dtEnd = DateTime.parse(e);
      return calendarLogRange(dtStart, dtEnd);
    } catch (_) {
      final s = start.trim();
      final e = end.trim();
      if (s.isNotEmpty && e.isNotEmpty) return '$s - $e';
      return s.isNotEmpty ? s : e;
    }
  }

  /// Formats date range for time off log: "MMM startdate, - MMM enddate, yyyy (days)" (e.g., "Jul 09, - Jul 12, 2026 (3)")
  static String formatTimeOffLogRangeStr(String start, String end, num days) {
    final daysInt = days.toInt();
    try {
      final s = start.trim();
      final e = end.trim();
      if (s.isEmpty && e.isEmpty) return '($daysInt)';
      if (s.isNotEmpty && e.isEmpty) {
        final dt = DateTime.parse(s);
        return '${_mmmDdYyyy.format(dt)} ($daysInt)';
      }
      if (s.isEmpty && e.isNotEmpty) {
        final dt = DateTime.parse(e);
        return '${_mmmDdYyyy.format(dt)} ($daysInt)';
      }
      final dtStart = DateTime.parse(s);
      final dtEnd = DateTime.parse(e);
      return '${calendarLogRange(dtStart, dtEnd)} ($daysInt)';
    } catch (_) {
      final s = start.trim();
      final e = end.trim();
      final range = (s.isNotEmpty && e.isNotEmpty)
          ? '$s - $e'
          : (s.isNotEmpty ? s : e);
      return '$range ($daysInt)';
    }
  }

  /// Formats notification time (e.g., "5m ago", "3h ago", or "5:30 PM")
  static String notificationTime(DateTime date, {AppLocalizations? l10n}) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      if (difference.inMinutes <= 0) {
        return l10n?.justNow ?? 'Just now';
      }
      return l10n?.minutesAgo(difference.inMinutes.toString()) ??
          '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return l10n?.hoursAgo(difference.inHours.toString()) ??
          '${difference.inHours}h ago';
    } else {
      final hour = date.hour > 12
          ? date.hour - 12
          : (date.hour == 0 ? 12 : date.hour);
      final amPm = date.hour >= 12 ? 'PM' : 'AM';
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute $amPm';
    }
  }
}
