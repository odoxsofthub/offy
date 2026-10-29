import '../../data/models/filter_model.dart';
import '../repositories/expense_repository.dart';

class ApplyExpenseFilterUseCase {
  final ExpenseRepository repository;

  ApplyExpenseFilterUseCase(this.repository);

  Future<FilterApplyResponseModel> call({
    required FilterSource source,
    required FilterOption option,
    required Map<String, dynamic> data,
    String? view,
  }) async {
    return await repository.applyFilter(
      source: source,
      option: option,
      data: data,
      view: view,
    );
  }
}
