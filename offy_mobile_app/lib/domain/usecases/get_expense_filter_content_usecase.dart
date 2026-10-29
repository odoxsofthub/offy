import '../../data/models/filter_model.dart';
import '../repositories/expense_repository.dart';

class GetExpenseFilterContentUseCase {
  final ExpenseRepository repository;

  GetExpenseFilterContentUseCase(this.repository);

  Future<FilterContentResponseModel> call({
    required FilterSource source,
    required FilterOption option,
    String? bucket,
    String? view,
  }) async {
    return await repository.getFilterContent(
      source: source,
      option: option,
      bucket: bucket,
      view: view,
    );
  }
}
