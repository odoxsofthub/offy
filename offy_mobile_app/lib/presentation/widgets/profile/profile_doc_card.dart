import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/document_payload_utils.dart';
import '../common/cached_image.dart';

class ProfileDocCard extends StatefulWidget {
  final String label;
  final String imageUrl;
  final String? filename;
  final String? mimetype;
  final String? kind;
  final int? fileSize;
  final dynamic docPayload;
  final bool isLoadingPayload;
  final VoidCallback? onTap;

  final BoxFit fit;

  const ProfileDocCard({
    super.key,
    required this.label,
    required this.imageUrl,
    this.filename,
    this.mimetype,
    this.kind,
    this.fileSize,
    this.docPayload,
    this.isLoadingPayload = false,
    this.onTap,
    this.fit = BoxFit.cover,
  });

  @override
  State<ProfileDocCard> createState() => _ProfileDocCardState();
}

class _ProfileDocCardState extends State<ProfileDocCard> {
  Future<Map<String, String>>? _mediaHeadersFuture;
  String? _lastHeadersUrl;

  @override
  void initState() {
    super.initState();
    _initHeadersFuture();
  }

  @override
  void didUpdateWidget(ProfileDocCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _initHeadersFuture();
    }
  }

  String _getResolvedUrl(String url) {
    if (url.startsWith('/')) {
      return '${ApiConstants.baseUrl}$url';
    }
    return url;
  }

  void _initHeadersFuture() {
    final resolvedUrl = _getResolvedUrl(widget.imageUrl);
    if (resolvedUrl.isNotEmpty && resolvedUrl.startsWith('http')) {
      _lastHeadersUrl = resolvedUrl;
      _mediaHeadersFuture = ApiClient.getMediaHeaders(resolvedUrl);
    } else {
      _mediaHeadersFuture = null;
    }
  }

  bool _isDirectImageUrl(String url) {
    if (url.isEmpty) return false;
    final lowerKind = (widget.kind ?? '').toLowerCase();
    if (lowerKind == 'image' ||
        lowerKind == 'img' ||
        lowerKind.startsWith('image/')) {
      return true;
    }
    final lower = url.toLowerCase();
    if (widget.mimetype != null && widget.mimetype!.toLowerCase().contains('image')) {
      return true;
    }
    if (lower.contains('/download')) {
      return false;
    }
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.contains('/avatar') ||
        lower.contains('/employees/') ||
        lower.contains('company') ||
        lower.startsWith('http');
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Uint8List? _extractBytesFromPayload() {
    return DocumentPayloadUtils.extractBytes(widget.docPayload);
  }

  bool _isPdfBytes(Uint8List bytes) {
    return DocumentPayloadUtils.isPdfBytes(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final resolvedUrl = _getResolvedUrl(widget.imageUrl);
    final isImage = _isDirectImageUrl(resolvedUrl);
    final decodedBytes = _extractBytesFromPayload();

    final displayFilename =
        widget.filename ??
        (resolvedUrl.isNotEmpty && !resolvedUrl.contains('/download')
            ? resolvedUrl.split('/').last
            : widget.label);
    String ext = displayFilename.contains('.')
        ? displayFilename.split('.').last.toUpperCase()
        : '';
    if (ext.isEmpty || ext.length > 5) {
      if (decodedBytes != null) {
        if (_isPdfBytes(decodedBytes)) {
          ext = 'PDF';
        } else if (DocumentPayloadUtils.isBinaryImageBytes(decodedBytes)) {
          ext = 'IMG';
        }
      }
      if (ext.isEmpty || ext.length > 5) {
        if (_isPdf('')) {
          ext = 'PDF';
        } else if (isImage) {
          ext = 'IMG';
        } else {
          ext = 'FILE';
        }
      }
    }
    final formattedSize = _formatFileSize(widget.fileSize);

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkCard.withValues(alpha: 0.3)
              : AppColors.light.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                height: 18 / 14,
                color: isDark ? AppColors.white : AppColors.black,
              ),
            ),
            SizedBox(height: 11.h),
            Container(
              height: 99.h,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6.r),
                child: _buildCardBody(
                  isDark,
                  resolvedUrl,
                  isImage,
                  decodedBytes,
                  displayFilename,
                  ext,
                  formattedSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBody(
    bool isDark,
    String resolvedUrl,
    bool isImage,
    Uint8List? decodedBytes,
    String displayFilename,
    String ext,
    String formattedSize,
  ) {
    if (widget.isLoadingPayload && decodedBytes == null) {
      return Shimmer.fromColors(
        baseColor: AppColors.shimmerBase(isDark),
        highlightColor: AppColors.shimmerHighlight(isDark),
        child: Container(
          width: double.infinity,
          height: 99.h,
          color: Colors.white,
        ),
      );
    }

    if (decodedBytes != null) {
      if (_isPdfBytes(decodedBytes)) {
        return _buildPdfPreview(decodedBytes);
      }
      return Image.memory(
        decodedBytes,
        height: 99.h,
        width: double.infinity,
        fit: widget.fit,
        alignment: Alignment.topCenter,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _buildDocumentThumbnail(
          isDark,
          displayFilename,
          ext,
          formattedSize,
        ),
      );
    }

    if (_isPdf(ext) &&
        resolvedUrl.isNotEmpty &&
        resolvedUrl.startsWith('http')) {
      return _buildNetworkPdfPreview(resolvedUrl, isDark);
    }

    if (isImage && resolvedUrl.isNotEmpty) {
      return CachedImage(
        imageUrl: resolvedUrl,
        height: 99.h,
        width: double.infinity,
        fit: widget.fit,
        errorWidget: _buildDocumentThumbnail(
          isDark,
          displayFilename,
          ext,
          formattedSize,
        ),
      );
    }

    return _buildDocumentThumbnail(isDark, displayFilename, ext, formattedSize);
  }

  bool _isPdf(String ext) {
    final lowerKind = (widget.kind ?? '').toLowerCase();
    return ext == 'PDF' ||
        lowerKind == 'pdf' ||
        lowerKind == 'application/pdf' ||
        (widget.mimetype ?? '').toLowerCase().contains('pdf') ||
        widget.label.toLowerCase().endsWith('.pdf') ||
        (widget.filename ?? '').toLowerCase().endsWith('.pdf');
  }

  /// PDF card preview: laid out large and scaled to cover (like BoxFit.cover) so it crops instead of
  /// letterboxing and stays sharp. IgnorePointer lets taps reach the card.
  Widget _buildPdfPreview(Uint8List bytes) {
    return IgnorePointer(
      child: SfPdfViewerTheme(
        data: SfPdfViewerThemeData(
          backgroundColor: Colors.transparent,
          progressBarColor: Colors.transparent,
        ),
        child: SfPdfViewer.memory(
          bytes,
          enableTextSelection: false,
          enableDocumentLinkAnnotation: false,
          canShowScrollHead: false,
          canShowScrollStatus: false,
          onDocumentLoadFailed: (_) {},
        ),
      ),
    );
  }

  Widget _buildNetworkPdfPreview(String url, bool isDark) {
    if (_mediaHeadersFuture == null || _lastHeadersUrl != url) {
      _lastHeadersUrl = url;
      _mediaHeadersFuture = ApiClient.getMediaHeaders(url);
    }
    return FutureBuilder<Map<String, String>>(
      future: _mediaHeadersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Shimmer.fromColors(
            baseColor: AppColors.shimmerBase(isDark),
            highlightColor: AppColors.shimmerHighlight(isDark),
            child: Container(
              width: double.infinity,
              height: 99.h,
              color: Colors.white,
            ),
          );
        }
        final headers = snapshot.data;
        return IgnorePointer(
          child: SfPdfViewerTheme(
            data: SfPdfViewerThemeData(
              backgroundColor: Colors.transparent,
              progressBarColor: Colors.transparent,
            ),
            child: SfPdfViewer.network(
              url,
              headers: (headers != null && headers.isNotEmpty) ? headers : null,
              enableTextSelection: false,
              enableDocumentLinkAnnotation: false,
              canShowScrollHead: false,
              canShowScrollStatus: false,
              onDocumentLoadFailed: (_) {},
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocumentThumbnail(
    bool isDark,
    String displayFilename,
    String ext,
    String formattedSize,
  ) {
    return Container(
      width: double.infinity,
      height: 99.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1E293B), Color(0xFF0F172A)]
              : const [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Document canvas paper representation with text lines
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120.w,
                    height: 6.h,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    width: 180.w,
                    height: 6.h,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.09)
                          : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    width: 90.w,
                    height: 6.h,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    width: 140.w,
                    height: 6.h,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Subtle document icon emblem
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.main.withValues(alpha: 0.15)
                  : AppColors.main.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              ext == 'JSON' || ext == 'TXT'
                  ? Icons.code_rounded
                  : ext == 'PDF'
                  ? Icons.picture_as_pdf_rounded
                  : Icons.insert_drive_file_rounded,
              color: AppColors.main,
              size: 24.r,
            ),
          ),
        ],
      ),
    );
  }
}
