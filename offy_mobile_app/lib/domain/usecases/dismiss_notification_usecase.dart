import '../repositories/notification_repository.dart';

class DismissNotificationUseCase {
  final NotificationRepository repository;

  DismissNotificationUseCase(this.repository);

  Future<void> call(int id) async {
    return await repository.dismissNotification(id);
  }
}
