import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../errors/app_exception.dart';
import '../errors/api_error_handler.dart';
import '../services/observability_service.dart';
import '../services/token_storage.dart';
import 'api_response.dart';
import 'network_interceptor.dart';
import 'mock_api_data.dart';
import '../constants/app_globals.dart';

/// Normalises the stored company-session selector for `X-Mobile-Session`.
/// Older builds stored a cookie string; send the bare token, or '' when unrecognisable.
String mobileSessionValue(String? stored) {
  final raw = (stored ?? '').trim();
  if (raw.isEmpty) return '';
  if (!raw.contains('=')) return raw;

  for (final part in raw.split(';')) {
    final segment = part.trim();
    if (segment.startsWith('session_id=')) {
      return segment.substring('session_id='.length).trim();
    }
  }
  return '';
}

class ApiClient {
  ApiClient({
    required this.tokenStorage,
    this.onRefreshToken,
    this.onUnauthenticated,
  });

  final TokenStorage tokenStorage;
  final Future<bool> Function()? onRefreshToken;
  final Future<void> Function()? onUnauthenticated;

  String get baseUrl => ApiConstants.baseUrl;

  static const Duration defaultTimeout = Duration(seconds: 25);
  static const Duration defaultMultipartTimeout = Duration(seconds: 60);

  /// Returns standard authentication & company-session headers for media/attachment
  /// endpoints (images, PDFs, documents) scoped to [ApiConstants.baseUrl].
  static Future<Map<String, String>> getMediaHeaders([String? url]) async {
    final bool isApiUrl =
        url == null || url.isEmpty || ApiConstants.isServerUrl(url);
    if (!isApiUrl) return const {};

    try {
      final tokenStorage = GetIt.instance<TokenStorage>();
      final savedBearer = await tokenStorage.readBearerToken();
      final savedSession = await tokenStorage.readSessionId();
      final bearerToken = savedBearer ?? ApiConstants.defaultBearerToken;
      final sessionValue = mobileSessionValue(savedSession);

      return {
        if (bearerToken.isNotEmpty) 'Authorization': 'Bearer $bearerToken',
        if (sessionValue.isNotEmpty) 'X-Mobile-Session': sessionValue,
      };
    } catch (_) {
      return const {};
    }
  }

  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    required T Function(Object? json) parser,
    bool retryOnNetworkError = true,
    Duration? timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    var url = '$baseUrl$endpoint';

    if (AppGlobals.isDesignMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      final mockJson = MockApiData.getMockResponse('GET', endpoint);
      final response = http.Response.bytes(
        utf8.encode(jsonEncode(mockJson)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
      return _parseResponse(response, parser);
    }

    final trace = ObservabilityService.instance.startApiTrace('GET', url);
    try {
      Uri uri = Uri.parse(url);
      if (queryParameters != null && queryParameters.isNotEmpty) {
        final mergedParams = <String, String>{};
        if (uri.queryParameters.isNotEmpty) {
          mergedParams.addAll(uri.queryParameters);
        }
        queryParameters.forEach((key, value) {
          if (value != null) {
            mergedParams[key] = value.toString();
          }
        });
        final queryString = mergedParams.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
        uri = uri.replace(query: queryString);
        url = uri.toString();
      }
      final result = await _withTokenRefresh(endpoint, () async {
        Future<ApiResponse<T>> requestFn() async {
          final currentHeaders = await _headers();
          _logRequest('GET', url, currentHeaders, null);
          final response = await http.get(uri, headers: currentHeaders);
          _logResponse(response);
          await ObservabilityService.instance.stopApiTrace(
            trace,
            response.statusCode,
          );
          await ObservabilityService.instance.logApiEvent(
            method: 'GET',
            endpoint: endpoint,
            statusCode: response.statusCode,
            durationMs: stopwatch.elapsedMilliseconds,
          );
          return _parseResponse(response, parser);
        }

        final effectiveTimeout = timeout ?? defaultTimeout;
        if (!retryOnNetworkError) {
          return await requestFn().timeout(effectiveTimeout);
        }

        return await NetworkInterceptor.instance.withRetry(
          requestFn,
          timeout: effectiveTimeout,
        );
      });
      return result;
    } on AppException {
      rethrow;
    } catch (e) {
      throw ApiErrorHandler.handle(e);
    } finally {
      stopwatch.stop();
    }
  }

  Future<Uint8List> getBytes(
    String endpointOrUrl, {
    bool requiresAuth = true,
    bool retryOnNetworkError = true,
    Duration? timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    final url = endpointOrUrl.startsWith('http')
        ? endpointOrUrl
        : '$baseUrl$endpointOrUrl';

    if (AppGlobals.isDesignMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return Uint8List(0);
    }

    final trace = ObservabilityService.instance.startApiTrace('GET', url);
    try {
      final uri = Uri.parse(url);
      Future<Uint8List> fetch() async {
        Future<Uint8List> requestFn() async {
          // Never send the token to another host, even if a caller passes one.
          final currentHeaders = ApiConstants.isServerUrl(url)
              ? await _headers()
              : <String, String>{};
          _logRequest('GET (Bytes)', url, currentHeaders, null);
          final response = await http.get(uri, headers: currentHeaders);
          _logResponse(response);
          await ObservabilityService.instance.stopApiTrace(
            trace,
            response.statusCode,
          );
          await ObservabilityService.instance.logApiEvent(
            method: 'GET',
            endpoint: endpointOrUrl,
            statusCode: response.statusCode,
            durationMs: stopwatch.elapsedMilliseconds,
          );
          if (response.statusCode < 200 || response.statusCode > 299) {
            throw ApiErrorHandler.handleResponse(response);
          }
          return response.bodyBytes;
        }

        final effectiveTimeout = timeout ?? defaultTimeout;
        if (!retryOnNetworkError) {
          return await requestFn().timeout(effectiveTimeout);
        }

        return await NetworkInterceptor.instance.withRetry(
          requestFn,
          timeout: effectiveTimeout,
        );
      }

      if (requiresAuth) {
        return await _withTokenRefresh(endpointOrUrl, fetch);
      } else {
        return await fetch();
      }
    } on AppException {
      rethrow;
    } catch (e) {
      throw ApiErrorHandler.handle(e);
    } finally {
      stopwatch.stop();
    }
  }

  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Object? body,
    required T Function(Object? json) parser,
    bool retryOnNetworkError = true,
    bool isSubmission = false,
    Duration? timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    final url = '$baseUrl$endpoint';

    if (AppGlobals.isDesignMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      final mockJson = MockApiData.getMockResponse('POST', endpoint);
      final response = http.Response.bytes(
        utf8.encode(jsonEncode(mockJson)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
      return _parseResponse(response, parser);
    }

    final trace = ObservabilityService.instance.startApiTrace('POST', url);
    try {
      final uri = Uri.parse(url);
      final bodyStr = jsonEncode(body ?? <String, dynamic>{});

      final result = await _withTokenRefresh(endpoint, () async {
        Future<ApiResponse<T>> requestFn() async {
          final currentHeaders = await _headers();
          _logRequest('POST', url, currentHeaders, body);
          final response = await http.post(
            uri,
            headers: currentHeaders,
            body: bodyStr,
          );
          _logResponse(response);
          await ObservabilityService.instance.stopApiTrace(
            trace,
            response.statusCode,
          );
          await ObservabilityService.instance.logApiEvent(
            method: 'POST',
            endpoint: endpoint,
            statusCode: response.statusCode,
            durationMs: stopwatch.elapsedMilliseconds,
          );
          return _parseResponse(response, parser);
        }

        final effectiveTimeout = timeout ?? defaultTimeout;
        if (!retryOnNetworkError ||
            endpoint.contains(ApiConstants.realtimeTicket) ||
            endpoint.contains(ApiConstants.deviceToken)) {
          return await requestFn().timeout(effectiveTimeout);
        }

        return await NetworkInterceptor.instance.withRetry(
          requestFn,
          timeout: effectiveTimeout,
          isSubmission: isSubmission,
        );
      });
      return result;
    } on AppException {
      rethrow;
    } catch (e) {
      throw ApiErrorHandler.handle(e);
    } finally {
      stopwatch.stop();
    }
  }

  Future<ApiResponse<T>> postMultipart<T>(
    String endpoint, {
    required Map<String, String> fields,
    required List<http.MultipartFile> files,
    required T Function(Object? json) parser,
    String? contentType,
    bool retryOnNetworkError = true,
    bool isSubmission = false,
    Duration? timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    final url = '$baseUrl$endpoint';

    if (AppGlobals.isDesignMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      final mockJson = MockApiData.getMockResponse('POST', endpoint);
      final response = http.Response.bytes(
        utf8.encode(jsonEncode(mockJson)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
      return _parseResponse(response, parser);
    }

    final trace = ObservabilityService.instance.startApiTrace('POST', url);
    try {
      final uri = Uri.parse(url);

      final result = await _withTokenRefresh(endpoint, () async {
        Future<ApiResponse<T>> requestFn() async {
          final currentHeaders = await _headers(contentType: contentType);
          _logRequest('POST (Multipart)', url, currentHeaders, fields, files);

          var request = http.MultipartRequest('POST', uri);
          request.headers.addAll(currentHeaders);
          request.fields.addAll(fields);
          request.files.addAll(files);

          final streamedResponse = await request.send();
          final response = await http.Response.fromStream(streamedResponse);

          _logResponse(response);
          await ObservabilityService.instance.stopApiTrace(
            trace,
            response.statusCode,
          );
          await ObservabilityService.instance.logApiEvent(
            method: 'POST',
            endpoint: endpoint,
            statusCode: response.statusCode,
            durationMs: stopwatch.elapsedMilliseconds,
          );
          return _parseResponse(response, parser);
        }

        final effectiveTimeout = timeout ?? defaultMultipartTimeout;
        if (!retryOnNetworkError) {
          return await requestFn().timeout(effectiveTimeout);
        }

        return await NetworkInterceptor.instance.withRetry(
          requestFn,
          timeout: effectiveTimeout,
          isSubmission: isSubmission,
        );
      });
      return result;
    } on AppException {
      rethrow;
    } catch (e) {
      throw ApiErrorHandler.handle(e);
    } finally {
      stopwatch.stop();
    }
  }

  Future<ApiResponse<T>> patchMultipart<T>(
    String endpoint, {
    required Map<String, String> fields,
    required List<http.MultipartFile> files,
    required T Function(Object? json) parser,
    String? contentType,
    bool retryOnNetworkError = true,
    bool isSubmission = false,
    Duration? timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    final url = '$baseUrl$endpoint';

    if (AppGlobals.isDesignMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      final mockJson = MockApiData.getMockResponse('PATCH', endpoint);
      final response = http.Response.bytes(
        utf8.encode(jsonEncode(mockJson)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
      return _parseResponse(response, parser);
    }

    final trace = ObservabilityService.instance.startApiTrace('PATCH', url);
    try {
      final uri = Uri.parse(url);

      final result = await _withTokenRefresh(endpoint, () async {
        Future<ApiResponse<T>> requestFn() async {
          final currentHeaders = await _headers(contentType: contentType);
          _logRequest('PATCH (Multipart)', url, currentHeaders, fields, files);

          var request = http.MultipartRequest('PATCH', uri);
          request.headers.addAll(currentHeaders);
          request.fields.addAll(fields);
          request.files.addAll(files);

          final streamedResponse = await request.send();
          final response = await http.Response.fromStream(streamedResponse);

          _logResponse(response);
          await ObservabilityService.instance.stopApiTrace(
            trace,
            response.statusCode,
          );
          await ObservabilityService.instance.logApiEvent(
            method: 'PATCH',
            endpoint: endpoint,
            statusCode: response.statusCode,
            durationMs: stopwatch.elapsedMilliseconds,
          );
          return _parseResponse(response, parser);
        }

        final effectiveTimeout = timeout ?? defaultMultipartTimeout;
        if (!retryOnNetworkError) {
          return await requestFn().timeout(effectiveTimeout);
        }

        return await NetworkInterceptor.instance.withRetry(
          requestFn,
          timeout: effectiveTimeout,
          isSubmission: isSubmission,
        );
      });
      return result;
    } on AppException {
      rethrow;
    } catch (e) {
      throw ApiErrorHandler.handle(e);
    } finally {
      stopwatch.stop();
    }
  }

  Future<ApiResponse<T>> patch<T>(
    String endpoint, {
    Object? body,
    required T Function(Object? json) parser,
    bool retryOnNetworkError = true,
    bool isSubmission = false,
    Duration? timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    final url = '$baseUrl$endpoint';

    if (AppGlobals.isDesignMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      final mockJson = MockApiData.getMockResponse('PATCH', endpoint);
      final response = http.Response.bytes(
        utf8.encode(jsonEncode(mockJson)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
      return _parseResponse(response, parser);
    }

    final trace = ObservabilityService.instance.startApiTrace('PATCH', url);
    try {
      final uri = Uri.parse(url);
      final bodyStr = jsonEncode(body ?? <String, dynamic>{});

      final result = await _withTokenRefresh(endpoint, () async {
        Future<ApiResponse<T>> requestFn() async {
          final currentHeaders = await _headers();
          _logRequest('PATCH', url, currentHeaders, body);
          final response = await http.patch(
            uri,
            headers: currentHeaders,
            body: bodyStr,
          );
          _logResponse(response);
          await ObservabilityService.instance.stopApiTrace(
            trace,
            response.statusCode,
          );
          await ObservabilityService.instance.logApiEvent(
            method: 'PATCH',
            endpoint: endpoint,
            statusCode: response.statusCode,
            durationMs: stopwatch.elapsedMilliseconds,
          );
          return _parseResponse(response, parser);
        }

        final effectiveTimeout = timeout ?? defaultTimeout;
        if (!retryOnNetworkError) {
          return await requestFn().timeout(effectiveTimeout);
        }

        return await NetworkInterceptor.instance.withRetry(
          requestFn,
          timeout: effectiveTimeout,
          isSubmission: isSubmission,
        );
      });
      return result;
    } on AppException {
      rethrow;
    } catch (e) {
      throw ApiErrorHandler.handle(e);
    } finally {
      stopwatch.stop();
    }
  }

  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    required T Function(Object? json) parser,
    bool retryOnNetworkError = true,
    Duration? timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    final url = '$baseUrl$endpoint';

    if (AppGlobals.isDesignMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      final mockJson = MockApiData.getMockResponse('DELETE', endpoint);
      final response = http.Response.bytes(
        utf8.encode(jsonEncode(mockJson)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
      return _parseResponse(response, parser);
    }

    final trace = ObservabilityService.instance.startApiTrace('DELETE', url);
    try {
      final uri = Uri.parse(url);
      final result = await _withTokenRefresh(endpoint, () async {
        Future<ApiResponse<T>> requestFn() async {
          final currentHeaders = await _headers();
          _logRequest('DELETE', url, currentHeaders, null);
          final response = await http.delete(uri, headers: currentHeaders);
          _logResponse(response);
          await ObservabilityService.instance.stopApiTrace(
            trace,
            response.statusCode,
          );
          await ObservabilityService.instance.logApiEvent(
            method: 'DELETE',
            endpoint: endpoint,
            statusCode: response.statusCode,
            durationMs: stopwatch.elapsedMilliseconds,
          );
          return _parseResponse(response, parser);
        }

        final effectiveTimeout = timeout ?? defaultTimeout;
        if (!retryOnNetworkError) {
          return await requestFn().timeout(effectiveTimeout);
        }

        return await NetworkInterceptor.instance.withRetry(
          requestFn,
          timeout: effectiveTimeout,
        );
      });
      return result;
    } on AppException {
      rethrow;
    } catch (e) {
      throw ApiErrorHandler.handle(e);
    } finally {
      stopwatch.stop();
    }
  }

  Future<bool>? _refreshTokenFuture;

  /// A 401 here is a credential verdict (wrong password, dead refresh token), so never refresh-and-retry.
  static const Set<String> _credentialEndpoints = {
    ApiConstants.login,
    ApiConstants.refresh,
  };

  /// Wraps an API request logic block to intercept 401s, attempt a single refresh,
  /// and retry the EXACT request if successful. If unauthorized persists, triggers `onUnauthenticated`.
  Future<T> _withTokenRefresh<T>(
    String endpoint,
    Future<T> Function() request,
  ) async {
    try {
      return await request();
    } on UnauthorizedException {
      // 0. A 401 from an auth endpoint is the real answer; pass it through so the caller shows
      //    "Invalid credentials" instead of a refresh failure.
      if (_credentialEndpoints.contains(endpoint)) {
        rethrow;
      }

      // 1. If we don't have a configured refresh mechanism, just fail & logout
      if (onRefreshToken == null) {
        await onUnauthenticated?.call();
        return await Completer<T>().future;
      }

      // 2. Single token refresh flow:
      //    Deduplicate concurrent 401 refresh calls by reusing an in-flight refresh Future.
      final refreshTask = _refreshTokenFuture ??=
          () async {
            final success = await onRefreshToken!();
            if (!success) {
              await onUnauthenticated?.call();
            }
            return success;
          }().whenComplete(() {
            _refreshTokenFuture = null;
          });

      final refreshSuccess = await refreshTask;

      if (refreshSuccess) {
        try {
          // 3. Tokens were swapped! Retry the exact request block with new credentials.
          return await request();
        } on UnauthorizedException {
          // 4. If we STILL get a 401 after the refresh, the session is dead.
          await onUnauthenticated?.call();
          return await Completer<T>().future;
        }
      } else {
        // 5. The refresh API returned false. Session dead.
        return await Completer<T>().future;
      }
    }
  }

  Future<Map<String, String>> _headers({
    String? contentType = 'application/json',
  }) async {
    final savedBearer = await tokenStorage.readBearerToken();
    final savedSession = await tokenStorage.readSessionId();
    final bearerToken = savedBearer ?? ApiConstants.defaultBearerToken;
    final sessionValue = mobileSessionValue(savedSession);

    return {
      if (contentType != null && contentType.isNotEmpty)
        'Content-Type': contentType,
      if (bearerToken.isNotEmpty) 'Authorization': 'Bearer $bearerToken',
      // Company-session selector: the backend scopes this device's company by it (default company if absent).
      if (sessionValue.isNotEmpty) 'X-Mobile-Session': sessionValue,
      // Language only. The API authenticates by Bearer token and needs no
      // Odoo session cookie.
      'Cookie': _languageCookie,
    };
  }

  ApiResponse<T> _parseResponse<T>(
    http.Response response,
    T Function(Object? json) parser,
  ) {
    final decodedBody = _safeDecode(response.body);
    final decodedMap = decodedBody is Map<String, dynamic> ? decodedBody : null;

    if (response.statusCode < 200 || response.statusCode > 299) {
      throw ApiErrorHandler.handleResponse(response);
    }

    if (response.body.trim().isEmpty) {
      return ApiResponse<T>(
        success: true,
        message: 'Success',
        data: parser(null),
      );
    }

    if (decodedMap != null) {
      Map<String, dynamic> target = decodedMap;

      // If it's a JSON-RPC response, the actual ApiResponse fields are inside 'result'
      if (decodedMap.containsKey('result') &&
          decodedMap['result'] is Map<String, dynamic>) {
        target = decodedMap['result'] as Map<String, dynamic>;
      }

      if (target.containsKey('success') ||
          target.containsKey('message') ||
          target.containsKey('data')) {
        if (target.containsKey('success') && target['success'] == false) {
          throw ApiErrorHandler.handleResponse(response);
        }
        return ApiResponse<T>.fromJson(target, parser);
      }
    }

    return ApiResponse<T>(
      success: true,
      message: 'Success',
      data: parser(decodedBody),
    );
  }

  static const String _languageCookie = 'frontend_lang=en_US';

  Object? _safeDecode(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  void _logRequest(
    String method,
    String url,
    Map<String, String> headers,
    Object? body, [
    List<http.MultipartFile>? files,
  ]) {
    if (kReleaseMode) return;
    log('🚀 [API Request] $method $url');
    log('Headers: $headers');
    if (body != null) {
      log('Payload: ${jsonEncode(body)}');
    }
    if (files != null && files.isNotEmpty) {
      final fileSummary = files
          .map(
            (f) =>
                '${f.filename ?? f.field} (${(f.length / 1024).toStringAsFixed(1)} KB)',
          )
          .join(', ');
      log('Files (${files.length}): [$fileSummary]');
    }
  }

  void _logResponse(http.Response response) {
    if (kReleaseMode) return;
    log('✅ [API Response] ${response.statusCode} ${response.request?.url}');
    log('Body: ${response.body}');
  }
}
