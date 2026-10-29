import '../repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase({required this.repository});

  final AuthRepository repository;

  Future<bool> call({required String email, required String password}) async {
    return await repository.login(email: email, password: password);
  }
}
