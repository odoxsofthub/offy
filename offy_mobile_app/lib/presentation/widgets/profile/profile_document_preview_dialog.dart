import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../core/theme/app_colors.dart';
import '../../viewmodels/profile/profile_provider.dart';
import '../common/cached_image.dart';
import '../../../../l10n/app_localizations.dart';

class ProfileDocumentPreviewDialog extends StatefulWidget {
  final int? documentId;
  final String title;
  final String? imageUrl;
  final String? filename;
  final String? mimetype;

  const ProfileDocumentPreviewDialog({
    super.key,
    this.documentId,
    required this.title,
    this.imageUrl,
    this.filename,
    this.mimetype,
  });

  @override
  State<ProfileDocumentPreviewDialog> createState() =>
      _ProfileDocumentPreviewDialogState();
}

class _ProfileDocumentPreviewDialogState
    extends State<ProfileDocumentPreviewDialog> {
  bool _isLoading = false;
  String? _error;
  Uint8List? _bytes;
  String? _textContent;
  bool _pdfFailed = false;

  /// PDF detection from mimetype/extension rather than by attempting an image decode.
  bool get _looksLikePdf {
    if ((widget.mimetype ?? '').toLowerCase().contains('pdf')) return true;
    return (widget.filename ?? widget.title).toLowerCase().endsWith('.pdf');
  }

  @override
  void initState() {
    super.initState();
    if (widget.documentId != null) {
      _fetchDocumentData();
    }
  }

  Future<void> _fetchDocumentData() async {
    if (widget.documentId == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      ProfileProvider provider;
      try {
        provider = context.read<ProfileProvider>();
      } catch (_) {
        provider = GetIt.instance<ProfileProvider>();
      }
      dynamic data;
      if (widget.documentId == ProfileProvider.idCardDocumentId) {
        await provider.fetchIdCardPayload();
        data = provider.getDocPayload(widget.documentId!);
      } else {
        data = await provider.downloadDocument(widget.documentId!);
      }

      String? base64Str;
      String? contentType = widget.mimetype;
      String? filename = widget.filename;

      if (data is Uint8List) {
        _bytes = data;
      } else if (data is List<int>) {
        _bytes = Uint8List.fromList(data);
      } else if (data is Map<String, dynamic>) {
        if (data['base64'] is String) {
          base64Str = data['base64'];
        } else if (data['content'] is String) {
          base64Str = data['content'];
        } else if (data['data'] != null) {
          if (data['data'] is String) {
            base64Str = data['data'];
          } else if (data['data'] is Map<String, dynamic>) {
            final inner = data['data'] as Map<String, dynamic>;
            if (inner['base64'] is String) {
              base64Str = inner['base64'];
            } else if (inner['content'] is String) {
              base64Str = inner['content'];
            }
            if (inner['content_type'] is String) {
              contentType = inner['content_type'];
            }
            if (inner['filename'] is String) {
              filename = inner['filename'];
            }
          }
        }

        if (data['content_type'] is String) {
          contentType = data['content_type'];
        }
        if (data['filename'] is String) {
          filename = data['filename'];
        }
      } else if (data is String) {
        base64Str = data;
      }

      if (base64Str != null && base64Str.isNotEmpty) {
        try {
          String cleanBase64 = base64Str.trim();
          if (cleanBase64.contains(',')) {
            cleanBase64 = cleanBase64.split(',').last;
          }
          cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');
          while (cleanBase64.length % 4 != 0) {
            cleanBase64 += '=';
          }

          final decoded = base64Decode(cleanBase64);
          final mime = (contentType ?? widget.mimetype ?? '').toLowerCase();
          final fname = (filename ?? widget.filename ?? '').toLowerCase();

          final isTextOrJson =
              mime.contains('json') ||
              mime.contains('text') ||
              fname.endsWith('.json') ||
              fname.endsWith('.txt') ||
              fname.endsWith('.csv') ||
              fname.endsWith('.md');

          if (isTextOrJson) {
            final text = utf8.decode(decoded, allowMalformed: true);
            try {
              final parsedJson = jsonDecode(text);
              const encoder = JsonEncoder.withIndent('  ');
              _textContent = encoder.convert(parsedJson);
            } catch (_) {
              _textContent = text;
            }
          } else {
            _bytes = decoded;
          }
        } catch (_) {
          _textContent = base64Str;
        }
      } else if (mounted) {
        _error =
            AppLocalizations.of(context)?.noDocumentContent ??
            'No document content available';
      }
    } catch (e) {
      if (mounted) {
        _error =
            '${AppLocalizations.of(context)?.failedToDownloadPreview ?? 'Failed to download document preview: '}$e';
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    final fname = widget.filename ?? widget.title;
    final ext = fname.contains('.')
        ? fname.split('.').last.toUpperCase()
        : (widget.mimetype?.contains('pdf') == true
            ? 'PDF'
            : widget.mimetype?.contains('image') == true
                ? 'IMG'
                : 'DOC');

    return Dialog(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 16.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          width: double.infinity,
          height: screenHeight * 0.80,
          color: isDark ? AppColors.darkBg : AppColors.white,
          child: Column(
            children: [
              // Dialog Header Row
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.white : AppColors.black,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (ext.isNotEmpty) ...[
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: AppColors.main.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                ext,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.main,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 24.r,
                        color: isDark ? AppColors.white : AppColors.black,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Interactive Document Preview Area
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(8.w),
                  child: Center(child: _buildPreviewBody(isDark)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewBody(bool isDark) {
    if (_isLoading) {
      return Shimmer.fromColors(
        baseColor: AppColors.shimmerBase(isDark),
        highlightColor: AppColors.shimmerHighlight(isDark),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      );
    }

    if (_error != null &&
        (_bytes == null &&
            _textContent == null &&
            (widget.imageUrl ?? '').isEmpty)) {
      return Center(
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.sp,
            color: isDark
                ? AppColors.white.withValues(alpha: 0.6)
                : AppColors.tertiary,
          ),
        ),
      );
    }

    if (_bytes != null) {
      if (_looksLikePdf && !_pdfFailed) {
        return SfPdfViewerTheme(
          data: SfPdfViewerThemeData(
            backgroundColor: Colors.transparent,
            progressBarColor: AppColors.main,
          ),
          child: SfPdfViewer.memory(
            _bytes!,
            canShowScrollHead: false,
            canShowScrollStatus: false,
            onDocumentLoadFailed: (_) {
              // Corrupt or password-protected: show the message below rather
              // than a blank pane -- and never the raw bytes.
              if (mounted) setState(() => _pdfFailed = true);
            },
          ),
        );
      }
      if (_pdfFailed) {
        return Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Text(
              AppLocalizations.of(context)?.failedToLoadDocumentPreview ??
                  'Failed to load document preview.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: isDark
                    ? AppColors.white.withValues(alpha: 0.6)
                    : AppColors.tertiary,
              ),
            ),
          ),
        );
      }
      return InteractiveViewer(
        minScale: 0.8,
        maxScale: 4.0,
        child: Image.memory(
          _bytes!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Center(
            child: Text(
              AppLocalizations.of(context)?.failedToLoadDocumentPreview ??
                  'Failed to load document preview.',
              style: TextStyle(
                fontSize: 14.sp,
                color: isDark
                    ? AppColors.white.withValues(alpha: 0.6)
                    : AppColors.tertiary,
              ),
            ),
          ),
        ),
      );
    }

    if (_textContent != null) {
      return _buildTextPreview(isDark, _textContent!);
    }

    if (_looksLikePdf &&
        !_pdfFailed &&
        (widget.imageUrl ?? '').isNotEmpty &&
        (widget.imageUrl ?? '').startsWith('http')) {
      return SfPdfViewerTheme(
        data: SfPdfViewerThemeData(
          backgroundColor: Colors.transparent,
          progressBarColor: AppColors.main,
        ),
        child: SfPdfViewer.network(
          widget.imageUrl!,
          canShowScrollHead: false,
          canShowScrollStatus: false,
          onDocumentLoadFailed: (_) {
            if (mounted) setState(() => _pdfFailed = true);
          },
        ),
      );
    }

    if ((widget.imageUrl ?? '').isNotEmpty) {
      return InteractiveViewer(
        minScale: 0.8,
        maxScale: 4.0,
        child: CachedImage(
          imageUrl: widget.imageUrl,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
          errorWidget: Center(
            child: Text(
              AppLocalizations.of(context)?.failedToLoadDocumentPreview ??
                  'Failed to load document preview.',
              style: TextStyle(
                fontSize: 14.sp,
                color: isDark
                    ? AppColors.white.withValues(alpha: 0.6)
                    : AppColors.tertiary,
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Text(
        AppLocalizations.of(context)?.noPreviewAvailable ??
            'No preview available.',
        style: TextStyle(
          fontSize: 14.sp,
          color: isDark
              ? AppColors.white.withValues(alpha: 0.6)
              : AppColors.tertiary,
        ),
      ),
    );
  }

  Widget _buildTextPreview(bool isDark, String text) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: SelectableText(
          text,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13.sp,
            color: isDark ? AppColors.white : AppColors.black,
          ),
        ),
      ),
    );
  }
}
