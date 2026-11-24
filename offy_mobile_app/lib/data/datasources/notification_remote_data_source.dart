import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../models/notification_model.dart';

abstract class NotificationRemoteDataSource {
  Future<NotificationResponseModel> getNotifications({int page = 1, int limit = 20});
  Future<void> dismissNotification(int id);
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final ApiClient apiClient;

  NotificationRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<NotificationResponseModel> getNotifications({int page = 1, int limit = 20}) async {
    final response = await apiClient.get<NotificationResponseModel>(
      '${ApiConstants.notifications}?page=$page&limit=$limit',
      parser: (json) => NotificationResponseModel.fromJson(json as Map<String, dynamic>),
    );
    if (response.data != null) {
      return response.data!;
    } else {
      throw const AppException('Notification data response was empty');
    }
  }

  @override
  Future<void> dismissNotification(int id) async {
    await apiClient.delete<void>(
      '${ApiConstants.notifications}/$id',
      parser: (_) {},
    );
  }
}
