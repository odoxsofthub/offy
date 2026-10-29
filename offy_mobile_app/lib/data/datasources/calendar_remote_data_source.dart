import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../models/calendar_month_response_model.dart';
import '../models/calendar_day_schedule_model.dart';

abstract class CalendarRemoteDataSource {
  Future<CalendarMonthDataModel> getCalendarMonth({
    required int year,
    required int month,
  });

  Future<CalendarDayScheduleModel> getCalendarDay({required String date});

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

class CalendarRemoteDataSourceImpl implements CalendarRemoteDataSource {
  final ApiClient apiClient;

  CalendarRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<CalendarMonthDataModel> getCalendarMonth({
    required int year,
    required int month,
  }) async {
    final response = await apiClient.get<CalendarMonthDataModel>(
      ApiConstants.calendarMonth,
      queryParameters: {'year': year, 'month': month},
      parser: (json) =>
          CalendarMonthDataModel.fromJson(json as Map<String, dynamic>),
    );
    if (response.data != null) {
      return response.data!;
    } else {
      throw const AppException('Failed to load calendar month data');
    }
  }

  @override
  Future<CalendarDayScheduleModel> getCalendarDay({
    required String date,
  }) async {
    final response = await apiClient.get<CalendarDayScheduleModel>(
      ApiConstants.calendarDay,
      queryParameters: {'date': date},
      parser: (json) => CalendarDayScheduleModel.fromJson(json),
    );
    if (response.data != null) {
      return response.data!;
    } else {
      throw const AppException('Failed to load calendar day schedule');
    }
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
    final Map<String, dynamic> data = {
      'title': title,
      'all_day': allDay,
      'start_date': startDate,
      'end_date': endDate,
      'start_time': startTime,
      'end_time': endTime,
      'notes': notes,
    };

    final response = await apiClient.post<bool>(
      ApiConstants.calendarEvents,
      body: data,
      parser: (json) => true,
      isSubmission: true,
    );
    return response.success;
  }

  @override
  Future<bool> deleteEvent({required int id}) async {
    try {
      final response = await apiClient.delete<bool>(
        ApiConstants.deleteCalendarEvent(id),
        parser: (json) => true,
      );
      return response.success;
    } on AppException catch (e) {
      if (e.statusCode == 404 || (e.message != null && e.message!.toLowerCase().contains('not found'))) {
        return true;
      }
      rethrow;
    }
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
    final Map<String, dynamic> data = {
      'title': title,
      'all_day': allDay,
      'start_date': startDate,
      'end_date': endDate,
      'start_time': startTime,
      'end_time': endTime,
      'notes': notes,
    };

    final response = await apiClient.patch<bool>(
      ApiConstants.updateCalendarEvent(id),
      body: data,
      parser: (json) => true,
      isSubmission: true,
    );
    return response.success;
  }
}
