import '../../data/models/filter_model.dart';
import '../repositories/expense_repository.dart';

class GetExpenseFilterOptionsUseCase {
  final ExpenseRepository repository;

  GetExpenseFilterOptionsUseCase(this.repository);

  Future<FilterOptionsResponseModel> call({
    required FilterSource source,
    String? view,
  }) async {
    return await repository.getFilterOptions(
      source: source,
      view: view,
    );
  }
}
