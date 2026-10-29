import '../../data/models/timeoff_response_model.dart';
import '../repositories/timeoff_repository.dart';

class GetTimeOffTypesUseCase {
  final TimeOffRepository repository;

  GetTimeOffTypesUseCase({required this.repository});

  Future<List<TimeOffTypeModel>> call() async {
    return await repository.getTimeOffTypes();
  }
}
