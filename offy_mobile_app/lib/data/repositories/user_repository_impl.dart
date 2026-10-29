import '../datasources/user_local_data_source.dart';
import '../datasources/user_remote_data_source.dart';
import '../models/access_details_response_model.dart';
import '../models/mention_suggestion_model.dart';
import '../../domain/repositories/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource remoteDataSource;
  final UserLocalDataSource localDataSource;

  UserRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<AccessDetailsResponseModel> getAccessDetails({
    bool retryOnNetworkError = true,
  }) async {
    final details = await remoteDataSource.getAccessDetails(
      retryOnNetworkError: retryOnNetworkError,
    );
    await localDataSource.cacheAccessDetails(details);
    return details;
  }

  @override
  AccessDetailsResponseModel? getCachedAccessDetails() {
    return localDataSource.getCachedAccessDetails();
  }

  @override
  Future<void> cacheAccessDetails(AccessDetailsResponseModel details) {
    return localDataSource.cacheAccessDetails(details);
  }

  @override
  Future<void> clearAccessDetailsCache() {
    return localDataSource.clearCache();
  }

  @override
  Future<List<MentionSuggestionModel>> getMentionSuggestions({
    String search = '',
    int limit = 20,
  }) {
    return remoteDataSource.getMentionSuggestions(search: search, limit: limit);
  }
}
