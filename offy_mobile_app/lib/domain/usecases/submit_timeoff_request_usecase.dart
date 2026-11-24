import '../repositories/timeoff_repository.dart';

class SubmitTimeOffRequestUseCase {
  final TimeOffRepository repository;

  SubmitTimeOffRequestUseCase(this.repository);

  Future<void> call({
    required int typeId,
    required String startDate,
    required String endDate,
    String? reason,
  }) async {
    return await repository.submitTimeOffRequest(
      typeId: typeId,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
    );
  }
}
