import '../../data/models/calendar_month_response_model.dart';
import '../../data/models/calendar_day_schedule_model.dart';

abstract class CalendarRepository {
  Future<CalendarMonthDataModel> getCalendarMonth({
    required int year,
    required int month,
  });

  Future<CalendarDayScheduleModel> getCalendarDay({
    required String date,
  });

  Future<bool> createEvent({
    required String title,
    required bool allDay,
    required String startDate,
    required String endDate,
    String? startTime,
    String? endTime,
    String? notes,
  });

  Future<bool> deleteEvent({required int id});

  Future<bool> updateEvent({
    required int id,
    required String title,
    required bool allDay,
    required String startDate,
    required String endDate,
    String? startTime,
    String? endTime,
    String? notes,
  });
}
