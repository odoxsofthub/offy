import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../errors/app_exception.dart';
import '../navigation/app_router.dart';
import '../constants/error_messages.dart';

class NetworkInterceptor extends ChangeNotifier {
  NetworkInterceptor._() {
    // configure() re-applies the timeout to every address (v3 bakes it in at construction);
    // 2 s per probe keeps hasConnection inside the 5 s Try Again window.
    InternetConnectionChecker.instance.configure(
      timeout: const Duration(seconds: 2),
    );
    // No onStatusChange listener: auto-retrying on "connected" caused an infinite loop.
    // Retry is user-initiated only (Try Again).
  }

  static final NetworkInterceptor instance = NetworkInterceptor._();

  bool _isOfflineBlocking = false;
  bool _shouldPopOnCancel = false;
  bool _isChecking = false;
  bool _isServerUnreachable = false;
  Completer<bool>? _waitingCompleter;
  final List<Completer<bool>> _waitingStack = [];
  final Set<Route<dynamic>> _activeSubmissionRoutes = {};
  // Deduplicate parallel network error connection checks
  Future<void>? _networkErrorFuture;
  // Deduplicate parallel connection check retries
  Future<bool>? _checkConnectionFuture;
  // Abort hook: assigned inside checkConnectionManually, called by cancelManually
  // to cleanly stop any in-flight timer and stream subscription immediately.
  VoidCallback? _cancelCheck;
  // Registered by HomePage when mounted so cancelManually can navigate back to
  // the previous bottom-nav tab without a broken cross-context Provider lookup.
  VoidCallback? _onTabNavigateBack;
  // Timestamp of the last manual cancellation to suppress lagging in-flight
  // failures from re-opening the error overlay.
  DateTime? _lastCancelledAt;
  // "Try Again" tapped before withRetry joined _waitingStack; consumed on its next park.
  bool _pendingRetry = false;

  bool get isOfflineBlocking => _isOfflineBlocking;
  bool get isChecking => _isChecking;
  bool get isServerUnreachable => _isServerUnreachable;
  bool get shouldPopOnCancel => _shouldPopOnCancel;

  /// Called by [HomePage] on mount so [cancelManually] can switch the bottom-nav
  /// back to the previous tab when the error overlay is dismissed.
  void registerTabNavigateBack(VoidCallback callback) {
    _onTabNavigateBack = callback;
  }

  /// Called by [HomePage] on dispose to prevent stale callback invocations.
  void unregisterTabNavigateBack() {
    _onTabNavigateBack = null;
  }

  final List<VoidCallback> _preDismissCallbacks = [];

  /// Register an atomic pre-dismissal callback (e.g. silent text clearing)
  /// executed immediately before the offline overlay state is dismissed.
  void registerPreDismissCallback(VoidCallback callback) {
    if (!_preDismissCallbacks.contains(callback)) {
      _preDismissCallbacks.add(callback);
    }
  }

  /// Unregister a pre-dismissal callback.
  void unregisterPreDismissCallback(VoidCallback callback) {
    _preDismissCallbacks.remove(callback);
  }

  void _executePreDismissCallbacks() {
    for (final callback in List<VoidCallback>.from(_preDismissCallbacks)) {
      try {
        callback();
      } catch (e) {
        _log('_executePreDismissCallbacks error: $e');
      }
    }
  }

  void _setOfflineState(bool isOffline, {bool isPageInitRequest = false}) {
    if (_isOfflineBlocking != isOffline) {
      if (!isOffline) {
        _executePreDismissCallbacks();
      }
      _isOfflineBlocking = isOffline;
      if (isOffline) {
        _shouldPopOnCancel = isPageInitRequest;
      }
      _log('_isOfflineBlocking → $isOffline');
      notifyListeners();
    }
  }

  void _releaseAllWaitingRequests(bool shouldRetry) {
    while (_waitingStack.isNotEmpty) {
      final completer = _waitingStack.removeLast();
      if (!completer.isCompleted) {
        completer.complete(shouldRetry);
      }
    }
    final singleCompleter = _waitingCompleter;
    _waitingCompleter = null;
    if (singleCompleter != null && !singleCompleter.isCompleted) {
      singleCompleter.complete(shouldRetry);
    }
  }

  Future<void> _handleNetworkError(
    bool isPageInitRequest,
    bool isLogin, {
    Object? error,
  }) async {
    _log('_handleNetworkError: isLogin=$isLogin, error=$error');

    if (isLogin) {
      final hasInternet = await InternetConnectionChecker.instance.hasConnection
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      _isServerUnreachable = true;
      _log(
        '_handleNetworkError (login): hasInternet=$hasInternet → serverUnreachable',
      );
      throw const NetworkException(ErrorMessages.serverUnreachable);
    }

    // Deduplicate concurrent connection probes across parallel failing requests
    if (_networkErrorFuture != null) {
      return await _networkErrorFuture!;
    }

    final completer = Completer<void>();
    _networkErrorFuture = completer.future;

    try {
      _isChecking = false;

      // Smart classification: TimeoutException, connection refused, or unreachable host
      // indicates the server is unreachable/slow rather than device being offline.
      bool likelyServerIssue = error is TimeoutException;
      if (error is SocketException) {
        final msg = error.message.toLowerCase();
        final errorCode = error.osError?.errorCode;
        if (msg.contains('refused') ||
            msg.contains('timed out') ||
            msg.contains('reset') ||
            msg.contains('no route') ||
            msg.contains('host is down') ||
            errorCode == 111 ||
            errorCode == 61 ||
            errorCode == 10061 ||
            errorCode == 1225 ||
            errorCode == 113 ||
            errorCode == 65 ||
            errorCode == 10065 ||
            errorCode == 64 ||
            errorCode == 10064) {
          likelyServerIssue = true;
        }
      } else if (error is http.ClientException) {
        final msg = error.message.toLowerCase();
        if (msg.contains('refused') ||
            msg.contains('timed out') ||
            msg.contains('reset')) {
          likelyServerIssue = true;
        }
      }

      _isServerUnreachable = likelyServerIssue;

      // Probe device internet reachability with a 2.5s window comfortably exceeding the 2s check
      final hasInternet = await InternetConnectionChecker.instance.hasConnection
          .timeout(const Duration(milliseconds: 2500), onTimeout: () => likelyServerIssue);
      _isServerUnreachable = likelyServerIssue || hasInternet;
      _log(
        '_handleNetworkError: likelyServerIssue=$likelyServerIssue, hasInternet=$hasInternet → _isServerUnreachable=$_isServerUnreachable',
      );

      // Now show the exact matching error overlay with 0 visual flicker
      _setOfflineState(true, isPageInitRequest: isPageInitRequest);
    } finally {
      _networkErrorFuture = null;
      completer.complete();
    }
  }

  /// Returns true if [error] represents a true connectivity failure (no
  /// internet / DNS / socket / connection abort), as opposed to a server or application error.
  bool _isConnectivityError(Object error) {
    if (error is SocketException) return true;
    if (error is http.ClientException) return true;
    if (error is HttpException) return true;
    final msg = error.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('clientexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('connection closed') ||
        msg.contains('connection refused') ||
        msg.contains('connection reset') ||
        msg.contains('network is unreachable') ||
        msg.contains('software caused connection abort') ||
        msg.contains('broken pipe') ||
        msg.contains('handshakeexception') ||
        msg.contains('tlsexception') ||
        msg.contains('xmlhttprequest error');
  }

  /// Runs [request]; on a connectivity failure shows the offline screen and waits
  /// for Try Again or Cancel.
  Future<T> withRetry<T>(
    Future<T> Function() request, {
    Duration? timeout,
    bool retryOnTimeout = true,
    bool isSubmission = false,
  }) async {
    final lastPush = AppNavigationObserver.lastPushOnlyTime;
    final requestRoute = AppNavigationObserver.lastPushedRoute;
    final isPageInitRequest =
        requestRoute != null &&
        lastPush != null &&
        DateTime.now().difference(lastPush).inMilliseconds < 3000;
    final isLogin = requestRoute?.settings.name == AppRouter.login;

    // True after the user pressed Try Again (retry uses a shorter timeout).
    bool isRetrying = false;

    final requestStartTime = DateTime.now();
    // A submission whose request actually went out and then lost its
    // connection has an UNKNOWN outcome: the server may have saved it.
    var sent = false;
    AppException cancelled() => isSubmission && sent
        ? const SubmissionOutcomeUnknownException()
        : const AppException(ErrorMessages.requestCancelled);
    final currentActiveRoute =
        isSubmission ? AppNavigationObserver.currentRoute : null;
    final routeName = currentActiveRoute?.settings.name;
    // Full log screens and the home screen must never be popped as disposable modal sheets
    final isPersistentScreen = routeName == AppRouter.home ||
        routeName == AppRouter.expenseLog ||
        routeName == AppRouter.timeOffLog ||
        routeName == AppRouter.scheduleLog;
    final submissionRoute =
        (isSubmission && !isPersistentScreen) ? currentActiveRoute : null;
    if (submissionRoute != null) {
      _activeSubmissionRoutes.add(submissionRoute);
    }

    try {
      while (true) {
        if (_isOfflineBlocking) {
          if (isLogin) {
            throw const NetworkException('No internet connection');
          }
          final completer = Completer<bool>();
          // Try Again was tapped before this completer joined the stack: retry now.
          if (_pendingRetry) {
            _pendingRetry = false;
            _log(
              'withRetry: consuming _pendingRetry → treating as immediate shouldRetry=true',
            );
            completer.complete(true);
          } else {
            _waitingStack.add(completer);
            _log(
              'withRetry: waiting on _waitingStack (count: ${_waitingStack.length})',
            );
          }
          bool shouldRetry;
          try {
            if (isSubmission) {
              // Submissions wait for user-initiated retry and must not automatically re-attempt on timeout.
              shouldRetry = await completer.future;
            } else {
              // 15 s cap so the UI never locks if the user does not respond.
              shouldRetry = await completer.future.timeout(
                const Duration(seconds: 15),
                onTimeout: () {
                  _waitingStack.remove(completer);
                  _log('withRetry: wait timed out → probing connection');
                  return true;
                },
              );
            }
          } catch (e) {
            _log('withRetry: completer error: $e');
            shouldRetry = false;
          }

          if (!shouldRetry) {
            // A sent submission may already be saved: close its form so it
            // cannot be resubmitted. Unsent: keep the form.
            if (isSubmission &&
                sent &&
                submissionRoute != null &&
                submissionRoute.isActive) {
              final navigator = AppRouter.navigatorKey.currentState;
              if (navigator != null && navigator.canPop()) {
                navigator.removeRoute(submissionRoute);
              }
            }
            _log('withRetry: shouldRetry=false → throwing requestCancelled');
            throw cancelled();
          }

          if (isSubmission) {
            _log(
              'withRetry: submission request unblocked on recovery → do not resubmit',
            );
            if (submissionRoute != null && submissionRoute.isActive) {
              final navigator = AppRouter.navigatorKey.currentState;
              if (navigator != null && navigator.canPop()) {
                navigator.removeRoute(submissionRoute);
              }
            }
            throw cancelled();
          }

          _log(
            'withRetry: shouldRetry=true → attempting request (retry timeout: 20 s)',
          );
          isRetrying = true;
          // Fall through, do NOT loop: _isOfflineBlocking is still true and a new
          // completer nobody completes would deadlock every waiting request.
        }

      try {
        final effectiveTimeout = timeout ?? const Duration(seconds: 20);
        final result = await request().timeout(effectiveTimeout);
        _log('withRetry: request succeeded (isRetrying=$isRetrying)');
        // Clear _isChecking even if cancelManually already cleared the overlay,
        // or the Try Again button stays disabled.
        if (_isChecking) {
          _isChecking = false;
          _log('withRetry: request succeeded → _isChecking=false');
        }
        // Dismiss the overlay only after the request actually succeeds,
        // not merely when connectivity is detected.
        if (_isOfflineBlocking) {
          _releaseAllWaitingRequests(true);
          _setOfflineState(false);
        }
        return result;
      } on SocketException catch (e) {
        sent = true;
        if (_isChecking) {
          _isChecking = false;
          notifyListeners();
        }
        if (!isRetrying &&
            _lastCancelledAt != null &&
            requestStartTime.isBefore(_lastCancelledAt!)) {
          _log(
            'withRetry: SocketException ignored (started before last cancel)',
          );
          throw cancelled();
        }
        _log('withRetry: SocketException → _handleNetworkError');
        await _handleNetworkError(isPageInitRequest, isLogin, error: e);
      } on TimeoutException catch (e) {
        sent = true;
        if (!retryOnTimeout) {
          rethrow;
        }
        if (_isChecking) {
          _isChecking = false;
          notifyListeners();
        }
        if (!isRetrying &&
            _lastCancelledAt != null &&
            requestStartTime.isBefore(_lastCancelledAt!)) {
          _log(
            'withRetry: TimeoutException ignored (started before last cancel)',
          );
          throw cancelled();
        }
        _log('withRetry: TimeoutException → _handleNetworkError');
        await _handleNetworkError(isPageInitRequest, isLogin, error: e);
      } on http.ClientException catch (e) {
        sent = true;
        if (_isChecking) {
          _isChecking = false;
          notifyListeners();
        }
        if (!isRetrying &&
            _lastCancelledAt != null &&
            requestStartTime.isBefore(_lastCancelledAt!)) {
          _log(
            'withRetry: ClientException ignored (started before last cancel)',
          );
          throw cancelled();
        }
        _log('withRetry: ClientException → _handleNetworkError: $e');
        await _handleNetworkError(isPageInitRequest, isLogin, error: e);
      } catch (e) {
        if (_isChecking) {
          _isChecking = false;
          notifyListeners();
        }
        // AppExceptions propagate as-is, never as connectivity failures.
        if (e is AppException) rethrow;
        if (_isConnectivityError(e)) {
          sent = true;
          if (!isRetrying &&
              _lastCancelledAt != null &&
              requestStartTime.isBefore(_lastCancelledAt!)) {
            _log(
              'withRetry: connectivity error ignored (started before last cancel)',
            );
            throw cancelled();
          }
          _log('withRetry: connectivity error → _handleNetworkError: $e');
          await _handleNetworkError(isPageInitRequest, isLogin, error: e);
        } else {
          rethrow;
        }
      }
    }
  } finally {
    if (submissionRoute != null) {
      _activeSubmissionRoutes.remove(submissionRoute);
    }
  }
}

  /// Try Again: resolves true as soon as the connection is back, false after 5 s.
  Future<bool> checkConnectionManually() {
    if (_checkConnectionFuture != null) {
      _log(
        'checkConnectionManually: already in-flight → returning existing future',
      );
      return _checkConnectionFuture!;
    }

    _log('checkConnectionManually: entered → _isChecking=true');
    _isChecking = true;
    notifyListeners();

    final completer = Completer<bool>();
    _checkConnectionFuture = completer.future;

    StreamSubscription<InternetConnectionStatus>? statusSubscription;
    Timer? timeoutTimer;

    void resolve(bool connected) {
      if (completer.isCompleted) return;
      _log(
        'checkConnectionManually: resolve($connected) → cancelling timer & subscription',
      );
      statusSubscription?.cancel();
      timeoutTimer?.cancel();
      _checkConnectionFuture = null;
      _cancelCheck = null;

      if (connected) {
        _isServerUnreachable = false;
        _isChecking = false;

        // Close any active submission UI routes behind the offline overlay before
        // dismissing the overlay, ensuring no closing transition is seen by the user.
        final navigator = AppRouter.navigatorKey.currentState;
        if (navigator != null) {
          for (final route in _activeSubmissionRoutes) {
            if (route.isActive && navigator.canPop()) {
              navigator.removeRoute(route);
            }
          }
        }
        _activeSubmissionRoutes.clear();

        _releaseAllWaitingRequests(true);
        _setOfflineState(false);
        notifyListeners();
        completer.complete(true);
      } else {
        _log(
          'checkConnectionManually: resolve(false) → _isChecking=false, show Try again',
        );
        _isChecking = false;
        InternetConnectionChecker.instance.hasConnection
            .then((hasInternet) {
              _isServerUnreachable = hasInternet;
              notifyListeners();
            })
            .catchError((e) {
              _log('checkConnectionManually: error probing reachability: $e');
              notifyListeners();
            });
        completer.complete(false);
      }
    }

    _cancelCheck = () => resolve(false);

    // SERVER ERROR SCREEN: checks server connection directly with an API call
    if (_isServerUnreachable) {
      if (_activeSubmissionRoutes.isNotEmpty) {
        _log(
          'checkConnectionManually: server unreachable state with active submission → checking connection without probing API',
        );
        _checkConnectionFuture = null;
        InternetConnectionChecker.instance.hasConnection.then(
          (isConnected) {
            resolve(isConnected);
          },
          onError: (e) {
            _log('checkConnectionManually: hasConnection error: $e');
            resolve(false);
          },
        );
        return completer.future;
      }

      _log(
        'checkConnectionManually: server unreachable state → probing API with latest request',
      );
      _checkConnectionFuture = null;
      if (_waitingStack.isNotEmpty) {
        final latestCompleter = _waitingStack.removeLast();
        if (!latestCompleter.isCompleted) {
          latestCompleter.complete(true);
        }
      } else {
        _pendingRetry = true;
      }
      completer.complete(true);
      return completer.future;
    }

    // NETWORK ERROR SCREEN: checks network status over a 5-second reactive window

    _log('checkConnectionManually: starting 5-second timer for network check');
    timeoutTimer = Timer(const Duration(seconds: 5), () {
      _log('checkConnectionManually: 5-second timer fired');
      resolve(false);
    });

    statusSubscription = InternetConnectionChecker.instance.onStatusChange
        .listen((status) {
          _log('checkConnectionManually: onStatusChange → $status');
          if (status == InternetConnectionStatus.connected) {
            resolve(true);
          }
        });

    InternetConnectionChecker.instance.hasConnection.then(
      (isConnected) {
        _log(
          'checkConnectionManually: hasConnection immediate result → $isConnected',
        );
        if (isConnected) resolve(true);
      },
      onError: (e) {
        _log('checkConnectionManually: hasConnection immediate error: $e');
      },
    );

    return completer.future;
  }

  /// Triggered by the "Cancel" button on the UI
  void cancelManually() {
    _log('cancelManually: called');

    // Stop any running check so it cannot resolve(true) after the cancel.
    _cancelCheck?.call();
    _cancelCheck = null;

    _lastCancelledAt = DateTime.now();
    // Clear any pending retry so a cancelled "Try Again" tap cannot accidentally
    // re-fire the request after cancel clears the offline state.
    _pendingRetry = false;
    _isChecking = false;
    _isServerUnreachable = false;
    _activeSubmissionRoutes.clear();
    _releaseAllWaitingRequests(false);
    _setOfflineState(false);

    final pop = _shouldPopOnCancel;
    _shouldPopOnCancel = false;

    if (pop) {
      // Pushed screen (e.g. TimeOffPage, LeaveHistory, SubmitExpense):
      // Only pop back to the previous screen without touching bottom-nav tabs.
      AppRouter.navigatorKey.currentState?.pop(false);
    } else {
      // Bottom-nav tab switch on HomePage: navigate back to the previous tab.
      _onTabNavigateBack?.call();
    }
  }

  /// Reset all offline state without popping navigation routes (used during logout).
  void resetOfflineState() {
    _log('resetOfflineState: called');
    _cancelCheck?.call();
    _cancelCheck = null;
    _pendingRetry = false;
    _isChecking = false;
    _isServerUnreachable = false;
    _activeSubmissionRoutes.clear();
    _shouldPopOnCancel = false;
    _releaseAllWaitingRequests(false);
    _setOfflineState(false);
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[NetworkInterceptor] $message');
    }
  }
}
