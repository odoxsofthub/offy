import '../models/privacy_policy_model.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';

abstract class PrivacyPolicyRemoteDataSource {
  Future<PrivacyPolicyModel> getPrivacyPolicy();
}

class PrivacyPolicyRemoteDataSourceImpl
    implements PrivacyPolicyRemoteDataSource {
  final ApiClient client;

  PrivacyPolicyRemoteDataSourceImpl({required this.client});

  @override
  Future<PrivacyPolicyModel> getPrivacyPolicy() async {
    final response = await client.get<PrivacyPolicyModel>(
      ApiConstants.privacyPolicy,
      parser: (json) {
        if (json is Map<String, dynamic>) {
          return PrivacyPolicyModel.fromJson(json);
        }
        return const PrivacyPolicyModel(title: 'User policy', body: '');
      },
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw AppException(response.message);
    }
  }
}
