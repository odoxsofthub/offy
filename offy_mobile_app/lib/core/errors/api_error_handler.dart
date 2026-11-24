import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/error_messages.dart';
import 'app_exception.dart';

class ApiErrorHandler {
  ApiErrorHandler._();

  /// Handle raw connection/network exceptions and map them to AppException/NetworkException
  static AppException handle(Object error) {
    if (error is AppException) {
      return error;
    }

    if (error is SocketException) {
      final msg = error.message.toLowerCase();
      final errorCode = error.osError?.errorCode;
      if (msg.contains('refused') ||
          msg.contains('reset') ||
          errorCode == 111 ||
          errorCode == 61 ||
          errorCode == 10061 ||
          errorCode == 1225) {
        return const NetworkException(ErrorMessages.serverUnreachable);
      }
      return const NetworkException(ErrorMessages.noInternet);
    }

    if (error is TimeoutException) {
      return const NetworkException(ErrorMessages.connectionTimeout);
    }

    if (error is http.ClientException) {
      final message = error.message.toLowerCase();
      if (message.contains('cancelled') || message.contains('abort')) {
        return const NetworkException(ErrorMessages.requestCancelled);
      }
      return const NetworkException(ErrorMessages.connectionTimeout);
    }

    return AppException(error.toString());
  }

  /// Handle HTTP status codes and API responses
  static AppException handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    final decodedBody = _safeDecode(response.body);
    final decodedMap = decodedBody is Map<String, dynamic> ? decodedBody : null;

    // 1. Prefer Backend/API response message
    final backendMessage = _extractBackendMessage(decodedMap);
    if (backendMessage != null && backendMessage.trim().isNotEmpty) {
      if (statusCode == 401) {
        return UnauthorizedException(backendMessage);
      }
      if (statusCode >= 500) {
        return ServerException(backendMessage);
      }
      return AppException(backendMessage, statusCode: statusCode);
    }

    // 2. Custom fallback message based on status code
    final fallbackMessage = _getFallbackMessageForStatus(statusCode);
    if (statusCode == 401) {
      return UnauthorizedException(fallbackMessage);
    }
    if (statusCode >= 500) {
      return ServerException(fallbackMessage);
    }
    return AppException(fallbackMessage, statusCode: statusCode);
  }

  static Object? _safeDecode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static String? _extractBackendMessage(Map<String, dynamic>? json) {
    if (json == null) return null;

    Map<String, dynamic> target = json;
    if (json.containsKey('result') && json['result'] is Map<String, dynamic>) {
      target = json['result'] as Map<String, dynamic>;
    }

    final fields = ['message', 'error', 'detail', 'msg'];
    for (final field in fields) {
      final val = target[field];
      if (val is String && val.trim().isNotEmpty) {
        return val;
      }
      if (val is Map<String, dynamic>) {
        final nestedMsg = val['message'] ?? val['data'] ?? val['detail'];
        if (nestedMsg is String && nestedMsg.trim().isNotEmpty) {
          return nestedMsg;
        }
      }
    }
    return null;
  }

  static String _getFallbackMessageForStatus(int statusCode) {
    switch (statusCode) {
      case 400:
        return ErrorMessages.badRequest;
      case 401:
        return ErrorMessages.unauthorized;
      case 403:
        return ErrorMessages.forbidden;
      case 404:
        return ErrorMessages.notFound;
      case 409:
        return ErrorMessages.conflict;
      case 422:
        return ErrorMessages.unprocessableEntity;
      case 429:
        return ErrorMessages.tooManyRequests;
      case 500:
        return ErrorMessages.internalServerError;
      case 502:
      case 503:
      case 504:
        return ErrorMessages.serviceUnavailable;
      default:
        return ErrorMessages.unknown;
    }
  }
}
