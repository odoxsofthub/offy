import 'dart:typed_data';

import '../datasources/payslip_remote_data_source.dart';
import '../models/payslip_response_model.dart';
import '../models/payslip_download_model.dart';
import '../../domain/repositories/payslip_repository.dart';

class PayslipRepositoryImpl implements PayslipRepository {
  final PayslipRemoteDataSource remoteDataSource;

  PayslipRepositoryImpl({required this.remoteDataSource});

  @override
  Future<PayslipModel> getPayslip() {
    return remoteDataSource.getPayslip();
  }

  @override
  Future<PayslipDownloadModel> downloadPayslip(int id) {
    return remoteDataSource.downloadPayslip(id);
  }

  @override
  Future<Uint8List> fetchPayslipPdfFromUrl(
    String url, {
    bool requiresAuth = true,
  }) {
    return remoteDataSource.fetchPayslipPdfFromUrl(
      url,
      requiresAuth: requiresAuth,
    );
  }

  @override
  Future<PayslipHistoryResponseModel> getPayslipHistory({
    int page = 1,
    int limit = 10,
    String? search,
    Map<String, dynamic>? filters,
    bool forceRefresh = false,
  }) {
    return remoteDataSource.getPayslipHistory(
      page: page,
      limit: limit,
      search: search,
      filters: filters,
      forceRefresh: forceRefresh,
    );
  }
}
