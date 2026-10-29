import '../repositories/expense_repository.dart';

class DeleteExpenseUseCase {
  final ExpenseRepository repository;

  DeleteExpenseUseCase(this.repository);

  Future<bool> call(int params) async {
    return await repository.deleteExpense(params);
  }
}
