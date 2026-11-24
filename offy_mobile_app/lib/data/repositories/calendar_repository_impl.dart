import '../../domain/repositories/calendar_repository.dart';
import '../datasources/calendar_remote_data_source.dart';
import '../models/calendar_month_response_model.dart';
import '../models/calendar_day_schedule_model.dart';

class CalendarRepositoryImpl implements CalendarRepository {
  final CalendarRemoteDataSource remoteDataSource;

  CalendarRepositoryImpl({required this.remoteDataSource});

  @override
  Future<CalendarMonthDataModel> getCalendarMonth({
    required int year,
    required int month,
  }) async {
    return await remoteDataSource.getCalendarMonth(year: year, month: month);
  }

  @override
  Future<CalendarDayScheduleModel> getCalendarDay({
    required String date,
  }) async {
    return await remoteDataSource.getCalendarDay(date: date);
  }

  @override
  Future<bool> createEvent({
    required String title,
    required bool allDay,
    required String startDate,
    required String endDate,
    String? startTime,
    String? endTime,
    String? notes,
  }) async {
    return await remoteDataSource.createEvent(
      title: title,
      allDay: allDay,
      startDate: startDate,
      endDate: endDate,
      startTime: startTime,
      endTime: endTime,
      notes: notes,
    );
  }

  @override
  Future<bool> deleteEvent({required int id}) async {
    return await remoteDataSource.deleteEvent(id: id);
  }

  @override
  Future<bool> updateEvent({
    required int id,
    required String title,
    required bool allDay,
    required String startDate,
    required String endDate,
    String? startTime,
    String? endTime,
    String? notes,
  }) async {
    return await remoteDataSource.updateEvent(
      id: id,
      title: title,
      allDay: allDay,
      startDate: startDate,
      endDate: endDate,
      startTime: startTime,
      endTime: endTime,
      notes: notes,
    );
  }
}
