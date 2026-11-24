import '../../data/models/home_response_model.dart';
import '../repositories/attendance_repository.dart';

class PerformAttendanceActionUseCase {
  final AttendanceRepository repository;

  PerformAttendanceActionUseCase({required this.repository});

  Future<AttendanceStatusModel> call({
    required String action,
    double? latitude,
    double? longitude,
  }) async {
    return await repository.performAction(
      action: action,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
