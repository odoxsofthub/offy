import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_globals.dart';
import '../../../core/constants/error_messages.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/api_error_handler.dart';
import '../../../domain/usecases/login_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class LoginProvider extends ChangeNotifier {
  LoginProvider({required this.loginUseCase, required this.sharedPreferences}) {
    _url = sharedPreferences.getString('saved_login_url') ?? '';
    _isReturningUser = _url.isNotEmpty;
  }

  final LoginUseCase loginUseCase;
  final SharedPreferences sharedPreferences;
  // Form key for validation
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  String _url = '';
  String _email = '';
  String _password = '';

  bool get obscurePassword => _obscurePassword;
  String get url => _url;
  String get email => _email;
  String get password => _password;

  late final bool _isReturningUser;

  /// True when a server URL was saved by an earlier session, so the login
  /// page greets the user with "Welcome back" instead of "Login".
  bool get isReturningUser => _isReturningUser;

  /// All three credentials are filled in (drives the button's enabled look).
  bool get hasAllFields =>
      _url.isNotEmpty && _email.isNotEmpty && _password.isNotEmpty;

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void urlChanged(String url) {
    _url = url;
    sharedPreferences.setString('saved_login_url', url);
    _clearError();
    notifyListeners();
  }

  void emailChanged(String email) {
    _email = email;
    _clearError();
    notifyListeners();
  }

  void passwordChanged(String password) {
    _password = password;
    _clearError();
    notifyListeners();
  }

  /// Clears the persistent error banner as soon as the user edits a credential.
  void _clearError() {
    _errorMessage = null;
  }

  bool _isSubmitted = false;
  bool get isSubmitted => _isSubmitted;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;

  /// Last login failure, shown as an inline banner (snackbars are cleared on every
  /// route change by `AppNavigationObserver`).
  String? get errorMessage => _errorMessage;

  Future<bool> login() async {
    _isSubmitted = true;
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    // Check if form is valid
    if (!(formKey.currentState?.validate() ?? false)) {
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (AppGlobals.isDesignMode) {
      // Show only design (simulate login)
      await Future.delayed(const Duration(milliseconds: 500));
      _isLoading = false;
      notifyListeners();
      return true;
    }

    // Actual API Call
    try {
      final success = await loginUseCase(email: _email, password: _password);
      if (!success && _errorMessage == null) {
        _errorMessage = 'Login failed. Please check your credentials.';
      }
      return success;
    } on AppException catch (e) {
      if (kDebugMode) {
        print("Login API Error: $e");
      }
      if (e.statusCode == 404) {
        _errorMessage = ErrorMessages.serverUrlNotFound;
      } else if (e is NetworkException) {
        final hasInternet = await InternetConnectionChecker.instance.hasConnection
            .timeout(const Duration(milliseconds: 2500), onTimeout: () => false);
        if (hasInternet) {
          _errorMessage = ErrorMessages.serverUnreachable;
        } else {
          _errorMessage = e.toString();
        }
      } else {
        _errorMessage = e.toString();
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print("Login API Error: $e");
      }
      final handled = ApiErrorHandler.handle(e);
      if (handled.statusCode == 404) {
        _errorMessage = ErrorMessages.serverUrlNotFound;
      } else if (handled is NetworkException) {
        final hasInternet = await InternetConnectionChecker.instance.hasConnection
            .timeout(const Duration(milliseconds: 2500), onTimeout: () => false);
        if (hasInternet) {
          _errorMessage = ErrorMessages.serverUnreachable;
        } else {
          _errorMessage = handled.toString();
        }
      } else {
        _errorMessage = handled.toString();
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
