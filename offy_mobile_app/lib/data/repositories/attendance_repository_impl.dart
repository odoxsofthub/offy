import '../models/home_response_model.dart';
import '../models/attendance_log_response_model.dart';
import '../../data/datasources/attendance_remote_data_source.dart';
import '../../domain/repositories/attendance_repository.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final AttendanceRemoteDataSource remoteDataSource;

  AttendanceRepositoryImpl({required this.remoteDataSource});

  @override
  Future<AttendanceStatusModel> performAction({
    required String action,
    double? latitude,
    double? longitude,
  }) {
    return remoteDataSource.performAction(
      action: action,
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  Future<AttendanceLogResponseModel> getAttendanceLogs({
    required int month,
    required int year,
    int page = 1,
    int limit = 10,
  }) {
    return remoteDataSource.getAttendanceLogs(
      month: month,
      year: year,
      page: page,
      limit: limit,
    );
  }
}
