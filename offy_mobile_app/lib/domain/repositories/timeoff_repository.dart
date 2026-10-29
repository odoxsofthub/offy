import '../../data/models/calendar_day_schedule_model.dart';
import '../../data/models/calendar_month_response_model.dart';
import '../../data/models/timeoff_response_model.dart';

abstract class TimeOffRepository {
  Future<TimeOffResponseModel> getTimeOffData();
  Future<TimeOffHistoryResponseModel> getTimeOffHistory({
    int page = 1,
    int limit = 10,
    String? search,
    Map<String, dynamic>? filters,
    bool forceRefresh = false,
  });
  Future<TimeOffHistoryResponseModel> getUpcomingLeaves({
    int page = 1,
    int limit = 10,
    String? search,
    Map<String, dynamic>? filters,
    bool forceRefresh = false,
  });
  Future<List<TimeOffTypeModel>> getTimeOffTypes();
  Future<TimeOffDurationModel> calculateTimeOffDuration({
    required int typeId,
    required String startDate,
    required String endDate,
  });
  Future<void> submitTimeOffRequest({
    required int typeId,
    required String startDate,
    required String endDate,
    String? reason,
  });
  Future<CalendarMonthDataModel> getTimeOffCalendarMonth({
    required int year,
    required int month,
  });
  Future<CalendarDayScheduleModel> getTimeOffCalendarDay({
    required String date,
  });
}
