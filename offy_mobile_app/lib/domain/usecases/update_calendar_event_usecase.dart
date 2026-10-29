import '../repositories/calendar_repository.dart';

class UpdateCalendarEventUseCase {
  final CalendarRepository repository;

  UpdateCalendarEventUseCase({required this.repository});

  Future<bool> call({
    required int id,
    required String title,
    required bool allDay,
    required String startDate,
    required String endDate,
    String? startTime,
    String? endTime,
    String? notes,
  }) async {
    return await repository.updateEvent(
      id: id,
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
