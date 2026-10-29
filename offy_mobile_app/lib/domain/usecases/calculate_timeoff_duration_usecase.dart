import '../../data/models/timeoff_response_model.dart';
import '../repositories/timeoff_repository.dart';

class CalculateTimeOffDurationUseCase {
  final TimeOffRepository repository;

  CalculateTimeOffDurationUseCase(this.repository);

  Future<TimeOffDurationModel> call({
    required int typeId,
    required String startDate,
    required String endDate,
  }) async {
    return await repository.calculateTimeOffDuration(
      typeId: typeId,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
