import '../../data/models/calendar_month_response_model.dart';
import '../repositories/timeoff_repository.dart';

class GetTimeOffCalendarMonthUseCase {
  final TimeOffRepository repository;

  GetTimeOffCalendarMonthUseCase(this.repository);

  Future<CalendarMonthDataModel> call({
    required int year,
    required int month,
  }) async {
    return await repository.getTimeOffCalendarMonth(
      year: year,
      month: month,
    );
  }
}
