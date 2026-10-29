import '../../../core/base/session_provider.dart';
import '../../../domain/usecases/get_home_data_usecase.dart';
import '../../../data/models/home_response_model.dart';
import '../attendance/attendance_provider.dart';

class HomeProvider extends SessionProvider {
  final GetHomeDataUseCase getHomeDataUseCase;

  HomeProvider({
    required this.getHomeDataUseCase,
    super.sessionResetService,
  });

  @override
  void resetState() {
    _homeData = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  HomeDataModel? _homeData;
  HomeDataModel? get homeData => _homeData;

  void markNotificationsAsRead() {
    if (_homeData?.home != null && _homeData!.home!.hasUnreadNotifications) {
      _homeData = _homeData!.copyWith(
        home: _homeData!.home!.copyWith(hasUnreadNotifications: false),
      );
      notifyListeners();
    }
  }

  Future<void> fetchHomeData(
    AttendanceProvider attendanceProvider, {
    bool silent = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await getHomeDataUseCase(
        retryOnNetworkError: !silent,
      );
      _homeData = data;
      
      // Sync attendance provider state
      final attendanceModel = data.home?.attendance;
      if (attendanceModel != null) {
        attendanceProvider.updateAttendanceState(attendanceModel);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
