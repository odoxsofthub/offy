import 'dart:typed_data';

import 'package:office_app/data/models/payslip_response_model.dart';
import 'package:office_app/data/models/payslip_download_model.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';

abstract class PayslipRemoteDataSource {
  Future<PayslipModel> getPayslip();
  Future<PayslipDownloadModel> downloadPayslip(int id);
  Future<Uint8List> fetchPayslipPdfFromUrl(
    String url, {
    bool requiresAuth = true,
  });
  Future<PayslipHistoryResponseModel> getPayslipHistory({
    int page = 1,
    int limit = 10,
    String? search,
    Map<String, dynamic>? filters,
    bool forceRefresh = false,
  });
}

class PayslipRemoteDataSourceImpl implements PayslipRemoteDataSource {
  final ApiClient apiClient;
  final Map<String, Future<PayslipHistoryResponseModel>>
      _inFlightHistoryRequests = {};

  PayslipRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<PayslipModel> getPayslip() async {
    final response = await apiClient.get<PayslipModel>(
      ApiConstants.payslip,
      parser: (json) {
        final map = json as Map<String, dynamic>;
        return PayslipModel.fromJson(map);
      },
    );

    if (response.data != null) {
      return response.data!;
    } else {
      throw const AppException('Payslip data response was empty');
    }
  }

  @override
  Future<PayslipDownloadModel> downloadPayslip(int id) async {
    final response = await apiClient.get<PayslipDownloadModel>(
      ApiConstants.payslipDownload(id),
      parser: (json) {
        final map = json as Map<String, dynamic>;
        return PayslipDownloadModel.fromJson(map);
      },
    );

    if (response.data != null) {
      return response.data!;
    } else {
      throw const AppException('Payslip download data response was empty');
    }
  }

  @override
  Future<Uint8List> fetchPayslipPdfFromUrl(
    String url, {
    bool requiresAuth = true,
  }) async {
    return await apiClient.getBytes(url, requiresAuth: requiresAuth);
  }

  @override
  Future<PayslipHistoryResponseModel> getPayslipHistory({
    int page = 1,
    int limit = 10,
    String? search,
    Map<String, dynamic>? filters,
    bool forceRefresh = false,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': limit.toString(),
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
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final url = '${ApiConstants.payslipList}?$queryString';

    if (!forceRefresh && _inFlightHistoryRequests.containsKey(url)) {
      return _inFlightHistoryRequests[url]!;
    }

    final future = _fetchPayslipHistory(url);
    _inFlightHistoryRequests[url] = future;
    try {
      return await future;
    } finally {
      _inFlightHistoryRequests.remove(url);
    }
  }

  Future<PayslipHistoryResponseModel> _fetchPayslipHistory(String url) async {
    final response = await apiClient.get<PayslipHistoryResponseModel>(
      url,
      parser: (json) {
        if (json is Map<String, dynamic>) {
          return PayslipHistoryResponseModel.fromJson(json);
        } else if (json is List) {
          return PayslipHistoryResponseModel.fromList(json);
        }
        return PayslipHistoryResponseModel(
          success: true,
          message: 'Success',
          payslips: const [],
          pagination: PayslipPaginationModel(
            page: 1,
            pageSize: 10,
            total: 0,
            totalPages: 1,
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
}
