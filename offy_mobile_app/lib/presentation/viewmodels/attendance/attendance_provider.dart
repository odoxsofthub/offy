import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../../domain/usecases/perform_attendance_action_usecase.dart';
import '../../../data/models/home_response_model.dart';
import '../user/access_provider.dart';

class AttendanceProvider extends ChangeNotifier {
  final PerformAttendanceActionUseCase performAttendanceActionUseCase;

  AttendanceProvider({required this.performAttendanceActionUseCase});

  bool _isCheckedIn = false;
  bool get isCheckedIn => _isCheckedIn;

  bool _isCheckedOut = false;
  bool get isCheckedOut => _isCheckedOut;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _checkInTime;
  String? get checkInTime => _checkInTime;

  String? _checkOutTime;
  String? get checkOutTime => _checkOutTime;

  void updateAttendanceState(AttendanceStatusModel model) {
    if (!model.enabled) return;

    _isCheckedIn = model.status == 'checked_in';
    _checkInTime = model.checkIn;
    _checkOutTime = model.checkOut;
    _isCheckedOut = model.status == 'checked_out';
    notifyListeners();
  }

  Future<bool> toggleAttendance(
    AccessProvider accessProvider, {
    Future<void> Function()? onSyncHome,
    String Function(int distance, bool isCheckOut)? onTooFar,
  }) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      final attendanceFeature = accessProvider.getFeature('attendance');
      final gps = attendanceFeature?.gps;

      final actionRequired = _isCheckedIn
          ? (gps?.checkoutRequired ?? false)
          : (gps?.checkinRequired ?? false);
      final isGpsEnabledConfig = gps?.enabled ?? false;
      final needsGps = isGpsEnabledConfig && actionRequired;

      double? lat;
      double? lng;

      if (needsGps) {
        // 1. Check and request location permission
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          _errorMessage = 'LOCATION_REQUIRED';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            _errorMessage = 'LOCATION_REQUIRED';
            _isLoading = false;
            notifyListeners();
            return false;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          _errorMessage = 'LOCATION_REQUIRED';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        // 2. Get current location
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
        lat = position.latitude;
        lng = position.longitude;

        // 2.5 Geofencing check
        if (gps != null) {
          final distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            gps.companyLatitude,
            gps.companyLongitude,
          );

          if (distance > gps.boundaryMeters) {
            _errorMessage = onTooFar != null
                ? onTooFar(gps.boundaryMeters, _isCheckedIn)
                : 'You are too far from the office. You must be within ${gps.boundaryMeters} meters to ${_isCheckedIn ? 'check out' : 'check in'}.';
            _isLoading = false;
            notifyListeners();
            return false;
          }
        }
      }

      // 3. Call API
      final action = _isCheckedIn ? 'check_out' : 'check_in';
      await performAttendanceActionUseCase(
        action: action,
        latitude: lat,
        longitude: lng,
      );

      // State is strictly updated from the Home API response via onSyncHome
      if (onSyncHome != null) {
        await onSyncHome();
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (e is TimeoutException) {
        _errorMessage =
            'Location request timed out. Please check your GPS signal and try again.';
      } else {
        _errorMessage = e.toString();
      }
      _isLoading = false;
      notifyListeners();
      // Reconcile actual punch state with backend on error/cancellation in background without keeping button locked in loading
      try {
        if (onSyncHome != null) {
          await onSyncHome();
        }
      } catch (_) {
        debugPrint('[AttendanceProvider] onSyncHome fallback sync failed');
      }
      return false;
    }
  }
}
