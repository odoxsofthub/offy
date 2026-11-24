import 'package:image_picker/image_picker.dart';
import '../../domain/repositories/expense_repository.dart';
import '../datasources/expense_remote_data_source.dart';
import '../models/expense_response_model.dart';
import '../models/expense_category_model.dart';
import '../models/filter_model.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  final ExpenseRemoteDataSource remoteDataSource;

  ExpenseRepositoryImpl({required this.remoteDataSource});

  @override
  Future<ExpenseSummaryModel> getExpenseSummary() async {
    return await remoteDataSource.getExpenseSummary();
  }

  @override
  Future<ExpenseListResponseModel> getExpensesList({
    int page = 1,
    int limit = 20,
    String? search,
    Map<String, dynamic>? filters,
    bool forceRefresh = false,
  }) async {
    return await remoteDataSource.getExpensesList(
      page: page,
      limit: limit,
      search: search,
      filters: filters,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<List<ExpenseCategoryModel>> getExpenseCategories() async {
    return await remoteDataSource.getExpenseCategories();
  }

  @override
  Future<bool> submitExpense(
    Map<String, String> data,
    List<XFile> files,
  ) async {
    return await remoteDataSource.submitExpense(data, files);
  }

  @override
  Future<bool> deleteExpense(int id) async {
    return await remoteDataSource.deleteExpense(id);
  }

  @override
  Future<FilterOptionsResponseModel> getFilterOptions({
    required FilterSource source,
    String? view,
  }) async {
    return await remoteDataSource.getFilterOptions(
      source: source,
      view: view,
    );
  }

  @override
  Future<FilterContentResponseModel> getFilterContent({
    required FilterSource source,
    required FilterOption option,
    String? bucket,
    String? view,
  }) async {
    return await remoteDataSource.getFilterContent(
      source: source,
      option: option,
      bucket: bucket,
      view: view,
    );
  }

  @override
  Future<FilterApplyResponseModel> applyFilter({
    required FilterSource source,
    required FilterOption option,
    required Map<String, dynamic> data,
    String? view,
  }) async {
    return await remoteDataSource.applyFilter(
      source: source,
      option: option,
      data: data,
      view: view,
    );
  }
}
