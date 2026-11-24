import 'package:image_picker/image_picker.dart';
import '../../data/models/expense_response_model.dart';
import '../../data/models/expense_category_model.dart';
import '../../data/models/filter_model.dart';

abstract class ExpenseRepository {
  Future<ExpenseSummaryModel> getExpenseSummary();
  Future<ExpenseListResponseModel> getExpensesList({
    int page = 1,
    int limit = 20,
    String? search,
    Map<String, dynamic>? filters,
    bool forceRefresh = false,
  });
  Future<List<ExpenseCategoryModel>> getExpenseCategories();
  Future<bool> submitExpense(Map<String, String> data, List<XFile> files);
  Future<bool> deleteExpense(int id);
  Future<FilterOptionsResponseModel> getFilterOptions({
    required FilterSource source,
    String? view,
  });
  Future<FilterContentResponseModel> getFilterContent({
    required FilterSource source,
    required FilterOption option,
    String? bucket,
    String? view,
  });
  Future<FilterApplyResponseModel> applyFilter({
    required FilterSource source,
    required FilterOption option,
    required Map<String, dynamic> data,
    String? view,
  });
}
