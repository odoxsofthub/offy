import '../repositories/payslip_repository.dart';
import '../../data/models/payslip_response_model.dart';

class GetPayslipHistoryUseCase {
  final PayslipRepository repository;

  GetPayslipHistoryUseCase({required this.repository});

  Future<PayslipHistoryResponseModel> call({
    int page = 1,
    int limit = 10,
    String? search,
    Map<String, dynamic>? filters,
    bool forceRefresh = false,
  }) async {
    return await repository.getPayslipHistory(
      page: page,
      limit: limit,
      search: search,
      filters: filters,
      forceRefresh: forceRefresh,
    );
  }
}
