import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/document_payload_utils.dart';
import 'app_document_shimmer.dart';

class AppPdfViewer extends StatefulWidget {
  final String? path;
  final Uint8List? bytes;
  final Map<String, String>? headers;

  const AppPdfViewer({super.key, this.path, this.bytes, this.headers});

  static bool _isLocalFile(String? path) {
    if (path == null || path.isEmpty) return false;
    if (path.startsWith('http://') || path.startsWith('https://')) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  static Future<void> show(
    BuildContext context, {
    String? path,
    Uint8List? bytes,
  }) {
    final isLocal = _isLocalFile(path);
    final resolvedPath =
        (!isLocal && path != null && path.startsWith('/') && !path.startsWith('//'))
            ? '${ApiConstants.baseUrl}$path'
            : path;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showGeneralDialog(
      context: context,
      barrierColor: isDark
          ? Colors.black.withValues(alpha: 0.85)
          : Colors.black.withValues(alpha: 0.4),
      barrierDismissible: false,
      pageBuilder: (context, animation, secondaryAnimation) {
        return AppPdfViewer(path: resolvedPath, bytes: bytes);
      },
    );
  }

  @override
  State<AppPdfViewer> createState() => _AppPdfViewerState();
}

class _AppPdfViewerState extends State<AppPdfViewer> {
  bool _hasError = false;
  bool _isLoaded = false;
  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      if (widget.bytes != null && widget.bytes!.isNotEmpty) {
        final cleanBytes = DocumentPayloadUtils.extractBytes(widget.bytes!) ?? widget.bytes!;
        if (mounted) {
          setState(() {
            _pdfBytes = cleanBytes;
          });
        }
        return;
      }

      var path = widget.path;
      if (path == null || path.isEmpty) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoaded = true;
          });
        }
        return;
      }

      // Handle raw Base64 string or Data URI directly
      if (DocumentPayloadUtils.isDataUri(path) || DocumentPayloadUtils.isBase64(path)) {
        final cleanBytes = DocumentPayloadUtils.extractBytes(path);
        if (cleanBytes != null && mounted) {
          setState(() {
            _pdfBytes = cleanBytes;
          });
          return;
        }
      }

      final isLocal = AppPdfViewer._isLocalFile(path);
      if (!isLocal && path.startsWith('/') && !path.startsWith('//')) {
        path = '${ApiConstants.baseUrl}$path';
      }

      if (!isLocal && (path.startsWith('http://') || path.startsWith('https://'))) {
        final isApiUrl = ApiConstants.isServerUrl(path);
        Uint8List rawBytes;
        if (isApiUrl && GetIt.instance.isRegistered<ApiClient>()) {
          rawBytes = await GetIt.instance<ApiClient>().getBytes(path);
        } else {
          Map<String, String>? headers = widget.headers;
          if (headers == null || headers.isEmpty) {
            headers = await ApiClient.getMediaHeaders(path);
          }
          final res = await http
              .get(Uri.parse(path), headers: headers)
              .timeout(const Duration(seconds: 30));
          if (res.statusCode == 200) {
            rawBytes = res.bodyBytes;
          } else {
            throw Exception('Failed to load PDF');
          }
        }
        final cleanBytes =
            DocumentPayloadUtils.extractBytes(rawBytes) ?? rawBytes;
        if (mounted) {
          setState(() {
            _pdfBytes = cleanBytes;
          });
        }
      } else {
        final file = File(path);
        if (await file.exists()) {
          final rawBytes = await file.readAsBytes();
          final cleanBytes = DocumentPayloadUtils.extractBytes(rawBytes) ?? rawBytes;
          if (mounted) {
            setState(() {
              _pdfBytes = cleanBytes;
            });
          }
        } else {
          throw Exception('File not found');
        }
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('AppPdfViewer: Failed to load PDF from ${widget.path}: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoaded = true;
        });
      }
    }
  }

  void _onLoadFailed(PdfDocumentLoadFailedDetails details) {
    if (mounted) {
      setState(() {
        _hasError = true;
        _isLoaded = true;
      });
    }
  }

  void _onLoaded(PdfDocumentLoadedDetails details) {
    if (mounted) {
      setState(() {
        _isLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNotFound = _pdfBytes == null && widget.path == null && widget.bytes == null;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.light,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _hasError || isNotFound
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 56.r,
                              color: isDark ? Colors.white70 : AppColors.navColor,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              isNotFound ? 'File not found' : 'Unable to open file',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.black,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _pdfBytes != null
                      ? SfPdfViewerTheme(
                          data: SfPdfViewerThemeData(
                            backgroundColor: Colors.transparent,
                            progressBarColor: AppColors.main,
                          ),
                          child: SfPdfViewer.memory(
                            _pdfBytes!,
                            pageLayoutMode: PdfPageLayoutMode.continuous,
                            canShowScrollHead: true,
                            canShowScrollStatus: true,
                            onDocumentLoaded: _onLoaded,
                            onDocumentLoadFailed: _onLoadFailed,
                          ),
                        )
                      : const SizedBox.shrink(),
            ),
            if (!_isLoaded && !_hasError && !isNotFound)
              const Positioned.fill(
                child: AppDocumentShimmer(),
              ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 24.r,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
