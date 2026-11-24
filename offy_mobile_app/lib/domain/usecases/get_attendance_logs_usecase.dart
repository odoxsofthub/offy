import '../repositories/attendance_repository.dart';
import '../../data/models/attendance_log_response_model.dart';

class GetAttendanceLogsUseCase {
  final AttendanceRepository repository;

  GetAttendanceLogsUseCase({required this.repository});

  Future<AttendanceLogResponseModel> call({
    required int month,
    required int year,
    int page = 1,
    int limit = 10,
  }) async {
    return await repository.getAttendanceLogs(
      month: month,
      year: year,
      page: page,
      limit: limit,
    );
  }
}
