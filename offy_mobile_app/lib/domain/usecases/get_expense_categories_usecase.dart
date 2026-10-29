import '../../data/models/expense_category_model.dart';
import '../repositories/expense_repository.dart';

class GetExpenseCategoriesUseCase {
  final ExpenseRepository repository;

  GetExpenseCategoriesUseCase(this.repository);

  Future<List<ExpenseCategoryModel>> call() async {
    return await repository.getExpenseCategories();
  }
}
