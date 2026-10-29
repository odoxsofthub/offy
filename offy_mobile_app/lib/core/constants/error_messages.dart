class ErrorMessages {
  ErrorMessages._();

  // HTTP Status Code Fallbacks
  static const String badRequest = 'The request could not be processed.';
  static const String unauthorized =
      'Your session has expired. Please sign in again.';
  static const String forbidden =
      "You don't have permission to perform this action.";
  static const String notFound =
      'The requested information could not be found.';
  static const String conflict =
      'This action could not be completed due to a conflict.';
  static const String unprocessableEntity =
      'Some of the provided information is invalid.';
  static const String tooManyRequests =
      'Too many requests. Please try again later.';
  static const String internalServerError =
      'Something went wrong on our server. Please try again later.';
  static const String serviceUnavailable =
      'The service is temporarily unavailable. Please try again later.';
  static const String serverUnreachable =
      'Something went wrong. Try changing the server URL';
  static const String serverUrlNotFound =
      'Unable to connect to the server. Verify the server URL and try again.';
  static const String unknown = 'Something went wrong. Please try again.';

  // Network Errors
  static const String noInternet = 'Please check your internet connection.';
  static const String connectionTimeout =
      'Connection timed out. Please try again.';
  static const String sendTimeout = 'Request timed out.';
  static const String receiveTimeout = 'The server took too long to respond.';
  static const String requestCancelled = 'Request cancelled.';
}
