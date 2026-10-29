import '../../core/constants/api_constants.dart';
import '../../core/constants/app_globals.dart';
import '../../core/errors/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../core/network/mock_api_data.dart';
import '../models/calendar_day_schedule_model.dart';
import '../models/calendar_month_response_model.dart';
import '../models/timeoff_response_model.dart';

abstract class TimeOffRemoteDataSource {
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

class TimeOffRemoteDataSourceImpl implements TimeOffRemoteDataSource {
  final ApiClient client;
  final Map<String, Future<TimeOffHistoryResponseModel>>
      _inFlightUpcomingLeavesRequests = {};
  final Map<String, Future<TimeOffHistoryResponseModel>>
      _inFlightHistoryRequests = {};

  TimeOffRemoteDataSourceImpl({required this.client});

  @override
  Future<TimeOffResponseModel> getTimeOffData() async {
    final response = await client.get(
      ApiConstants.timeOff,
      parser: (json) =>
          TimeOffResponseModel.fromJson(json as Map<String, dynamic>),
    );
    if (response.data != null) {
      return response.data as TimeOffResponseModel;
    }
    throw const AppException('Time off data response was empty');
  }

  @override
  Future<TimeOffHistoryResponseModel> getTimeOffHistory({
    int page = 1,
    int limit = 10,
    String? search,
    Map<String, dynamic>? filters,
    bool forceRefresh = false,
  }) async {
    if (AppGlobals.isDesignMode) {
      await Future.delayed(const Duration(seconds: 1));
      return TimeOffHistoryResponseModel.fromJson(
        MockApiData.getMockResponse('GET', ApiConstants.timeOffHistory)['data']
            as Map<String, dynamic>,
      );
    }

    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': limit.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (filters != null && filters.isNotEmpty) {
      filters.forEach((key, value) {
        if (value != null) {
          queryParams[key] = value.toString();
        }
      });
    }

    final queryString = queryParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final url = '${ApiConstants.timeOffHistory}?$queryString';

    if (!forceRefresh && _inFlightHistoryRequests.containsKey(url)) {
      return _inFlightHistoryRequests[url]!;
    }

    final future = _fetchTimeOffHistory(url);
    _inFlightHistoryRequests[url] = future;
    try {
      return await future;
    } finally {
      _inFlightHistoryRequests.remove(url);
    }
  }

  Future<TimeOffHistoryResponseModel> _fetchTimeOffHistory(String url) async {
    final response = await client.get<TimeOffHistoryResponseModel>(
      url,
      parser: (json) {
        if (json is Map<String, dynamic>) {
          return TimeOffHistoryResponseModel.fromJson(json);
        } else if (json is List) {
          return TimeOffHistoryResponseModel.fromList(json);
        }
        return TimeOffHistoryResponseModel(
          leaves: const [],
          pagination: TimeOffPaginationModel(
            page: 1,
            pageSize: 10,
            total: 0,
            totalPages: 1,
          ),
        );
      },
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw AppException(response.message);
    }
  }

  @override
  Future<TimeOffHistoryResponseModel> getUpcomingLeaves({
    int page = 1,
    int limit = 10,
    String? search,
    Map<String, dynamic>? filters,
    bool forceRefresh = false,
  }) async {
    if (AppGlobals.isDesignMode) {
      await Future.delayed(const Duration(seconds: 1));
      return TimeOffHistoryResponseModel.fromJson(
        MockApiData.getMockResponse('GET', ApiConstants.timeOffUpcoming)['data']
            as Map<String, dynamic>,
      );
    }

    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': limit.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (filters != null && filters.isNotEmpty) {
      filters.forEach((key, value) {
        if (value != null) {
          queryParams[key] = value.toString();
        }
      });
    }

    final queryString = queryParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final url = '${ApiConstants.timeOffUpcoming}?$queryString';

    if (!forceRefresh && _inFlightUpcomingLeavesRequests.containsKey(url)) {
      return _inFlightUpcomingLeavesRequests[url]!;
    }

    final future = _fetchUpcomingLeaves(url);
    _inFlightUpcomingLeavesRequests[url] = future;
    try {
      return await future;
    } finally {
      _inFlightUpcomingLeavesRequests.remove(url);
    }
  }

  Future<TimeOffHistoryResponseModel> _fetchUpcomingLeaves(String url) async {
    final response = await client.get<TimeOffHistoryResponseModel>(
      url,
      parser: (json) {
        if (json is Map<String, dynamic>) {
          return TimeOffHistoryResponseModel.fromJson(json);
        } else if (json is List) {
          return TimeOffHistoryResponseModel.fromList(json);
        }
        return TimeOffHistoryResponseModel(
          leaves: const [],
          pagination: TimeOffPaginationModel(
            page: 1,
            pageSize: 10,
            total: 0,
            totalPages: 1,
          ),
        );
      },
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw AppException(response.message);
    }
  }

  @override
  Future<List<TimeOffTypeModel>> getTimeOffTypes() async {
    if (AppGlobals.isDesignMode) {
      await Future.delayed(const Duration(seconds: 1));
      final jsonList = MockApiData.getMockResponse(
        'GET',
        ApiConstants.timeOffTypes,
      )['data'];
      if (jsonList is List) {
        return jsonList
            .map((e) => TimeOffTypeModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    final response = await client.get<List<TimeOffTypeModel>>(
      ApiConstants.timeOffTypes,
      parser: (json) {
        if (json is List) {
          return json
              .map((e) => TimeOffTypeModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        return [];
      },
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw AppException(response.message);
    }
  }

  @override
  Future<TimeOffDurationModel> calculateTimeOffDuration({
    required int typeId,
    required String startDate,
    required String endDate,
  }) async {
    if (AppGlobals.isDesignMode) {
      await Future.delayed(const Duration(seconds: 1));
      final jsonData = MockApiData.getMockResponse(
        'POST',
        ApiConstants.timeOffDuration,
      )['data'];
      return TimeOffDurationModel.fromJson(jsonData as Map<String, dynamic>);
    }

    final payload = {
      "time_off_type_id": typeId,
      "start_date": startDate,
      "end_date": endDate,
    };

    final response = await client.post<TimeOffDurationModel>(
      ApiConstants.timeOffDuration,
      body: payload,
      parser: (json) =>
          TimeOffDurationModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw AppException(response.message);
    }
  }

  @override
  Future<void> submitTimeOffRequest({
    required int typeId,
    required String startDate,
    required String endDate,
    String? reason,
  }) async {
    if (AppGlobals.isDesignMode) {
      await Future.delayed(const Duration(seconds: 1));
      return;
    }

    final payload = {
      "time_off_type_id": typeId,
      "start_date": startDate,
      "end_date": endDate,
      if (reason != null && reason.isNotEmpty) "reason": reason,
    };

    final response = await client.post<dynamic>(
      ApiConstants.timeOffRequest,
      body: payload,
      parser: (json) => json,
      isSubmission: true,
    );

    if (!response.success) {
      throw AppException(response.message);
    }
  }

  @override
  Future<CalendarMonthDataModel> getTimeOffCalendarMonth({
    required int year,
    required int month,
  }) async {
    final response = await client.get<CalendarMonthDataModel>(
      ApiConstants.timeOffCalendarMonth,
      queryParameters: {
        'year': year,
        'month': month,
      },
      parser: (json) =>
          CalendarMonthDataModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw AppException(response.message);
    }
  }

  @override
  Future<CalendarDayScheduleModel> getTimeOffCalendarDay({
    required String date,
  }) async {
    final response = await client.get<CalendarDayScheduleModel>(
      ApiConstants.timeOffCalendarDay,
      queryParameters: {
        'date': date,
      },
      parser: (json) =>
          CalendarDayScheduleModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw AppException(response.message);
    }
  }
}
