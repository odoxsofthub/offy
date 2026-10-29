import 'dart:typed_data';
import '../../data/models/payslip_download_model.dart';
import '../repositories/payslip_repository.dart';

class DownloadPayslipUseCase {
  final PayslipRepository repository;

  DownloadPayslipUseCase({required this.repository});

  Future<PayslipDownloadModel> call(int id) async {
    return await repository.downloadPayslip(id);
  }

  Future<Uint8List> fromUrl(String url, {bool requiresAuth = true}) async {
    return await repository.fetchPayslipPdfFromUrl(
      url,
      requiresAuth: requiresAuth,
    );
  }
}
