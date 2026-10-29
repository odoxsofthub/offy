import '../../core/utils/api_parser_utils.dart';
import 'access_details_response_model.dart';

class HomeDataModel {
  final HomeContentModel? home;

  HomeDataModel({this.home});

  factory HomeDataModel.fromJson(Map<String, dynamic> json) {
    return HomeDataModel(
      home: json['home'] is Map<String, dynamic>
          ? HomeContentModel.fromJson(json['home'])
          : null,
    );
  }

  HomeDataModel copyWith({HomeContentModel? home}) {
    return HomeDataModel(home: home ?? this.home);
  }
}

class HomeContentModel {
  final AttendanceStatusModel? attendance;
  final double? totalRemainingLeave;
  final HomePayslipModel? payslip;
  final HomeExpenseModel? expense;
  final HomeCalendarModel? calendar;
  final bool hasUnreadNotifications;

  HomeContentModel({
    this.attendance,
    this.totalRemainingLeave,
    this.payslip,
    this.expense,
    this.calendar,
    this.hasUnreadNotifications = false,
  });

  factory HomeContentModel.fromJson(Map<String, dynamic> json) {
    return HomeContentModel(
      attendance: json['attendance'] is Map<String, dynamic>
          ? AttendanceStatusModel.fromJson(json['attendance'])
          : null,
      totalRemainingLeave: parseField<double>(json['total_remaining_leave']),
      payslip: json['payslip'] is Map<String, dynamic>
          ? HomePayslipModel.fromJson(json['payslip'])
          : null,
      expense: json['expense'] is Map<String, dynamic>
          ? HomeExpenseModel.fromJson(json['expense'])
          : null,
      calendar: json['calendar'] is Map<String, dynamic>
          ? HomeCalendarModel.fromJson(json['calendar'])
          : null,
      hasUnreadNotifications:
          parseField<bool>(json['has_unread_notifications']) ?? false,
    );
  }

  HomeContentModel copyWith({
    AttendanceStatusModel? attendance,
    double? totalRemainingLeave,
    HomePayslipModel? payslip,
    HomeExpenseModel? expense,
    HomeCalendarModel? calendar,
    bool? hasUnreadNotifications,
  }) {
    return HomeContentModel(
      attendance: attendance ?? this.attendance,
      totalRemainingLeave: totalRemainingLeave ?? this.totalRemainingLeave,
      payslip: payslip ?? this.payslip,
      expense: expense ?? this.expense,
      calendar: calendar ?? this.calendar,
      hasUnreadNotifications:
          hasUnreadNotifications ?? this.hasUnreadNotifications,
    );
  }
}

class AttendanceStatusModel {
  final bool enabled;
  final String status;
  final String? checkIn;
  final String? checkOut;
  final String? displayTime;

  AttendanceStatusModel({
    required this.enabled,
    required this.status,
    this.checkIn,
    this.checkOut,
    this.displayTime,
  });

  factory AttendanceStatusModel.fromJson(Map<String, dynamic> json) {
    return AttendanceStatusModel(
      enabled: parseField<bool>(json['enabled']) ?? false,
      status: parseField<String>(json['status']) ?? 'not_checked_in',
      checkIn: parseField<String>(json['check_in']),
      checkOut: parseField<String>(json['check_out']),
      displayTime: parseField<String>(json['display_time']),
    );
  }
}

class HomePayslipModel {
  final bool enabled;
  final String? month;
  final dynamic finalAmount;
  final CurrencyModel? currency;

  HomePayslipModel({
    required this.enabled,
    this.month,
    this.finalAmount,
    this.currency,
  });

  factory HomePayslipModel.fromJson(Map<String, dynamic> json) {
    return HomePayslipModel(
      enabled: parseField<bool>(json['enabled']) ?? false,
      month: parseField<String>(json['month']),
      finalAmount: parseField<Object>(json['final_amount']),
      currency: json['currency'] is Map<String, dynamic>
          ? CurrencyModel.fromJson(json['currency'])
          : null,
    );
  }
}

class HomeExpenseModel {
  final bool enabled;
  final String? month;
  final dynamic totalAmount;
  final CurrencyModel? currency;

  HomeExpenseModel({
    required this.enabled,
    this.month,
    this.totalAmount,
    this.currency,
  });

  factory HomeExpenseModel.fromJson(Map<String, dynamic> json) {
    return HomeExpenseModel(
      enabled: parseField<bool>(json['enabled']) ?? false,
      month: parseField<String>(json['month']),
      totalAmount: parseField<Object>(json['total_amount']),
      currency: json['currency'] is Map<String, dynamic>
          ? CurrencyModel.fromJson(json['currency'])
          : null,
    );
  }
}

class HomeCalendarModel {
  final bool enabled;
  final String? date;
  final List<HomeCalendarItemModel> items;

  HomeCalendarModel({required this.enabled, this.date, required this.items});

  factory HomeCalendarModel.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List<dynamic>? ?? [];
    return HomeCalendarModel(
      enabled: parseField<bool>(json['enabled']) ?? false,
      date: parseField<String>(json['date']),
      items: itemsList
          .whereType<Map<String, dynamic>>()
          .map((e) => HomeCalendarItemModel.fromJson(e))
          .toList(),
    );
  }
}

class HomeCalendarItemModel {
  final int id;
  final String title;
  final String subtitle;
  final String type;
  final String accentColor;

  HomeCalendarItemModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.accentColor,
  });

  factory HomeCalendarItemModel.fromJson(Map<String, dynamic> json) {
    return HomeCalendarItemModel(
      id: parseField<int>(json['id']) ?? 0,
      title:
          parseField<String>(json['note']) ??
          parseField<String>(json['title']) ??
          '',
      subtitle:
          parseField<String>(json['time']) ??
          parseField<String>(json['subtitle']) ??
          '',
      type: parseField<String>(json['type']) ?? '',
      accentColor: parseField<String>(json['accent_color']) ?? '',
    );
  }
}
