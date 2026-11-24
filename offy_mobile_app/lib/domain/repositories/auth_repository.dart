import '../../data/models/login_response_model.dart';

abstract class AuthRepository {
  Future<bool> login({required String email, required String password});
  Future<bool> refreshToken();
  Future<LoginResponseModel> switchCompany(int companyId);
  Future<void> registerDeviceToken({required String token, required String deviceType});
  Future<void> logout();
}
