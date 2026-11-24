import '../repositories/timeoff_repository.dart';
import '../../data/models/timeoff_response_model.dart';

class GetTimeOffDataUseCase {
  final TimeOffRepository repository;

  GetTimeOffDataUseCase({required this.repository});

  Future<TimeOffResponseModel> call() async {
    return await repository.getTimeOffData();
  }
}
