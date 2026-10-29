import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/document_payload_utils.dart';
import '../cached_image.dart';
import 'app_document_shimmer.dart';
import 'app_zoomable_image_view.dart';

class AppImageGalleryViewer extends StatefulWidget {
  final List<dynamic> images;
  final int initialIndex;

  const AppImageGalleryViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  static void show(
    BuildContext context, {
    required List<dynamic> images,
    int initialIndex = 0,
  }) {
    if (images.isEmpty) return;
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: isDark
            ? Colors.black.withValues(alpha: 0.95)
            : Colors.black.withValues(alpha: 0.5),
        pageBuilder: (context, animation, secondaryAnimation) =>
            AppImageGalleryViewer(images: images, initialIndex: initialIndex),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<AppImageGalleryViewer> createState() => _AppImageGalleryViewerState();
}

class _AppImageGalleryViewerState extends State<AppImageGalleryViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _isSvgBytes(Uint8List bytes) {
    if (bytes.length < 4) return false;
    try {
      final prefix = utf8
          .decode(bytes.take(100).toList(), allowMalformed: true)
          .trim()
          .toLowerCase();
      return prefix.startsWith('<svg') ||
          prefix.startsWith('<?xml') ||
          prefix.contains('<svg');
    } catch (_) {
      return false;
    }
  }

  bool _isSvgPath(String path) {
    return path.split('?').first.toLowerCase().endsWith('.svg');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isDark ? Colors.black : AppColors.light,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : AppColors.light,
        body: SafeArea(
          child: Stack(
            children: [
              // Swipable Full Screen Image PageView
              PageView.builder(
                controller: _pageController,
                physics: _isZoomed
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                itemCount: widget.images.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                    _isZoomed = false;
                  });
                },
                itemBuilder: (context, index) {
                  final item = widget.images[index];
                  final isBytes = item is Uint8List;
                  final isLocal =
                      !isBytes && item is String && File(item).existsSync();
                  String? resolvedUrl;
                  if (!isBytes && item is String) {
                    if (item.startsWith('http://') ||
                        item.startsWith('https://')) {
                      resolvedUrl = item;
                    } else if (item.startsWith('/') && !isLocal) {
                      resolvedUrl = '${ApiConstants.baseUrl}$item';
                    }
                  }
                  final isUrl = resolvedUrl != null;

                  Widget imageWidget;
                  if (isBytes) {
                    final cleanBytes =
                        DocumentPayloadUtils.extractBytes(item) ?? item;
                    final isSvg =
                        _isSvgBytes(cleanBytes) ||
                        DocumentPayloadUtils.isSvgBytes(cleanBytes);
                    if (isSvg) {
                      imageWidget = SvgPicture.memory(
                        cleanBytes,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      );
                    } else {
                      imageWidget = Image.memory(
                        cleanBytes,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildImageErrorWidget(context);
                        },
                      );
                    }
                  } else if (isLocal) {
                    final isSvg = _isSvgPath(item);
                    if (isSvg) {
                      imageWidget = SvgPicture.file(
                        File(item),
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      );
                    } else {
                      Uint8List? cleanBytes;
                      try {
                        final fileBytes = File(item).readAsBytesSync();
                        cleanBytes = DocumentPayloadUtils.extractBytes(
                          fileBytes,
                        );
                      } catch (e, stackTrace) {
                        developer.log(
                          'Failed to read local file bytes in AppImageGalleryViewer: $e',
                          error: e,
                          stackTrace: stackTrace,
                          name: 'AppImageGalleryViewer',
                        );
                        if (Firebase.apps.isNotEmpty) {
                          FirebaseCrashlytics.instance.recordError(
                            e,
                            stackTrace,
                            fatal: false,
                          );
                        }
                      }

                      if (cleanBytes != null) {
                        imageWidget = Image.memory(
                          cleanBytes,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildImageErrorWidget(context);
                          },
                        );
                      } else {
                        imageWidget = Image.file(
                          File(item),
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildImageErrorWidget(context);
                          },
                        );
                      }
                    }
                  } else if (item is String &&
                      (DocumentPayloadUtils.isDataUri(item) ||
                          DocumentPayloadUtils.isBase64(item))) {
                    final cleanBytes = DocumentPayloadUtils.extractBytes(item);
                    if (cleanBytes != null) {
                      final isSvg =
                          _isSvgBytes(cleanBytes) ||
                          DocumentPayloadUtils.isSvgBytes(cleanBytes);
                      if (isSvg) {
                        imageWidget = SvgPicture.memory(
                          cleanBytes,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        );
                      } else {
                        imageWidget = Image.memory(
                          cleanBytes,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildImageErrorWidget(context);
                          },
                        );
                      }
                    } else {
                      imageWidget = _buildImageErrorWidget(context);
                    }
                  } else if (isUrl) {
                    final isApiUrl = ApiConstants.isServerUrl(resolvedUrl);
                    if (isApiUrl && GetIt.instance.isRegistered<ApiClient>()) {
                      imageWidget = _ApiGalleryImageView(
                        url: resolvedUrl,
                        errorWidget: _buildImageErrorWidget(context),
                      );
                    } else {
                      imageWidget = CachedImage(
                        imageUrl: resolvedUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        placeholder: const AppDocumentShimmer(isImage: true),
                        errorWidget: _buildImageErrorWidget(context),
                      );
                    }
                  } else {
                    imageWidget = _buildImageErrorWidget(context);
                  }

                  return AppZoomableImageView(
                    onZoomChanged: (zoomed) {
                      if (_isZoomed != zoomed && mounted) {
                        setState(() {
                          _isZoomed = zoomed;
                        });
                      }
                    },
                    child: imageWidget,
                  );
                },
              ),

              // Top Bar Header with Close Button and Page Counter
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.35),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
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
                          Text(
                            'Image ${_currentIndex + 1} of ${widget.images.length}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 48.w), // Balance close button spacing
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageErrorWidget(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(24.r),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_rounded,
            size: 64.r,
            color: isDark ? AppColors.white : AppColors.navColor,
          ),
          SizedBox(height: 12.h),
          Text(
            'Unable to open file',
            style: TextStyle(
              color: isDark ? AppColors.white : AppColors.black,
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiGalleryImageView extends StatefulWidget {
  final String url;
  final Widget errorWidget;

  const _ApiGalleryImageView({
    required this.url,
    required this.errorWidget,
  });

  @override
  State<_ApiGalleryImageView> createState() => _ApiGalleryImageViewState();
}

class _ApiGalleryImageViewState extends State<_ApiGalleryImageView> {
  Uint8List? _bytes;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant _ApiGalleryImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final rawBytes = await GetIt.instance<ApiClient>().getBytes(widget.url);
      final cleanBytes =
          DocumentPayloadUtils.extractBytes(rawBytes) ?? rawBytes;
      if (mounted) {
        setState(() {
          _bytes = cleanBytes;
          _isLoading = false;
          _hasError = cleanBytes.isEmpty;
        });
      }
    } catch (e) {
      debugPrint(
        '_ApiGalleryImageView: Failed to load image from ${widget.url}: $e',
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppDocumentShimmer(isImage: true);
    }
    if (_hasError || _bytes == null) {
      return widget.errorWidget;
    }
    final isSvg = DocumentPayloadUtils.isSvgBytes(_bytes!);
    if (isSvg) {
      return SvgPicture.memory(
        _bytes!,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return Image.memory(
      _bytes!,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) => widget.errorWidget,
    );
  }
}
