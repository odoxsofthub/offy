import '../repositories/calendar_repository.dart';

class CreateCalendarEventUseCase {
  final CalendarRepository repository;

  CreateCalendarEventUseCase({required this.repository});

  Future<bool> call({
    required String title,
    required bool allDay,
    required String startDate,
    required String endDate,
    String? startTime,
    String? endTime,
    String? notes,
  }) async {
    return await repository.createEvent(
      title: title,
      allDay: allDay,
      startDate: startDate,
      endDate: endDate,
      startTime: startTime,
      endTime: endTime,
      notes: notes,
    );
  }
}
