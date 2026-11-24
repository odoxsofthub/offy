import '../../data/models/login_response_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({required this.remoteDataSource});

  final AuthRemoteDataSource remoteDataSource;

  @override
  Future<bool> login({required String email, required String password}) {
    return remoteDataSource.login(email, password);
  }

  @override
  Future<bool> refreshToken() {
    return remoteDataSource.refreshToken();
  }

  @override
  Future<LoginResponseModel> switchCompany(int companyId) {
    return remoteDataSource.switchCompany(companyId);
  }

  @override
  Future<void> registerDeviceToken({required String token, required String deviceType}) {
    return remoteDataSource.registerDeviceToken(token, deviceType);
  }

  @override
  Future<void> logout() {
    return remoteDataSource.logout();
  }
}
