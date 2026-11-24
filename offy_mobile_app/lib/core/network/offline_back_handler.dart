import 'package:flutter/widgets.dart';

import '../services/app_update_service.dart';
import 'network_interceptor.dart';

/// Sends Android back to the offline screen, which sits above the Navigator (no PopScope route).
/// [install] runs before `runApp` so this observer is asked ahead of `WidgetsApp`.
class OfflineBackHandler with WidgetsBindingObserver {
  OfflineBackHandler._();

  static final OfflineBackHandler instance = OfflineBackHandler._();

  /// Set by the offline screen while it is shown.
  VoidCallback? onBack;

  /// Whether the offline screen is up.
  @visibleForTesting
  bool Function() isOfflineBlocking =
      () => NetworkInterceptor.instance.isOfflineBlocking;

  void install() => WidgetsBinding.instance.addObserver(this);

  @visibleForTesting
  void uninstall() => WidgetsBinding.instance.removeObserver(this);

  @override
  Future<bool> didPopRoute() async {
    // A force update has no way back: swallow back entirely.
    if (AppUpdateService.instance.forceUpdate.value != null) return true;
    if (!isOfflineBlocking()) return false;
    // Always consume back here so the page underneath is never popped.
    onBack?.call();
    return true;
  }
}
