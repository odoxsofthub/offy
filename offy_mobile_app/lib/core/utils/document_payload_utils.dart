import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Validates, extracts and decodes document/image payloads (bytes, data URIs, Base64, JSON, files).
class DocumentPayloadUtils {
  const DocumentPayloadUtils._();

  /// Magic bytes check for PDF documents ('%PDF' header).
  static bool isPdfBytes(Uint8List bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x25 && // '%'
        bytes[1] == 0x50 && // 'P'
        bytes[2] == 0x44 && // 'D'
        bytes[3] == 0x46;   // 'F'
  }

  /// Magic bytes check for JPEG images.
  static bool isJpegBytes(Uint8List bytes) {
    return bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
  }

  /// Magic bytes check for PNG images.
  static bool isPngBytes(Uint8List bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
  }

  /// Magic bytes check for GIF images.
  static bool isGifBytes(Uint8List bytes) {
    return bytes.length >= 3 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46;
  }

  /// Magic bytes check for WebP images ('RIFF' ... 'WEBP').
  static bool isWebpBytes(Uint8List bytes) {
    return bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 && // 'RIFF'
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;  // 'WEBP'
  }

  /// Magic text check for SVG markup.
  static bool isSvgBytes(Uint8List bytes) {
    if (bytes.length < 4) return false;
    try {
      final prefix = utf8
          .decode(bytes.take(150).toList(), allowMalformed: true)
          .trim()
          .toLowerCase();
      return prefix.startsWith('<svg') ||
          prefix.startsWith('<?xml') ||
          prefix.contains('<svg');
    } catch (_) {
      return false;
    }
  }

  /// Checks if bytes represent a known binary image format (JPEG, PNG, GIF, WebP, SVG).
  static bool isBinaryImageBytes(Uint8List bytes) {
    return isJpegBytes(bytes) ||
        isPngBytes(bytes) ||
        isGifBytes(bytes) ||
        isWebpBytes(bytes) ||
        isSvgBytes(bytes);
  }

  /// Checks if string is a Data URI (e.g., `data:image/png;base64,...`).
  static bool isDataUri(String str) {
    final trimmed = str.trim();
    return trimmed.startsWith('data:') && trimmed.contains(';base64,');
  }

  /// Checks if string is a Base64-encoded payload.
  static bool isBase64(String str) {
    final trimmed = str.trim();
    if (trimmed.length < 16) return false;
    if (isDataUri(trimmed)) return true;
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('file://')) {
      return false;
    }
    // Filter out common relative or absolute URL/file paths unless it is a JPEG base64 payload (/9j/)
    if (trimmed.startsWith('/') && !trimmed.startsWith('/9j/')) {
      return false;
    }
    final clean = trimmed.replaceAll(RegExp(r'\s+'), '');
    return RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(clean);
  }

  static Uint8List? _decodeBase64String(String base64Str) {
    try {
      var clean = base64Str.trim();
      if (clean.contains(';base64,')) {
        clean = clean.split(';base64,').last;
      } else if (clean.contains(',')) {
        clean = clean.split(',').last;
      }
      clean = clean.replaceAll(RegExp(r'\s+'), '');
      while (clean.length % 4 != 0) {
        clean += '=';
      }
      final decoded = base64Decode(clean);
      return decoded.isNotEmpty ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Recursively extracts raw bytes from bytes, a JSON map or string, a data URI, Base64 or a local file path.
  static Uint8List? extractBytes(dynamic input) {
    if (input == null) return null;

    if (input is Uint8List) {
      // If it's already a recognized binary format, return immediately
      if (isPdfBytes(input) || isBinaryImageBytes(input)) {
        return input;
      }
      // Check if it's UTF-8 encoded text (JSON, Data URI, or Base64)
      try {
        final str = utf8.decode(input, allowMalformed: true).trim();
        if (str.startsWith('{') || str.startsWith('[') || isDataUri(str) || isBase64(str)) {
          final decoded = extractBytes(str);
          if (decoded != null && decoded.isNotEmpty) {
            return decoded;
          }
          if (str.startsWith('{') || str.startsWith('[')) {
            return null;
          }
        }
      } catch (e, stackTrace) {
        developer.log(
          'Failed to decode UTF-8 payload: $e',
          error: e,
          stackTrace: stackTrace,
          name: 'DocumentPayloadUtils',
        );
        _safeRecordCrashlyticsError(e, stackTrace);
      }
      return input;
    }

    if (input is List<int>) {
      return extractBytes(Uint8List.fromList(input));
    }

    if (input is Map) {
      if (input['success'] == false) return null;
      if (input['base64'] != null) return extractBytes(input['base64']);
      if (input['content'] != null) return extractBytes(input['content']);
      if (input['preview'] != null) return extractBytes(input['preview']);
      if (input['data'] != null) return extractBytes(input['data']);
      if (input['file'] != null) return extractBytes(input['file']);
      if (input['payload'] != null) return extractBytes(input['payload']);
      if (input['bytes'] != null) return extractBytes(input['bytes']);
      return null;
    }

    if (input is String) {
      final trimmed = input.trim();
      if (trimmed.isEmpty) return null;

      // Check if it's a JSON string
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          final dynamic parsedJson = jsonDecode(trimmed);
          return extractBytes(parsedJson);
        } catch (e, stackTrace) {
          developer.log(
            'Failed to parse JSON document payload: $e',
            error: e,
            stackTrace: stackTrace,
            name: 'DocumentPayloadUtils',
          );
          _safeRecordCrashlyticsError(e, stackTrace);
        }
      }

      // Check Data URI or Base64 string
      if (isDataUri(trimmed) || isBase64(trimmed)) {
        return _decodeBase64String(trimmed);
      }

      // Check if it's an existing local file
      try {
        final file = File(trimmed);
        if (file.existsSync()) {
          final fileBytes = file.readAsBytesSync();
          return extractBytes(fileBytes);
        }
      } catch (e, stackTrace) {
        developer.log(
          'Failed to read local document file bytes: $e',
          error: e,
          stackTrace: stackTrace,
          name: 'DocumentPayloadUtils',
        );
        _safeRecordCrashlyticsError(e, stackTrace);
      }
    }

    return null;
  }

  /// Async [extractBytes]: binary input returns at once; heavy JSON/Base64 decoding runs in [Isolate.run].
  static Future<Uint8List?> extractBytesAsync(dynamic input) async {
    if (input == null) return null;

    if (input is Uint8List && (isPdfBytes(input) || isBinaryImageBytes(input))) {
      return input;
    }

    return await Isolate.run(() => extractBytes(input));
  }

  static void _safeRecordCrashlyticsError(Object error, StackTrace stackTrace) {
    try {
      if (Firebase.apps.isNotEmpty) {
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          fatal: false,
        );
      }
    } catch (e, stack) {
      // Ignored when running in background isolates where Firebase channels are not bound.
      developer.log(
        'DocumentPayloadUtils: Failed to record Crashlytics error: $e',
        error: e,
        stackTrace: stack,
        name: 'DocumentPayloadUtils',
      );
    }
  }
}
