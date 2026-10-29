import '../repositories/auth_repository.dart';

class RegisterDeviceTokenUseCase {
  final AuthRepository repository;

  RegisterDeviceTokenUseCase({required this.repository});

  Future<void> call({required String token, required String deviceType}) {
    return repository.registerDeviceToken(token: token, deviceType: deviceType);
  }
}
