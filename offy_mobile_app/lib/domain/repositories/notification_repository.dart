import '../../data/models/notification_model.dart';

abstract class NotificationRepository {
  Future<NotificationResponseModel> getNotifications({int page = 1, int limit = 20});
  Future<void> dismissNotification(int id);
}
