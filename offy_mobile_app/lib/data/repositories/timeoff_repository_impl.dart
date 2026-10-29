import '../models/calendar_day_schedule_model.dart';
import '../models/calendar_month_response_model.dart';
import '../../domain/repositories/timeoff_repository.dart';
import '../datasources/timeoff_remote_data_source.dart';
import '../models/timeoff_response_model.dart';

class TimeOffRepositoryImpl implements TimeOffRepository {
  final TimeOffRemoteDataSource remoteDataSource;

  TimeOffRepositoryImpl({required this.remoteDataSource});

  @override
  Future<TimeOffResponseModel> getTimeOffData() async {
    return await remoteDataSource.getTimeOffData();
  }

  @override
  Future<TimeOffHistoryResponseModel> getTimeOffHistory({
    int page = 1,
    int limit = 10,
    String? search,
    Map<String, dynamic>? filters,
    bool forceRefresh = false,
  }) async {
    return await remoteDataSource.getTimeOffHistory(
      page: page,
      limit: limit,
      search: search,
      filters: filters,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<TimeOffHistoryResponseModel> getUpcomingLeaves({
    int page = 1,
    int limit = 10,
    String? search,
    Map<String, dynamic>? filters,
    bool forceRefresh = false,
  }) async {
    return await remoteDataSource.getUpcomingLeaves(
      page: page,
      limit: limit,
      search: search,
      filters: filters,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<List<TimeOffTypeModel>> getTimeOffTypes() async {
    return await remoteDataSource.getTimeOffTypes();
  }

  @override
  Future<TimeOffDurationModel> calculateTimeOffDuration({
    required int typeId,
    required String startDate,
    required String endDate,
  }) async {
    return await remoteDataSource.calculateTimeOffDuration(
      typeId: typeId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<void> submitTimeOffRequest({
    required int typeId,
    required String startDate,
    required String endDate,
    String? reason,
  }) async {
    await remoteDataSource.submitTimeOffRequest(
      typeId: typeId,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
    );
  }

  @override
  Future<CalendarMonthDataModel> getTimeOffCalendarMonth({
    required int year,
    required int month,
  }) async {
    return await remoteDataSource.getTimeOffCalendarMonth(
      year: year,
      month: month,
    );
  }

  @override
  Future<CalendarDayScheduleModel> getTimeOffCalendarDay({
    required String date,
  }) async {
    return await remoteDataSource.getTimeOffCalendarDay(date: date);
  }
}
