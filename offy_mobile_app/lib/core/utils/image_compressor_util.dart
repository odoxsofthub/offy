import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Centralized utility for cross-platform (Android & iOS) background image compression.
class ImageCompressorUtil {
  const ImageCompressorUtil._();

  /// Compresses a single image file via native background worker threads.
  /// If the file is not an image (e.g. PDF, docx), it returns the original file untouched.
  static Future<XFile> compressImageFile(
    XFile file, {
    int quality = 70,
    int minWidth = 1920,
    int minHeight = 1920,
  }) async {
    final path = file.path.toLowerCase();
    final isImage = path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.heic') ||
        path.endsWith('.webp');

    if (!isImage) return file;

    try {
      final tempDir = await getTemporaryDirectory();
      final nameWithoutExt = file.name.contains('.')
          ? file.name.substring(0, file.name.lastIndexOf('.'))
          : file.name;
      final targetPath =
          '${tempDir.path}/compressed_${DateTime.now().microsecondsSinceEpoch}_$nameWithoutExt.jpg';

      FlutterImageCompress.validator.ignoreCheckExtName = true;
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
        format: CompressFormat.jpeg,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Image compression timed out for: ${file.path}');
          return null;
        },
      );

      return compressedFile ?? file;
    } catch (e) {
      debugPrint('Error during image compression: $e');
      return file;
    }
  }

  /// Compresses a list of files concurrently.
  static Future<List<XFile>> compressImageList(
    List<XFile> files, {
    int quality = 70,
    int minWidth = 1920,
    int minHeight = 1920,
  }) async {
    if (files.isEmpty) return files;
    return await Future.wait(
      files.map(
        (file) => compressImageFile(
          file,
          quality: quality,
          minWidth: minWidth,
          minHeight: minHeight,
        ),
      ),
    );
  }
}
