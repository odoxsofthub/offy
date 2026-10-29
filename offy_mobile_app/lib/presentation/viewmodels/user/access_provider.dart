import 'package:flutter/widgets.dart';
import '../../../core/base/session_provider.dart';
import '../../../core/navigation/app_router.dart';
import '../../../data/models/access_details_response_model.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../domain/usecases/get_access_details_usecase.dart';

class AccessProvider extends SessionProvider {
  final GetAccessDetailsUseCase getAccessDetailsUseCase;
  final UserRepository userRepository;

  AccessProvider({
    required this.getAccessDetailsUseCase,
    required this.userRepository,
    super.sessionResetService,
  }) {
    _loadCachedAccessDetails();
  }

  void _loadCachedAccessDetails() {
    final cached = userRepository.getCachedAccessDetails();
    if (cached != null) {
      _accessDetails = cached;
    }
  }

  AccessDetailsResponseModel? _accessDetails;
  AccessDetailsResponseModel? get accessDetails => _accessDetails;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void _checkRevokedFeatures(
    AccessDetailsResponseModel? oldDetails,
    AccessDetailsResponseModel? newDetails,
  ) {
    if (oldDetails == null || newDetails == null) return;
    const revokable = [
      'attendance',
      'expense',
      'time_off',
      'payslip',
      'calendar',
    ];
    for (final feature in revokable) {
      final wasActive =
          oldDetails.features?.any((f) => f.code == feature && f.active) ??
          false;
      final isNowActive =
          newDetails.features?.any((f) => f.code == feature && f.active) ??
          false;
      if (wasActive && !isNowActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AppRouter.handleFeatureRevoked(feature);
        });
      }
    }
  }

  Future<void> fetchAccessDetails({bool silent = false}) async {
    if (_accessDetails == null && !silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final details = await getAccessDetailsUseCase(
        retryOnNetworkError: !silent,
      );
      _checkRevokedFeatures(_accessDetails, details);
      _accessDetails = details;
      await userRepository.cacheAccessDetails(details);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Replace the permission set.
  void applyAccessDetails(AccessDetailsResponseModel details) {
    _checkRevokedFeatures(_accessDetails, details);
    _accessDetails = details;
    _errorMessage = null;
    userRepository.cacheAccessDetails(details);
    notifyListeners();
  }

  /// Whether the user is a mobile user.
  bool get isMobileUser => _accessDetails?.user?.mobileUser ?? true;

  FeatureModel? getFeature(String code) {
    if (_accessDetails?.features == null) return null;
    try {
      return _accessDetails!.features!.firstWhere((feature) => feature.code == code);
    } catch (e) {
      return null;
    }
  }

  bool hasFeature(String code) {
    if (_accessDetails?.features == null) return false;
    try {
      return _accessDetails!.features!.any((f) => f.code == code && f.active);
    } catch (e) {
      return false;
    }
  }

  @override
  void resetState() {
    _accessDetails = null;
    _isLoading = false;
    _errorMessage = null;
    userRepository.clearAccessDetailsCache();
    notifyListeners();
  }
}
