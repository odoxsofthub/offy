import '../models/terms_conditions_model.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';

abstract class TermsConditionsRemoteDataSource {
  Future<TermsConditionsModel> getTermsConditions();
}

class TermsConditionsRemoteDataSourceImpl
    implements TermsConditionsRemoteDataSource {
  final ApiClient client;

  TermsConditionsRemoteDataSourceImpl({required this.client});

  @override
  Future<TermsConditionsModel> getTermsConditions() async {
    final response = await client.get<TermsConditionsModel>(
      ApiConstants.termsConditions,
      parser: (json) {
        if (json is Map<String, dynamic>) {
          return TermsConditionsModel.fromJson(json);
        }
        return const TermsConditionsModel(title: 'Terms of service', body: '');
      },
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw AppException(response.message);
    }
  }
}
