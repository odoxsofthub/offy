import '../../data/models/home_response_model.dart';

abstract class HomeRepository {
  Future<HomeDataModel> getHomeData({bool retryOnNetworkError = true});
}
