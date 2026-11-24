import '../../domain/repositories/home_repository.dart';
import '../datasources/home_remote_data_source.dart';
import '../models/home_response_model.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDataSource remoteDataSource;

  HomeRepositoryImpl({required this.remoteDataSource});

  @override
  Future<HomeDataModel> getHomeData({bool retryOnNetworkError = true}) {
    return remoteDataSource.getHomeData(
      retryOnNetworkError: retryOnNetworkError,
    );
  }
}
