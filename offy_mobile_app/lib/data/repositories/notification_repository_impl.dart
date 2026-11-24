import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_remote_data_source.dart';
import '../models/notification_model.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource remoteDataSource;

  NotificationRepositoryImpl({required this.remoteDataSource});

  @override
  Future<NotificationResponseModel> getNotifications({int page = 1, int limit = 20}) {
    return remoteDataSource.getNotifications(page: page, limit: limit);
  }

  @override
  Future<void> dismissNotification(int id) {
    return remoteDataSource.dismissNotification(id);
  }
}
