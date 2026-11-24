import '../../data/models/payslip_response_model.dart';
import '../repositories/payslip_repository.dart';

class GetPayslipUseCase {
  final PayslipRepository repository;

  GetPayslipUseCase({required this.repository});

  Future<PayslipModel> call() async {
    return await repository.getPayslip();
  }
}
