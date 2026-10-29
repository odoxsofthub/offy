import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_globals.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/mock_api_data.dart';
import '../models/expense_response_model.dart';
import '../models/expense_category_model.dart';
import '../models/filter_model.dart';

abstract class ExpenseRemoteDataSource {
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

class ExpenseRemoteDataSourceImpl implements ExpenseRemoteDataSource {
  final ApiClient client;

  ExpenseRemoteDataSourceImpl({required this.client});

  @override
  Future<ExpenseSummaryModel> getExpenseSummary() async {
    if (AppGlobals.isDesignMode) {
      await Future.delayed(const Duration(seconds: 1));
      return ExpenseSummaryModel.fromJson(
        MockApiData.getMockResponse('GET', ApiConstants.expenseSummary)['data']
            as Map<String, dynamic>,
      );
    }

    final response = await client.get<ExpenseSummaryModel>(
      ApiConstants.expenseSummary,
      parser: (json) =>
          ExpenseSummaryModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw AppException(response.message);
    }
  }

  final Map<String, Future<ExpenseListResponseModel>>
  _inFlightExpensesListRequests = {};
  final Map<String, Future<FilterContentResponseModel>>
  _inFlightFilterContentRequests = {};

  @override
  Future<ExpenseListResponseModel> getExpensesList({
    int page = 1,
    int limit = 20,
    String? search,
    Map<String, dynamic>? filters,
    bool forceRefresh = false,
  }) async {
    if (AppGlobals.isDesignMode) {
      await Future.delayed(const Duration(seconds: 1));
      return ExpenseListResponseModel.fromJson(
        MockApiData.getMockResponse('GET', ApiConstants.expensesList)['data']
            as Map<String, dynamic>,
      );
    }

    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (filters != null && filters.isNotEmpty) {
      filters.forEach((key, value) {
        if (value != null) {
          queryParams[key] = value.toString();
        }
      });
    }

    final queryString = queryParams.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
    final url = '${ApiConstants.expensesList}?$queryString';

    if (!forceRefresh && _inFlightExpensesListRequests.containsKey(url)) {
      return _inFlightExpensesListRequests[url]!;
    }

    final future = _fetchExpensesList(url);
    _inFlightExpensesListRequests[url] = future;
    try {
      return await future;
    } finally {
      _inFlightExpensesListRequests.remove(url);
    }
  }

  Future<ExpenseListResponseModel> _fetchExpensesList(String url) async {
    final response = await client.get<ExpenseListResponseModel>(
      url,
      parser: (json) {
        if (json is Map<String, dynamic>) {
          return ExpenseListResponseModel.fromJson(json);
        } else if (json is List) {
          return ExpenseListResponseModel.fromList(json);
        }
        return ExpenseListResponseModel(
          pagination: PaginationModel(
            page: 1,
            limit: 20,
            total: 0,
            hasNext: false,
            hasPrevious: false,
          ),
        );
      },
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw AppException(response.message);
    }
  }

  @override
  Future<List<ExpenseCategoryModel>> getExpenseCategories() async {
    if (AppGlobals.isDesignMode) {
      await Future.delayed(const Duration(seconds: 1));
      final json = MockApiData.getMockResponse(
        'GET',
        ApiConstants.expenseCategories,
      )['data'];
      if (json is List) {
        return json
            .map(
              (e) => ExpenseCategoryModel.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
      return [];
    }

    final response = await client.get<List<ExpenseCategoryModel>>(
      ApiConstants.expenseCategories,
      parser: (json) {
        if (json is List) {
          return json
              .map(
                (e) => ExpenseCategoryModel.fromJson(e as Map<String, dynamic>),
              )
              .toList();
        }
        return [];
      },
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw AppException(response.message);
    }
  }

  @override
  Future<bool> submitExpense(
    Map<String, String> data,
    List<XFile> files,
  ) async {
    if (AppGlobals.isDesignMode) {
      await Future.delayed(const Duration(seconds: 1));
      return true; // Mock success
    }

    List<http.MultipartFile> multipartFiles = [];
    for (var file in files) {
      final bytes = await file.readAsBytes();
      multipartFiles.add(
        http.MultipartFile.fromBytes('files', bytes, filename: file.name),
      );
    }

    final isUpdate =
        data.containsKey('id') && (int.tryParse(data['id']!) ?? 0) > 0;

    final response = isUpdate
        ? await client.patchMultipart<bool>(
            ApiConstants.submitExpense,
            fields: data,
            files: multipartFiles,
            parser: (json) => true,
            isSubmission: true,
          )
        : await client.postMultipart<bool>(
            ApiConstants.submitExpense,
            fields: data,
            files: multipartFiles,
            parser: (json) => true,
            isSubmission: true,
          );

    if (response.success) {
      return true;
    } else {
      throw AppException(response.message);
    }
  }

  @override
  Future<bool> deleteExpense(int id) async {
    if (AppGlobals.isDesignMode) {
      await Future.delayed(const Duration(seconds: 1));
      return true; // Mock success
    }

    try {
      final response = await client.delete<bool>(
        '/api/mobile/v1/expenses/$id',
        parser: (json) => true,
      );

      if (response.success) {
        return true;
      } else {
        throw AppException(response.message);
      }
    } on AppException catch (e) {
      if (e.statusCode == 404 || (e.message != null && e.message!.toLowerCase().contains('not found'))) {
        return true;
      }
      rethrow;
    }
  }

  @override
  Future<FilterOptionsResponseModel> getFilterOptions({
    required FilterSource source,
    String? view,
  }) async {
    final queryParams = <String, dynamic>{'source': source.value};
    if (view != null && view.isNotEmpty) {
      queryParams['view'] = view;
    }
    final response = await client.get<FilterOptionsResponseModel>(
      ApiConstants.filterOptions,
      queryParameters: queryParams,
      parser: (json) => FilterOptionsResponseModel.fromJson(
        json is Map<String, dynamic> ? json : <String, dynamic>{},
      ),
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw AppException(response.message);
    }
  }

  @override
  Future<FilterContentResponseModel> getFilterContent({
    required FilterSource source,
    required FilterOption option,
    String? bucket,
    String? view,
  }) async {
    final queryParams = <String, dynamic>{'source': source.value};
    if (view != null && view.isNotEmpty) {
      queryParams['view'] = view;
    }
    queryParams['option'] = option.value;
    if (bucket != null && bucket.isNotEmpty) {
      queryParams['bucket'] = bucket.toLowerCase();
    }

    final reqKey =
        '${source.value}:${view ?? ''}:${option.value}:${bucket?.toLowerCase() ?? ''}';
    if (_inFlightFilterContentRequests.containsKey(reqKey)) {
      return _inFlightFilterContentRequests[reqKey]!;
    }

    final future = _fetchFilterContent(queryParams);
    _inFlightFilterContentRequests[reqKey] = future;
    return future.whenComplete(() {
      _inFlightFilterContentRequests.remove(reqKey);
    });
  }

  Future<FilterContentResponseModel> _fetchFilterContent(
    Map<String, dynamic> queryParams,
  ) async {
    final response = await client.get<FilterContentResponseModel>(
      ApiConstants.filters,
      queryParameters: queryParams,
      parser: (json) => FilterContentResponseModel.fromJson(
        json is Map<String, dynamic> ? json : <String, dynamic>{},
      ),
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw AppException(response.message);
    }
  }

  @override
  Future<FilterApplyResponseModel> applyFilter({
    required FilterSource source,
    required FilterOption option,
    required Map<String, dynamic> data,
    String? view,
  }) async {
    final queryMap = <String, String>{'source': source.value};
    if (view != null && view.isNotEmpty) {
      queryMap['view'] = view;
    }
    queryMap['option'] = option.value;

    final queryString = queryMap.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
    final url = '${ApiConstants.applyFilters}?$queryString';

    final payload = Map<String, dynamic>.from(data);
    if (!payload.containsKey('option')) {
      payload['option'] = option.value;
    }

    final response = await client.post<FilterApplyResponseModel>(
      url,
      body: payload,
      parser: (json) => FilterApplyResponseModel.fromJson(
        json is Map<String, dynamic> ? json : <String, dynamic>{},
      ),
    );

    _inFlightExpensesListRequests.clear();
    _inFlightFilterContentRequests.clear();

    if (response.success) {
      return response.data ??
          FilterApplyResponseModel(
            success: true,
            message: response.message,
            data: FilterApplyDataModel(
              source: source.value,
              option: option.value,
              cleared: false,
            ),
          );
    } else {
      throw AppException(response.message);
    }
  }
}
