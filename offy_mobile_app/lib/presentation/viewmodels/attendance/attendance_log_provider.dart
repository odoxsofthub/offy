import '../../../core/base/session_provider.dart';
import '../../../domain/usecases/get_attendance_logs_usecase.dart';
import '../../../data/models/attendance_log_response_model.dart';

class AttendanceLogProvider extends SessionProvider {
  final GetAttendanceLogsUseCase getAttendanceLogsUseCase;

  AttendanceLogProvider({
    required this.getAttendanceLogsUseCase,
    super.sessionResetService,
  });

  @override
  void resetState() {
    _logs = [];
    _avgInTime = '-';
    _avgWorkedHour = '-';
    _currentPage = 1;
    _hasNext = true;
    _currentMonth = DateTime.now().month;
    _currentYear = DateTime.now().year;
    _isLoading = false;
    _isLoadingMore = false;
    _errorMessage = null;
    _activeRequestId = 0;
    notifyListeners();
  }

  int _activeRequestId = 0;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<AttendanceLogEntryModel> _logs = [];
  List<AttendanceLogEntryModel> get logs => _logs;

  String _avgInTime = '-';
  String get avgInTime => _avgInTime;

  String _avgWorkedHour = '-';
  String get avgWorkedHour => _avgWorkedHour;

  int _currentPage = 1;
  bool _hasNext = true;
  bool get hasNext => _hasNext;

  int _currentMonth = DateTime.now().month;
  int get currentMonth => _currentMonth;

  int _currentYear = DateTime.now().year;
  int get currentYear => _currentYear;

  Future<void> fetchLogs({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasNext = true;
      _errorMessage = null;
      _isLoading = true;
      _isLoadingMore = false;
    } else {
      if (_isLoading || _isLoadingMore || !_hasNext) return;
      _isLoadingMore = true;
      _errorMessage = null;
    }

    final requestId = ++_activeRequestId;
    notifyListeners();

    try {
      final targetPage = refresh ? 1 : _currentPage + 1;
      final response = await getAttendanceLogsUseCase(
        month: _currentMonth,
        year: _currentYear,
        page: targetPage,
        limit: 10,
      );

      if (requestId != _activeRequestId) return;

      if (refresh) {
        _logs = response.logs;
      } else {
        _logs.addAll(response.logs);
      }

      _currentPage = targetPage;
      _avgInTime = response.avgInTime;
      _avgWorkedHour = response.avgWorkedHour;
      _hasNext = response.pagination.hasNext;
      _errorMessage = null;
    } catch (e) {
      if (requestId != _activeRequestId) return;
      _errorMessage = e.toString();
    } finally {
      if (requestId == _activeRequestId) {
        _isLoading = false;
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  void updateDateFilter(int month, int year) {
    if (_currentMonth == month && _currentYear == year && !_isLoading) return;
    _currentMonth = month;
    _currentYear = year;
    fetchLogs(refresh: true);
  }
}
