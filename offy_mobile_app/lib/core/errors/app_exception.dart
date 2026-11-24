class AppException implements Exception {
  const AppException(this.message, {this.statusCode});
  final String? message;
  final int? statusCode;

  @override
  String toString() {
    return message ?? 'An unknown error occurred';
  }
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message]) : super(statusCode: 401);
}

class ServerException extends AppException {
  const ServerException([super.message]) : super(statusCode: 500);
}

class NetworkException extends AppException {
  const NetworkException([super.message]) : super(statusCode: null);
}

/// A sent submission lost its reply, so the server may or may not have saved it.
/// Same message as a plain cancel; providers catch it to run `LostSubmissionChecker`.
class SubmissionOutcomeUnknownException extends AppException {
  const SubmissionOutcomeUnknownException() : super('Request cancelled.');
}
