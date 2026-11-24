import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import 'app_document_shimmer.dart';

class AppTextViewer extends StatefulWidget {
  final String? path;
  final Uint8List? bytes;
  final String? title;
  final bool isJson;

  const AppTextViewer({
    super.key,
    this.path,
    this.bytes,
    this.title,
    this.isJson = false,
  });

  static Future<void> show(
    BuildContext context, {
    String? path,
    Uint8List? bytes,
    String? title,
    bool isJson = false,
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
        return AppTextViewer(
          path: path,
          bytes: bytes,
          title: title,
          isJson: isJson,
        );
      },
    );
  }

  @override
  State<AppTextViewer> createState() => _AppTextViewerState();
}

class _AppTextViewerState extends State<AppTextViewer> {
  bool _isLoading = true;
  String? _content;
  String? _errorMessage;

  static Uint8List? _extractBase64Bytes(dynamic payload) {
    if (payload == null) return null;
    String? base64Str;
    if (payload is Map) {
      if (payload['base64'] is String) {
        base64Str = payload['base64'];
      } else if (payload['content'] is String) {
        base64Str = payload['content'];
      } else if (payload['preview'] is String) {
        base64Str = payload['preview'];
      } else if (payload['data'] != null) {
        if (payload['data'] is String) {
          base64Str = payload['data'];
        } else if (payload['data'] is Map) {
          final inner = payload['data'] as Map;
          if (inner['base64'] is String) {
            base64Str = inner['base64'];
          } else if (inner['content'] is String) {
            base64Str = inner['content'];
          } else if (inner['preview'] is String) {
            base64Str = inner['preview'];
          }
        }
      }
    } else if (payload is String) {
      base64Str = payload;
    }

    if (base64Str != null && base64Str.isNotEmpty) {
      try {
        String clean = base64Str.trim();
        if (clean.contains(',')) {
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
    return null;
  }

  Uint8List _tryExtractBase64FromBytes(Uint8List inputBytes) {
    try {
      final maybeJson = utf8.decode(inputBytes, allowMalformed: true);
      if (_looksLikeJson(maybeJson)) {
        final dynamic decoded = jsonDecode(maybeJson);
        final extracted = _extractBase64Bytes(decoded);
        if (extracted != null && extracted.isNotEmpty) {
          return extracted;
        }
      }
    } on FormatException {
      // Input is not JSON; proceed with raw input bytes
      return inputBytes;
    } catch (e) {
      debugPrint('AppTextViewer: Failed to decode base64 from bytes: $e');
    }
    return inputBytes;
  }

  String _tryFormatJson(String raw) {
    if (widget.isJson || _looksLikeJson(raw)) {
      try {
        final dynamic decoded = jsonDecode(raw);
        return const JsonEncoder.withIndent('  ').convert(decoded);
      } on FormatException {
        // Fallback: retain raw text if json formatting fails
        return raw;
      } catch (e) {
        debugPrint('AppTextViewer: Failed to format JSON: $e');
      }
    }
    return raw;
  }

  @override
  void initState() {
    super.initState();
    if (widget.bytes != null && widget.bytes!.isNotEmpty) {
      try {
        final bytes = _tryExtractBase64FromBytes(widget.bytes!);
        final rawText = utf8.decode(bytes, allowMalformed: true);
        _content = _tryFormatJson(rawText);
        _isLoading = false;
        return;
      } catch (e) {
        debugPrint('AppTextViewer: Sync byte load failed, falling back to async loader: $e');
      }
    } else if (widget.path != null &&
        !widget.path!.startsWith('http://') &&
        !widget.path!.startsWith('https://')) {
      try {
        final file = File(widget.path!);
        if (file.existsSync()) {
          final rawText = file.readAsStringSync();
          _content = _tryFormatJson(rawText);
          _isLoading = false;
          return;
        }
      } catch (e) {
        debugPrint('AppTextViewer: Sync file read failed, falling back to async loader: $e');
      }
    }
    _loadTextContent();
  }

  Future<void> _loadTextContent() async {
    try {
      String rawText = '';
      if (widget.bytes != null && widget.bytes!.isNotEmpty) {
        final bytes = _tryExtractBase64FromBytes(widget.bytes!);
        rawText = utf8.decode(bytes, allowMalformed: true);
      } else if (widget.path != null) {
        final path = widget.path!;
        if (path.startsWith('http://') || path.startsWith('https://')) {
          final isApiUrl = ApiConstants.isServerUrl(path);
          Uint8List bodyBytes;
          if (isApiUrl && GetIt.instance.isRegistered<ApiClient>()) {
            bodyBytes = await GetIt.instance<ApiClient>().getBytes(path);
          } else {
            final headers = await ApiClient.getMediaHeaders(path);
            final res = await http
                .get(Uri.parse(path), headers: headers)
                .timeout(const Duration(seconds: 30));
            if (res.statusCode == 200) {
              bodyBytes = res.bodyBytes;
            } else {
              throw Exception('Failed to download file: HTTP ${res.statusCode}');
            }
          }
          final bodyStr = utf8.decode(bodyBytes, allowMalformed: true);
            if (_looksLikeJson(bodyStr)) {
              try {
                final dynamic decoded = jsonDecode(bodyStr);
                final extracted = _extractBase64Bytes(decoded);
                if (extracted != null && extracted.isNotEmpty) {
                  rawText = utf8.decode(extracted, allowMalformed: true);
                } else {
                  rawText = bodyStr;
                }
              } on FormatException {
                rawText = bodyStr;
              } catch (e) {
                debugPrint('AppTextViewer: Failed to parse body JSON: $e');
                rawText = bodyStr;
              }
            } else {
              rawText = bodyStr;
            }
        } else {
          final file = File(path);
          if (await file.exists()) {
            rawText = await file.readAsString();
          } else {
            throw Exception('File not found');
          }
        }
      } else {
        throw Exception('No file source provided');
      }

      rawText = _tryFormatJson(rawText);

      if (mounted) {
        setState(() {
          _content = rawText;
          _isLoading = false;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _errorMessage = 'Connection timed out. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  bool _looksLikeJson(String text) {
    final trimmed = text.trim();
    return (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'));
  }

  Future<void> _openExternal() async {
    if (widget.path == null) return;
    final path = widget.path!;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      final uri = Uri.parse(path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      await OpenFilex.open(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.light,
      body: SafeArea(
        child: Stack(
          children: [
            // Content or Error State
            Positioned.fill(
              child: _isLoading
                  ? const AppDocumentShimmer()
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32.w),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 64.r,
                                  color: isDark
                                      ? Colors.white60
                                      : AppColors.navColor,
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  'Unable to open file',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color:
                                        isDark ? Colors.white : AppColors.black,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (widget.path != null) ...[
                                  SizedBox(height: 20.h),
                                  OutlinedButton.icon(
                                    onPressed: _openExternal,
                                    icon: Icon(
                                      Icons.open_in_new_rounded,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.black,
                                      size: 18.r,
                                    ),
                                    label: Text(
                                      'Open externally',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.black,
                                        fontSize: 14.sp,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: isDark
                                            ? Colors.white38
                                            : AppColors.shade,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8.r),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : Container(
                          width: double.infinity,
                          height: double.infinity,
                          margin: EdgeInsets.fromLTRB(12.r, 64.h, 12.r, 12.r),
                          padding: EdgeInsets.all(14.r),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : AppColors.white,
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : AppColors.midLight,
                            ),
                          ),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: SelectableText(
                                _content ?? '',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13.sp,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : AppColors.black,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
            ),

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
          ],
        ),
      ),
    );
  }
}
