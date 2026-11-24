import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../models/home_response_model.dart';

abstract class HomeRemoteDataSource {
  Future<HomeDataModel> getHomeData({bool retryOnNetworkError = true});
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final ApiClient apiClient;

  HomeRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<HomeDataModel> getHomeData({bool retryOnNetworkError = true}) async {
    final response = await apiClient.get<HomeDataModel>(
      ApiConstants.home,
      retryOnNetworkError: retryOnNetworkError,
      parser: (json) => HomeDataModel.fromJson(json as Map<String, dynamic>),
    );
    if (response.data != null) {
      return response.data!;
    } else {
      throw const AppException('Home data response was empty');
    }
  }
}
