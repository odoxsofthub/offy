import '../../data/models/expense_response_model.dart';
import '../repositories/expense_repository.dart';

class GetExpensesListUseCase {
  final ExpenseRepository repository;

  GetExpensesListUseCase(this.repository);

  Future<ExpenseListResponseModel> call({
    int page = 1,
    int limit = 20,
    String? search,
    Map<String, dynamic>? filters,
    bool forceRefresh = false,
  }) async {
    return await repository.getExpensesList(
      page: page,
      limit: limit,
      search: search,
      filters: filters,
      forceRefresh: forceRefresh,
    );
  }
}
