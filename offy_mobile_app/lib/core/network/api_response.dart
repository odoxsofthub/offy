class ApiResponse<T> {
  const ApiResponse({
    required this.success,
    required this.message,
    required this.data,
    this.pagination,
  });

  final bool success;
  final String message;
  final T? data;
  final Map<String, dynamic>? pagination;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json)? parser,
  ) {
    // Find the data list: `data`, `result.data` or `result`.
    final result = json['result'];
    final data = json['data'] ?? (result is Map ? (result['data'] ?? result) : result);

    // Find pagination: `pagination`, `data.pagination` or `result.pagination`.
    var paginationJson = json['pagination'];
    if (paginationJson == null && result is Map) {
      paginationJson = result['pagination'];
    }
    if (paginationJson == null && json['data'] is Map) {
      paginationJson = (json['data'] as Map)['pagination'];
    }

    return ApiResponse<T>(
      success: json['success'] as bool? ?? (result is Map ? (result['success'] as bool? ?? true) : true),
      message: json['message'] as String? ?? (result is Map ? (result['message'] as String? ?? 'Success') : 'Success'),
      data: parser == null ? data as T? : parser(data),
      pagination: paginationJson as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    'message': message,
    'data': data,
  };
}
