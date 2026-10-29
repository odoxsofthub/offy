import '../../data/models/home_response_model.dart';
import '../../data/models/attendance_log_response_model.dart';

abstract class AttendanceRepository {
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
