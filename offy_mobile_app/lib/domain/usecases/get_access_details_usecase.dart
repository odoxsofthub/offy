import '../../data/models/access_details_response_model.dart';
import '../repositories/user_repository.dart';

class GetAccessDetailsUseCase {
  final UserRepository repository;

  GetAccessDetailsUseCase({required this.repository});

  Future<AccessDetailsResponseModel> call({
    bool retryOnNetworkError = true,
  }) async {
    return await repository.getAccessDetails(
      retryOnNetworkError: retryOnNetworkError,
    );
  }
}
