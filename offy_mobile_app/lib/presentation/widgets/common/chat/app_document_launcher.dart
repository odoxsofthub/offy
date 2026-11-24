import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/utils/document_payload_utils.dart';
import '../../../../domain/entities/attachment_entity.dart';
import 'app_fallback_document_viewer.dart';
import 'app_image_gallery_viewer.dart';
import 'app_pdf_viewer.dart';
import 'app_text_viewer.dart';

class AppDocumentLauncher {
  static bool _isLocalFile(String? path) {
    if (path == null || path.isEmpty) return false;
    if (path.startsWith('http://') || path.startsWith('https://')) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  static void open(
    BuildContext context, {
    required String path,
    String? name,
    String? kind,
    Uint8List? bytes,
    List<AttachmentEntity>? allAttachments,
  }) {
    Uint8List? resolvedBytes = bytes;
    String? resolvedKind = kind;

    if (resolvedBytes == null &&
        (DocumentPayloadUtils.isDataUri(path) || DocumentPayloadUtils.isBase64(path))) {
      resolvedBytes = DocumentPayloadUtils.extractBytes(path);
    }

    if (resolvedBytes != null) {
      final isGenericKind = resolvedKind == null ||
          resolvedKind == 'employee_document' ||
          resolvedKind == 'certificate' ||
          resolvedKind == 'file' ||
          resolvedKind == 'other' ||
          resolvedKind == 'application/octet-stream';

      if (isGenericKind) {
        if (DocumentPayloadUtils.isPdfBytes(resolvedBytes)) {
          resolvedKind = 'pdf';
        } else if (DocumentPayloadUtils.isBinaryImageBytes(resolvedBytes)) {
          resolvedKind = 'image';
        }
      }
    }

    final isLocal = _isLocalFile(path);
    final resolvedPath = (!isLocal && path.startsWith('/') && !path.startsWith('//'))
        ? '${ApiConstants.baseUrl}$path'
        : path;

    final attachment = AttachmentEntity(
      url: resolvedPath,
      name: name,
      kind: resolvedKind,
    );

    if (attachment.isPdf) {
      AppPdfViewer.show(context, path: resolvedPath, bytes: resolvedBytes);
    } else if (attachment.isText) {
      AppTextViewer.show(
        context,
        path: resolvedPath,
        bytes: resolvedBytes,
        title: attachment.fileName,
        isJson: attachment.isJson,
      );
    } else if (attachment.isImage) {
      if (allAttachments != null && allAttachments.isNotEmpty) {
        final imageAttachments =
            allAttachments.where((a) => a.isImage).toList();
        final imgIndex = imageAttachments.indexWhere(
          (a) => a.url == path || a.url == resolvedPath,
        );
        final imagesToOpen = imageAttachments.isNotEmpty
            ? imageAttachments.map((a) {
                final isAttLocal = _isLocalFile(a.url);
                if (!isAttLocal && a.url.startsWith('/') && !a.url.startsWith('//')) {
                  return '${ApiConstants.baseUrl}${a.url}';
                }
                return a.url;
              }).toList()
            : [resolvedPath];
        AppImageGalleryViewer.show(
          context,
          images: imagesToOpen,
          initialIndex: imgIndex != -1 ? imgIndex : 0,
        );
      } else if (resolvedBytes != null && resolvedBytes.isNotEmpty) {
        AppImageGalleryViewer.show(context, images: [resolvedBytes]);
      } else {
        AppImageGalleryViewer.show(context, images: [resolvedPath]);
      }
    } else {
      AppFallbackDocumentViewer.show(
        context,
        path: resolvedPath,
        bytes: resolvedBytes,
        title: attachment.fileName,
      );
    }
  }
}
