import '../../data/models/calendar_day_schedule_model.dart';
import '../repositories/timeoff_repository.dart';

class GetTimeOffCalendarDayUseCase {
  final TimeOffRepository repository;

  GetTimeOffCalendarDayUseCase(this.repository);

  Future<CalendarDayScheduleModel> call({required String date}) async {
    return await repository.getTimeOffCalendarDay(date: date);
  }
}
