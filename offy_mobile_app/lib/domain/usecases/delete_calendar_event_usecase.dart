import '../repositories/calendar_repository.dart';

class DeleteCalendarEventUseCase {
  final CalendarRepository repository;

  DeleteCalendarEventUseCase({required this.repository});

  Future<bool> call({required int id}) async {
    return await repository.deleteEvent(id: id);
  }
}
