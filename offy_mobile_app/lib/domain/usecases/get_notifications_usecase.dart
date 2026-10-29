import '../../data/models/notification_model.dart';
import '../repositories/notification_repository.dart';

class GetNotificationsUseCase {
  final NotificationRepository repository;

  GetNotificationsUseCase(this.repository);

  Future<NotificationResponseModel> call({int page = 1, int limit = 20}) async {
    return await repository.getNotifications(page: page, limit: limit);
  }
}
