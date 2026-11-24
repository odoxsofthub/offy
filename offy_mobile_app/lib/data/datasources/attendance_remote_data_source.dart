import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../models/home_response_model.dart';
import '../models/attendance_log_response_model.dart';

abstract class AttendanceRemoteDataSource {
  Future<AttendanceStatusModel> performAction({
    required String action,
    double? latitude,
    double? longitude,
  });

  Future<AttendanceLogResponseModel> getAttendanceLogs({
    required int month,
    required int year,
    int page = 1,
    int limit = 10,
  });
}

class AttendanceRemoteDataSourceImpl implements AttendanceRemoteDataSource {
  final ApiClient apiClient;

  AttendanceRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<AttendanceStatusModel> performAction({
    required String action,
    double? latitude,
    double? longitude,
  }) async {
    final body = <String, dynamic>{
      'action': action,
    };
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;

    final response = await apiClient.post<AttendanceStatusModel>(
      ApiConstants.attendanceAction,
      body: body,
      isSubmission: true,
      parser: (json) {
        if (json is! Map<String, dynamic>) {
          throw const AppException('Invalid attendance action response format');
        }
        final attendanceMap = json['attendance'] is Map<String, dynamic>
            ? json['attendance'] as Map<String, dynamic>
            : json;
        return AttendanceStatusModel.fromJson(attendanceMap);
      },
    );

    if (response.data != null) {
      return response.data!;
    } else {
      throw const AppException('Attendance data response was empty');
    }
  }

  @override
  Future<AttendanceLogResponseModel> getAttendanceLogs({
    required int month,
    required int year,
    int page = 1,
    int limit = 10,
  }) async {
    final response = await apiClient.get<AttendanceLogResponseModel>(
      '${ApiConstants.attendanceLogs}?month=$month&year=$year&page=$page&limit=$limit',
      parser: (json) => AttendanceLogResponseModel.fromJson(json as Map<String, dynamic>),
    );
    if (response.data != null) {
      return response.data!;
    } else {
      throw const AppException('Attendance data response was empty');
    }
  }
}
