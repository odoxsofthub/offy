import '../../core/services/token_storage.dart';
import '../../data/models/login_response_model.dart';
import '../repositories/auth_repository.dart';

class SwitchCompanyUseCase {
  const SwitchCompanyUseCase({
    required this.repository,
    required this.tokenStorage,
  });

  final AuthRepository repository;
  final TokenStorage tokenStorage;

  Future<LoginResponseModel> call(int companyId) async {
    final response = await repository.switchCompany(companyId);
    // Atomically replace tokens and selected company ID in storage before any subsequent network calls
    if (response.refreshToken != null && response.refreshToken!.isNotEmpty) {
      await tokenStorage.saveRefreshToken(response.refreshToken!);
    }
    await tokenStorage.saveBearerToken(response.token);
    if (response.companySessionId != null &&
        response.companySessionId!.isNotEmpty) {
      await tokenStorage.saveSessionId(response.companySessionId!);
    }
    final activeCompanyId = response.primarySelectedCompanyId ?? companyId;
    await tokenStorage.saveSelectedCompanyId(activeCompanyId);
    return response;
  }
}
