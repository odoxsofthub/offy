import '../../data/models/calendar_day_schedule_model.dart';
import '../repositories/calendar_repository.dart';

class GetCalendarDayUseCase {
  final CalendarRepository repository;

  GetCalendarDayUseCase({required this.repository});

  Future<CalendarDayScheduleModel> call({
    required String date,
  }) async {
    return await repository.getCalendarDay(date: date);
  }
}
