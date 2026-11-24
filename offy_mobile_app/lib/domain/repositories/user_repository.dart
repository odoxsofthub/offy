import '../../data/models/access_details_response_model.dart';
import '../../data/models/mention_suggestion_model.dart';

abstract class UserRepository {
  Future<AccessDetailsResponseModel> getAccessDetails({
    bool retryOnNetworkError = true,
  });

  AccessDetailsResponseModel? getCachedAccessDetails();

  Future<void> cacheAccessDetails(AccessDetailsResponseModel details);

  Future<void> clearAccessDetailsCache();

  Future<List<MentionSuggestionModel>> getMentionSuggestions({
    String search = '',
    int limit = 20,
  });
}
