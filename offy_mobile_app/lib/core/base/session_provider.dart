import 'package:flutter/foundation.dart';
import '../services/session_reset_service.dart';

abstract class SessionProvider extends ChangeNotifier implements SessionResettable {
  final SessionResetService? sessionResetService;
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  SessionProvider({this.sessionResetService}) {
    sessionResetService?.register(this);
  }

  @override
  void dispose() {
    _isDisposed = true;
    sessionResetService?.unregister(this);
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void resetState();
}
