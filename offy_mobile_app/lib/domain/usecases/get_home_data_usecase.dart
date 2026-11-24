import '../../data/models/home_response_model.dart';
import '../repositories/home_repository.dart';

class GetHomeDataUseCase {
  final HomeRepository repository;

  GetHomeDataUseCase({required this.repository});

  Future<HomeDataModel> call({bool retryOnNetworkError = true}) async {
    return await repository.getHomeData(
      retryOnNetworkError: retryOnNetworkError,
    );
  }
}
