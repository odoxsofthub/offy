import '../../data/models/timeoff_response_model.dart';
import '../repositories/timeoff_repository.dart';

class GetUpcomingLeavesUseCase {
  final TimeOffRepository repository;

  GetUpcomingLeavesUseCase(this.repository);

  Future<TimeOffHistoryResponseModel> call({
    int page = 1,
    int limit = 10,
    String? search,
    Map<String, dynamic>? filters,
    bool forceRefresh = false,
  }) async {
    return await repository.getUpcomingLeaves(
      page: page,
      limit: limit,
      search: search,
      filters: filters,
      forceRefresh: forceRefresh,
    );
  }
}
