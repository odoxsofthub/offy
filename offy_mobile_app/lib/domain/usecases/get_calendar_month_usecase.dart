import '../../data/models/calendar_month_response_model.dart';
import '../repositories/calendar_repository.dart';

class GetCalendarMonthUseCase {
  final CalendarRepository repository;

  GetCalendarMonthUseCase({required this.repository});

  Future<CalendarMonthDataModel> call({
    required int year,
    required int month,
  }) async {
    return await repository.getCalendarMonth(year: year, month: month);
  }
}
