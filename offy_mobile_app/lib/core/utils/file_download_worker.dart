import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

/// Background worker for downloading files and processing document payloads
/// completely off the main UI isolate.
class FileDownloadWorker {
  const FileDownloadWorker._();

  /// A server- or user-supplied [name] as a single file name (path separators
  /// become `_`), so it cannot point outside the target folder.
  static String safeFileName(String? name, String fallback) {
    final cleaned = (name ?? '')
        .replaceAll(RegExp(r'[/\\]'), '_')
        .replaceAll(RegExp(r'[\x00-\x1F]'), '')
        .trim();
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') return fallback;
    return cleaned;
  }

  /// Writes [bytes], a Base64/data-URI [base64Payload] or a streamed [url] to disk in a background isolate.
  static Future<File> prepareFileInIsolate({
    required String targetPath,
    String? url,
    Uint8List? bytes,
    String? base64Payload,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    return await Isolate.run(() async {
      final file = File(targetPath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (e, stackTrace) {
          developer.log(
            'Failed to delete existing file at $targetPath: $e',
            name: 'FileDownloadWorker',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      // Ensure parent directory exists
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }

      // 1. If raw binary bytes provided
      if (bytes != null && bytes.isNotEmpty) {
        final cleanBytes = _extractCleanBytes(bytes);
        await file.writeAsBytes(cleanBytes, flush: true);
        return file;
      }

      // 2. If Base64 string payload provided
      if (base64Payload != null && base64Payload.isNotEmpty) {
        final cleanBytes = _extractCleanBytes(base64Payload);
        await file.writeAsBytes(cleanBytes, flush: true);
        return file;
      }

      // 3. If remote URL provided: stream directly to disk without buffering full payload in RAM
      if (url != null && url.isNotEmpty) {
        final client = HttpClient();
        try {
          final uri = Uri.parse(url);
          final request = await client.getUrl(uri).timeout(timeout);

          headers?.forEach((key, value) {
            request.headers.set(key, value);
          });

          final response = await request.close().timeout(timeout);

          if (response.statusCode != 200) {
            throw HttpException(
              'Failed to download file (HTTP ${response.statusCode})',
              uri: uri,
            );
          }

          final contentType =
              response.headers.contentType?.mimeType.toLowerCase() ?? '';
          final isJsonOrText =
              contentType.contains('json') ||
              contentType.contains('text') ||
              contentType.contains('javascript');

          if (isJsonOrText) {
            // Buffer text/json payload in isolate memory to extract base64 or raw body
            final bodyBytes = await response
                .fold<List<int>>([], (prev, elem) => prev..addAll(elem))
                .timeout(timeout);
            final cleanBytes = _extractCleanBytes(
              Uint8List.fromList(bodyBytes),
            );
            await file.writeAsBytes(cleanBytes, flush: true);
          } else {
            // Pure binary stream directly to file via IOSink (minimal memory footprint)
            final sink = file.openWrite();
            try {
              await response.pipe(sink).timeout(timeout);
            } finally {
              await sink.flush();
              await sink.close();
            }
          }

          return file;
        } finally {
          client.close(force: true);
        }
      }

      throw ArgumentError(
        'No valid file source (bytes, base64Payload, or url) provided.',
      );
    });
  }

  /// Self-contained extractor running safely in a pure Dart isolate without
  /// Flutter or platform channel dependencies.
  static Uint8List _extractCleanBytes(dynamic input) {
    if (input == null) return Uint8List(0);

    if (input is Uint8List) {
      if (_isKnownBinary(input)) {
        return input;
      }
      try {
        final str = utf8.decode(input, allowMalformed: true).trim();
        if (str.startsWith('{') ||
            str.startsWith('[') ||
            _isDataUri(str) ||
            _looksLikeBase64(str)) {
          final decoded = _extractCleanBytes(str);
          if (decoded.isNotEmpty) return decoded;
        }
      } catch (e, stackTrace) {
        developer.log(
          'Failed to decode UTF-8 payload candidate: $e',
          name: 'FileDownloadWorker',
          error: e,
          stackTrace: stackTrace,
        );
      }
      return input;
    }

    if (input is List<int>) {
      return _extractCleanBytes(Uint8List.fromList(input));
    }

    if (input is Map) {
      if (input['success'] == false) return Uint8List(0);
      for (final key in const [
        'base64',
        'content',
        'preview',
        'data',
        'file',
        'payload',
        'bytes',
      ]) {
        if (input[key] != null) {
          final res = _extractCleanBytes(input[key]);
          if (res.isNotEmpty) return res;
        }
      }
      return Uint8List(0);
    }

    if (input is String) {
      final trimmed = input.trim();
      if (trimmed.isEmpty) return Uint8List(0);

      // JSON string check
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          final dynamic parsed = jsonDecode(trimmed);
          return _extractCleanBytes(parsed);
        } catch (e, stackTrace) {
          developer.log(
            'Failed to parse JSON document payload string: $e',
            name: 'FileDownloadWorker',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      // Base64 check
      if (_isDataUri(trimmed) || _looksLikeBase64(trimmed)) {
        final decoded = _decodeBase64String(trimmed);
        if (decoded != null && decoded.isNotEmpty) return decoded;
      }

      // Check if local file path
      try {
        final f = File(trimmed);
        if (f.existsSync()) {
          return _extractCleanBytes(f.readAsBytesSync());
        }
      } catch (e, stackTrace) {
        developer.log(
          'Failed to read local document file bytes at "$trimmed": $e',
          name: 'FileDownloadWorker',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    return Uint8List(0);
  }

  static bool _isKnownBinary(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // %PDF
    if (bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      return true;
    }
    // JPEG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return true;
    }
    // PNG
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    // GIF
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      return true;
    }
    // WebP (RIFF....WEBP)
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    return false;
  }

  static bool _isDataUri(String str) {
    final s = str.trim();
    return s.startsWith('data:') && s.contains(';base64,');
  }

  static bool _looksLikeBase64(String str) {
    final s = str.trim();
    if (s.length < 16) return false;
    if (_isDataUri(s)) return true;
    if (s.startsWith('http://') ||
        s.startsWith('https://') ||
        s.startsWith('file://')) {
      return false;
    }
    if (s.startsWith('/') && !s.startsWith('/9j/')) {
      return false;
    }
    final clean = s.replaceAll(RegExp(r'\s+'), '');
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
}
