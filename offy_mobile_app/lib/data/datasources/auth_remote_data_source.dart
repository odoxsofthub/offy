import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_globals.dart';
import '../../../core/constants/error_messages.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/network_interceptor.dart';
import '../../../core/services/push_notification_service.dart';
import '../models/login_response_model.dart';

import 'dart:developer' as developer;

abstract class AuthRemoteDataSource {
  Future<bool> login(String email, String password);
  Future<bool> refreshToken();
  Future<LoginResponseModel> switchCompany(int companyId);
  Future<void> registerDeviceToken(String token, String deviceType);
  Future<void> logout();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl({
    required this.apiClient,
    this.pushNotificationService,
  });

  final ApiClient apiClient;
  final PushNotificationService? pushNotificationService;
  Future<bool>? _refreshTokenFuture;

  @override
  Future<LoginResponseModel> switchCompany(int companyId) async {
    final tokenStorage = apiClient.tokenStorage;
    final refreshToken = await tokenStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const UnauthorizedException('No refresh token available');
    }

    final response = await apiClient.patch<LoginResponseModel>(
      ApiConstants.switchCompany,
      body: {
        "refreshToken": refreshToken,
        "companyIds": [companyId],
      },
      parser: (json) =>
          LoginResponseModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.success && response.data != null) {
      return response.data!;
    }
    throw const AppException('Failed to switch company');
  }

  @override
  Future<bool> login(String email, String password) async {
    final response = await apiClient.post<LoginResponseModel>(
      ApiConstants.login,
      body: {
        "login": email,
        "password": password,
      },
      retryOnNetworkError: false,
      parser: (json) => LoginResponseModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.success && response.data != null) {
      final data = response.data!;
      if (data.refreshToken == null || data.refreshToken!.isEmpty) {
        throw const AppException('Login failed: missing refresh token');
      }
      await apiClient.tokenStorage.clear();
      await apiClient.tokenStorage.saveRefreshToken(data.refreshToken!);
      await apiClient.tokenStorage.saveBearerToken(data.token);
      if (data.companySessionId != null &&
          data.companySessionId!.isNotEmpty) {
        await apiClient.tokenStorage.saveSessionId(
          data.companySessionId!,
        );
      }
      if (data.primarySelectedCompanyId != null) {
        await apiClient.tokenStorage.saveSelectedCompanyId(
          data.primarySelectedCompanyId!,
        );
      }
      return true;
    }
    
    throw AppException(
      response.message.isNotEmpty ? response.message : 'Login failed',
    );
  }

  @override
  Future<bool> refreshToken() async {
    if (_refreshTokenFuture != null) {
      developer.log('Refresh token already in progress. Waiting for it to complete...', name: 'Auth');
      return await _refreshTokenFuture!;
    }

    _refreshTokenFuture = _performRefreshToken();
    try {
      final result = await _refreshTokenFuture!;
      return result;
    } finally {
      _refreshTokenFuture = null;
    }
  }

  Future<bool> _performRefreshToken() async {
    try {
      final tokenStorage = apiClient.tokenStorage;
      final refreshToken = await tokenStorage.readRefreshToken();
      final sessionId = await tokenStorage.readSessionId();

      if (refreshToken == null || refreshToken.isEmpty || ApiConstants.baseUrl.isEmpty) {
        return false;
      }

      if (AppGlobals.isDesignMode) {
        await Future.delayed(const Duration(milliseconds: 100));
        return true;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final headers = {
        'Content-Type': 'application/json',
        'X-Platform': Platform.operatingSystem,
        'X-App-Version': packageInfo.version,
      };

      // Company-session selector (not an Odoo session id) so the refreshed token keeps the device's company.
      final mobileSession = mobileSessionValue(sessionId);
      if (mobileSession.isNotEmpty) {
        headers['X-Mobile-Session'] = mobileSession;
      }

      final url = '${ApiConstants.baseUrl}${ApiConstants.refresh}';
      final body = json.encode({"refreshToken": refreshToken});

      // Do NOT retry on timeout or 5xx: backend rotates and revokes the token upon receipt.
      // Retrying with the same token would cause a false 401.
      final response = await NetworkInterceptor.instance.withRetry(
        () async {
          return await http.post(
            Uri.parse(url),
            headers: headers,
            body: body,
          );
        },
        timeout: const Duration(seconds: 15),
        retryOnTimeout: false,
      );

      // 1. Explicit 401 / 403 status codes mean the refresh token is expired or revoked.
      if (response.statusCode == 401 || response.statusCode == 403) {
        return false;
      }

      // 2. Outages and rate limits must throw ServerException, NEVER returning false.
      if (response.statusCode == 408 || response.statusCode == 429) {
        throw const ServerException(ErrorMessages.connectionTimeout);
      }
      if (response.statusCode >= 500) {
        throw const ServerException(ErrorMessages.internalServerError);
      }

      // 3. Parse JSON safely, mapping FormatException and TypeError to ServerException
      final dynamic jsonResponse;
      try {
        jsonResponse = json.decode(response.body);
      } on FormatException {
        throw const ServerException('Invalid JSON response from refresh endpoint');
      } catch (e) {
        throw ServerException('Failed to decode refresh response: $e');
      }

      if (jsonResponse is! Map<String, dynamic>) {
        throw const ServerException('Unexpected response payload from refresh endpoint');
      }

      // 4. Check for explicit backend error codes for invalid refresh tokens
      final errorCode = jsonResponse['code'];
      if (errorCode == 'invalid_refresh_token' ||
          errorCode == 'missing_refresh_token' ||
          errorCode == 'mobile_access_denied' ||
          errorCode == 'employee_not_linked') {
        return false;
      }

      // 5. 2xx with success == true and data != null: save tokens, return true.
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (jsonResponse['success'] == true &&
            jsonResponse['data'] is Map<String, dynamic>) {
          final LoginResponseModel model;
          try {
            model = LoginResponseModel.fromJson(
              jsonResponse['data'] as Map<String, dynamic>,
            );
          } catch (e) {
            throw ServerException('Failed to parse refresh model: $e');
          }

          // Save refresh token BEFORE bearer token to prevent leaving a dead refresh token
          // Only save if non-null and non-empty; keep existing token otherwise.
          if (model.refreshToken != null && model.refreshToken!.isNotEmpty) {
            await tokenStorage.saveRefreshToken(model.refreshToken!);
          }
          await tokenStorage.saveBearerToken(model.token);
          if (model.companySessionId != null &&
              model.companySessionId!.isNotEmpty) {
            await tokenStorage.saveSessionId(model.companySessionId!);
          }
          return true;
        }

        final message = jsonResponse['message'] as String? ?? 'Token refresh failed';
        throw ServerException(message);
      }

      // Any other unrecognized status code
      throw ServerException('Server error (${response.statusCode}): ${response.body}');
    } catch (e) {
      if (e is ServerException ||
          e is NetworkException ||
          e is SocketException ||
          e is TimeoutException ||
          e is AppException) {
        rethrow;
      }
      throw ServerException('Unexpected error during token refresh: $e');
    }
  }

  @override
  Future<void> registerDeviceToken(String token, String deviceType) async {
    try {
      await apiClient.post(
        ApiConstants.deviceToken,
        body: {
          "firebase_id": token,
          "device_type": deviceType,
        },
        retryOnNetworkError: false,
        parser: (json) => null, // Just checking status, ignoring response data
      );
    } catch (e) {
      developer.log('Failed to register device token: $e', name: 'Auth');
    }
  }

  @override
  Future<void> logout() async {
    try {
      final tokenStorage = apiClient.tokenStorage;
      final refreshToken = await tokenStorage.readRefreshToken();

      String? firebaseToken;
      try {
        firebaseToken = await pushNotificationService?.getToken();
      } catch (e) {
        developer.log('Failed to get firebase token for logout: $e', name: 'Auth');
      }

      if (!AppGlobals.isDesignMode) {
        await apiClient.post(
          ApiConstants.logout,
          body: {
            if (firebaseToken != null && firebaseToken.isNotEmpty)
              "firebase_id": firebaseToken,
            if (refreshToken != null && refreshToken.isNotEmpty)
              "refreshToken": refreshToken,
          },
          parser: (json) => null,
        );
      }
    } catch (e) {
      developer.log('Failed to call logout api: $e', name: 'Auth');
    } finally {
      try {
        await pushNotificationService?.deleteToken();
      } catch (e) {
        developer.log('Failed to delete FCM token during logout: $e', name: 'Auth');
      }
      await apiClient.tokenStorage.clear();
    }
  }
}
