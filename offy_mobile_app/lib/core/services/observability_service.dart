import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

class ObservabilityService {
  ObservabilityService._();
  static final ObservabilityService instance = ObservabilityService._();

  final Map<String, HttpMetric> _activeMetrics = {};

  HttpMethod? _mapMethod(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return HttpMethod.Get;
      case 'POST':
        return HttpMethod.Post;
      case 'PUT':
        return HttpMethod.Put;
      case 'DELETE':
        return HttpMethod.Delete;
      case 'PATCH':
        return HttpMethod.Patch;
      default:
        return null;
    }
  }

  String startApiTrace(String method, String url) {
    final traceKey = '${DateTime.now().microsecondsSinceEpoch}_${method}_$url';
    final httpMethod = _mapMethod(method);

    if (httpMethod != null) {
      try {
        final metric = FirebasePerformance.instance.newHttpMetric(
          url,
          httpMethod,
        );
        metric
            .start()
            .then((_) {
              _activeMetrics[traceKey] = metric;
            })
            .catchError((e) {
              debugPrint('ObservabilityService: metric.start() failed: $e');
            });
      } catch (e) {
        debugPrint('ObservabilityService: metric.start() failed: $e');
        // Ignored when Firebase is not initialized (e.g., tests or background workers)
      }
    }

    return traceKey;
  }

  Future<void> stopApiTrace(String traceKey, int statusCode) async {
    final metric = _activeMetrics.remove(traceKey);
    if (metric != null) {
      try {
        metric.httpResponseCode = statusCode;
        await metric.stop();
      } catch (e) {
        debugPrint('ObservabilityService: metric.stop() failed: $e');
      }
    }
  }

  Future<void> logApiEvent({
    required String method,
    required String endpoint,
    required int statusCode,
    required int durationMs,
  }) async {
    try {
      // Sanitize trace name: alphanumeric and underscores only, max 32 characters
      final traceName =
          'api_${endpoint.replaceAll('/', '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')}';
      final sanitizedTraceName = traceName.length > 32
          ? traceName.substring(0, 32)
          : traceName;

      final trace = FirebasePerformance.instance.newTrace(sanitizedTraceName);
      await trace.start();
      trace.putAttribute('method', method);
      trace.putAttribute('statusCode', statusCode.toString());
      trace.setMetric('durationMs', durationMs);
      await trace.stop();
    } catch (e) {
      debugPrint('ObservabilityService: logApiEvent failed: $e');
    }
  }
}
