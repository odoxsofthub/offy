import '../models/faq_response_model.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';

abstract class FaqRemoteDataSource {
  Future<FaqResponseModel> getFaqs();
}

class FaqRemoteDataSourceImpl implements FaqRemoteDataSource {
  final ApiClient client;

  FaqRemoteDataSourceImpl({required this.client});

  @override
  Future<FaqResponseModel> getFaqs() async {
    final response = await client.get<FaqResponseModel>(
      ApiConstants.faqs,
      parser: (json) {
        if (json is Map<String, dynamic>) {
          return FaqResponseModel.fromJson(json);
        }
        return const FaqResponseModel(faqs: []);
      },
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw AppException(response.message);
    }
  }
}
