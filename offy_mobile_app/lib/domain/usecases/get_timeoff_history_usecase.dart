import '../../data/models/timeoff_response_model.dart';
import '../repositories/timeoff_repository.dart';

class GetTimeOffHistoryUseCase {
  final TimeOffRepository repository;

  GetTimeOffHistoryUseCase({required this.repository});

  Future<TimeOffHistoryResponseModel> call({
    int page = 1,
    int limit = 10,
    String? search,
    Map<String, dynamic>? filters,
    bool forceRefresh = false,
  }) async {
    return await repository.getTimeOffHistory(
      page: page,
      limit: limit,
      search: search,
      filters: filters,
      forceRefresh: forceRefresh,
    );
  }
}
