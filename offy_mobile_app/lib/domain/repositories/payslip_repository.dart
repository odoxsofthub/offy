import 'dart:typed_data';

import '../../data/models/payslip_response_model.dart';
import '../../data/models/payslip_download_model.dart';

abstract class PayslipRepository {
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
