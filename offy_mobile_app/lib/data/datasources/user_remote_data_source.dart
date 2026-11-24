import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../models/access_details_response_model.dart';
import '../models/mention_suggestion_model.dart';

abstract class UserRemoteDataSource {
  Future<AccessDetailsResponseModel> getAccessDetails({
    bool retryOnNetworkError = true,
  });

  Future<List<MentionSuggestionModel>> getMentionSuggestions({
    String search = '',
    int limit = 20,
  });
}

class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  final ApiClient apiClient;

  UserRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<AccessDetailsResponseModel> getAccessDetails({
    bool retryOnNetworkError = true,
  }) async {
    final response = await apiClient.get<AccessDetailsResponseModel>(
      ApiConstants.accessDetails,
      retryOnNetworkError: retryOnNetworkError,
      parser: (json) {
        final map = json as Map<String, dynamic>;
        return AccessDetailsResponseModel.fromJson(map);
      },
    );

    if (response.data != null) {
      return response.data!;
    } else {
      throw const AppException('User access details response was empty');
    }
  }

  @override
  Future<List<MentionSuggestionModel>> getMentionSuggestions({
    String search = '',
    int limit = 20,
  }) async {
    final response = await apiClient.get<List<MentionSuggestionModel>>(
      ApiConstants.mentionSuggestions,
      queryParameters: {
        'search': search,
        'limit': limit,
      },
      parser: (json) {
        List<dynamic> items = [];
        if (json is List) {
          items = json;
        } else if (json is Map<String, dynamic>) {
          if (json['suggestions'] is List) {
            items = json['suggestions'] as List<dynamic>;
          } else if (json['data'] is Map<String, dynamic> &&
              json['data']['suggestions'] is List) {
            items = json['data']['suggestions'] as List<dynamic>;
          } else if (json['data'] is List) {
            items = json['data'] as List<dynamic>;
          } else if (json['users'] is List) {
            items = json['users'] as List<dynamic>;
          } else if (json['members'] is List) {
            items = json['members'] as List<dynamic>;
          }
        }
        return items
            .map(
              (e) => MentionSuggestionModel.fromJson(
                e is Map<String, dynamic> ? e : {},
              ),
            )
            .toList();
      },
    );

    return response.data ?? [];
  }
}
