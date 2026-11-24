import '../../data/models/expense_response_model.dart';
import '../repositories/expense_repository.dart';

class GetExpenseSummaryUseCase {
  final ExpenseRepository repository;

  GetExpenseSummaryUseCase(this.repository);

  Future<ExpenseSummaryModel> call() async {
    return await repository.getExpenseSummary();
  }
}
