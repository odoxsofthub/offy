import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/file_download_worker.dart';

class AppFallbackDocumentViewer extends StatefulWidget {
  final String? path;
  final Uint8List? bytes;
  final String? title;

  const AppFallbackDocumentViewer({
    super.key,
    this.path,
    this.bytes,
    this.title,
  });

  static Future<void> show(
    BuildContext context, {
    String? path,
    Uint8List? bytes,
    String? title,
  }) async {
    if (!context.mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showGeneralDialog(
      context: context,
      barrierColor: isDark
          ? Colors.black.withValues(alpha: 0.85)
          : Colors.black.withValues(alpha: 0.4),
      barrierDismissible: false,
      pageBuilder: (context, animation, secondaryAnimation) {
        return AppFallbackDocumentViewer(
          path: path,
          bytes: bytes,
          title: title,
        );
      },
    );
  }

  @override
  State<AppFallbackDocumentViewer> createState() =>
      _AppFallbackDocumentViewerState();
}

class _AppFallbackDocumentViewerState extends State<AppFallbackDocumentViewer> {
  bool _isOpening = false;
  String? _statusMessage;

  String _getFileExtension() {
    if (widget.title != null && widget.title!.contains('.')) {
      final ext = widget.title!.split('.').last.split('?').first.toUpperCase();
      if (ext.length <= 5) return ext;
    }
    if (widget.path != null && widget.path!.contains('.')) {
      final ext = widget.path!.split('.').last.split('?').first.toUpperCase();
      if (ext.length <= 5 && !ext.contains('/')) return ext;
    }
    return 'FILE';
  }

  Future<void> _handleOpenExternal() async {
    setState(() {
      _isOpening = true;
      _statusMessage = null;
    });

    try {
      final path = widget.path;

      // 1. If path is an already existing local file on disk, open directly
      if (path != null && File(path).existsSync()) {
        final res = await OpenFilex.open(path);
        if (res.type != ResultType.done) {
          setState(() {
            _statusMessage = res.message.isNotEmpty
                ? res.message
                : 'No app available to open this file';
          });
        }
        return;
      }

      // 2. If it's an external web URL (not our API), open in browser
      if (path != null &&
          (path.startsWith('http://') || path.startsWith('https://')) &&
          !ApiConstants.isServerUrl(path)) {
        final uri = Uri.parse(path);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          setState(() {
            _statusMessage = 'Could not open URL in browser';
          });
        }
        return;
      }

      // 3. Prepare target file destination on main isolate
      final tempDir = await getTemporaryDirectory();
      final ext = _getFileExtension().toLowerCase();
      var fileName = FileDownloadWorker.safeFileName(
        widget.title,
        'document_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      if (ext != 'file' && !fileName.toLowerCase().endsWith('.$ext')) {
        fileName = '$fileName.$ext';
      }
      final targetFilePath = '${tempDir.path}/$fileName';

      // 4. Resolve auth headers on main isolate if authenticated API URL
      Map<String, String>? headers;
      Uint8List? fileBytes = widget.bytes;
      final isApiUrl = path != null && ApiConstants.isServerUrl(path);
      if (fileBytes == null && isApiUrl && GetIt.instance.isRegistered<ApiClient>()) {
        fileBytes = await GetIt.instance<ApiClient>().getBytes(path);
      } else if (path != null && isApiUrl) {
        headers = await ApiClient.getMediaHeaders(path);
      }

      // 5. Offload heavy download, Base64/JSON decoding, and disk write to background isolate
      final readyFile = await FileDownloadWorker.prepareFileInIsolate(
        targetPath: targetFilePath,
        url: fileBytes != null ? null : path,
        bytes: fileBytes,
        headers: headers,
      );

      // 6. Main UI isolate opens the file with the native OS
      final res = await OpenFilex.open(readyFile.path);
      if (res.type != ResultType.done) {
        setState(() {
          _statusMessage = res.message.isNotEmpty
              ? res.message
              : 'No app available to open this file';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Unable to open file: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isOpening = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleText = widget.title ??
        (widget.path != null
            ? widget.path!.split('/').last.split('?').first
            : 'Document');
    final ext = _getFileExtension();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.light,
      body: SafeArea(
        child: Stack(
          children: [
            // Top Left Close Button
            Positioned(
              top: 16.r,
              left: 16.r,
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
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),

            // Center Info & Action Card
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Document Icon Card
                    Container(
                      width: 90.r,
                      height: 90.r,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : AppColors.midLight,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.insert_drive_file_rounded,
                            size: 50.r,
                            color: isDark ? Colors.white70 : AppColors.navColor,
                          ),
                          Positioned(
                            bottom: 10.h,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.main,
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                ext,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // File Name
                    Text(
                      titleText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.black,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8.h),

                    // Subtitle
                    Text(
                      'This file cannot be previewed directly in the app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white60 : AppColors.navColor,
                        fontSize: 13.sp,
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // Open Externally Button
                    ElevatedButton.icon(
                      onPressed: _isOpening ? null : _handleOpenExternal,
                      icon: _isOpening
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.open_in_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                      label: Text(
                        _isOpening ? 'Opening...' : 'Open with external app',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.main,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24.w,
                          vertical: 12.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                    ),

                    if (_statusMessage != null) ...[
                      SizedBox(height: 14.h),
                      Text(
                        _statusMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
