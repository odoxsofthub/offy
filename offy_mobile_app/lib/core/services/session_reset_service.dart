import 'dart:developer' as developer;

abstract class SessionResettable {
  void resetState();
}

class SessionResetService {
  final Set<SessionResettable> _registry = <SessionResettable>{};

  void register(SessionResettable target) {
    _registry.add(target);
  }

  void unregister(SessionResettable target) {
    _registry.remove(target);
  }

  void resetAll() {
    for (final target in _registry.toList()) {
      try {
        target.resetState();
      } catch (e, stackTrace) {
        developer.log(
          '❌ [SessionReset error in ${target.runtimeType}]: $e',
          error: e,
          stackTrace: stackTrace,
          name: 'SessionResetService',
        );
      }
    }
  }
}
