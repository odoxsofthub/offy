import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/document_payload_utils.dart';

class CachedImage extends StatefulWidget {
  const CachedImage({
    super.key,
    this.radius = 6.0,
    required this.imageUrl,
    this.imageUrl2,
    this.height,
    this.width,
    this.placeholder,
    this.errorWidget,
    this.fit,
    this.userName,
    this.isProfile = false,
  });

  final double radius;
  final String? imageUrl;
  final String? imageUrl2;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double? height, width;
  final BoxFit? fit;
  final String? userName;
  final bool isProfile;

  static final Map<String, Uint8List> _memoryCache = {};
  static final Map<String, bool> _svgCache = {};
  static final Map<String, String> _cachedVersions = {};
  static final Map<String, DateTime> _failedUrls = {};
  static final Map<String, Future<Uint8List?>> _inFlightFetches = {};
  static const Duration _failureCooldown = Duration(seconds: 15);

  /// Strips query parameters (e.g., `?t=...`) to identify the avatar/resource entity.
  static String _getBaseKey(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.hasScheme) {
      return uri.replace(queryParameters: {}, fragment: '').toString();
    }
    return url.split('?').first;
  }

  static bool _isFailed(String url) {
    final failedAt = _failedUrls[url];
    if (failedAt == null) return false;
    if (DateTime.now().difference(failedAt) > _failureCooldown) {
      _failedUrls.remove(url);
      return false;
    }
    return true;
  }

  static void _recordFailure(String url) {
    _failedUrls[url] = DateTime.now();
  }

  static void _clearFailure(String url) {
    _failedUrls.remove(url);
  }

  /// Deduplicates concurrent download tasks for identical URLs.
  static Future<Uint8List?> _fetchWithDeduplication(String url, {String? token}) async {
    if (_inFlightFetches.containsKey(url)) {
      return await _inFlightFetches[url]!;
    }
    final future = _fetchBytes(url, token: token);
    _inFlightFetches[url] = future;
    try {
      return await future;
    } finally {
      _inFlightFetches.remove(url);
    }
  }

  /// Pre-caches image bytes into memory using stale-while-revalidate.
  static Future<void> precache(String? url, {String? token}) async {
    if (url == null || url.isEmpty) return;
    final baseKey = _getBaseKey(url);

    if (_memoryCache.containsKey(baseKey) && _cachedVersions[baseKey] == url) {
      return;
    }
    if (_isFailed(url)) return;

    try {
      final bytes = await _fetchWithDeduplication(url, token: token);
      if (bytes != null && bytes.isNotEmpty) {
        _memoryCache[baseKey] = bytes;
        _svgCache[baseKey] = _detectSvg(bytes, url);
        _cachedVersions[baseKey] = url;
        _clearFailure(url);
      } else {
        _recordFailure(url);
      }
    } catch (_) {
      _recordFailure(url);
    }
  }

  /// Evicts an image URL from both static memory cache and persistent disk cache.
  static Future<void> evict(String? url) async {
    if (url == null || url.isEmpty) return;
    final baseKey = _getBaseKey(url);
    _memoryCache.remove(baseKey);
    _svgCache.remove(baseKey);
    _cachedVersions.remove(baseKey);
    _failedUrls.remove(url);
    try {
      await DefaultCacheManager().removeFile(url);
    } catch (e, stackTrace) {
      developer.log(
        'Failed to remove cached file in CachedImage.evict: $e',
        error: e,
        stackTrace: stackTrace,
        name: 'CachedImage',
      );
      try {
        if (Firebase.apps.isNotEmpty) {
          FirebaseCrashlytics.instance.recordError(
            e,
            stackTrace,
            fatal: false,
          );
        }
      } catch (logErr) {
        developer.log(
          'CachedImage.evict: Unable to record to Crashlytics: $logErr',
          name: 'CachedImage',
        );
      }
    }
  }

  static Future<Uint8List?> _fetchBytes(String url, {String? token}) async {
    try {
      final isApiUrl = ApiConstants.isServerUrl(url);
      if (token == null && isApiUrl && GetIt.instance.isRegistered<ApiClient>()) {
        final rawBytes = await GetIt.instance<ApiClient>().getBytes(
          url,
          retryOnNetworkError: false,
        );
        if (rawBytes.isNotEmpty) {
          final cleanBytes =
              await DocumentPayloadUtils.extractBytesAsync(rawBytes) ?? rawBytes;
          try {
            await DefaultCacheManager().putFile(url, cleanBytes);
          } catch (e) {
            developer.log(
              'CachedImage: Failed to cache image to disk: $e',
              name: 'CachedImage',
            );
          }
          return cleanBytes.isNotEmpty ? cleanBytes : null;
        }
        return null;
      }

      final headers = {...await ApiClient.getMediaHeaders(url)};
      if (token != null && token.isNotEmpty && isApiUrl) {
        headers['Authorization'] = 'Bearer $token';
      }

      final File file = await DefaultCacheManager().getSingleFile(
        url,
        headers: headers.isNotEmpty ? headers : null,
      );
      final rawBytes = await file.readAsBytes();
      if (rawBytes.isEmpty) return null;

      // Extract & decode Base64/JSON in background isolate via extractBytesAsync
      final cleanBytes = await DocumentPayloadUtils.extractBytesAsync(rawBytes) ?? rawBytes;
      return cleanBytes.isNotEmpty ? cleanBytes : null;
    } catch (e) {
      // Gracefully handle 404, network failure, or file read error without throwing
      developer.log(
        'CachedImage: Failed to fetch image bytes from $url: $e',
        name: 'CachedImage',
      );
      return null;
    }
  }

  static bool _detectSvg(Uint8List bytes, String url) {
    if (url.toLowerCase().endsWith('.svg')) return true;
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

  /// Centralized broken image fallback widget used across image tiles and attachments.
  static Widget buildBrokenImageFallback(
    BuildContext context, {
    double? width,
    double? height,
    double radius = 0.0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxH = constraints.maxHeight != double.infinity
            ? constraints.maxHeight
            : (height ?? 40.0);
        final double maxW = constraints.maxWidth != double.infinity
            ? constraints.maxWidth
            : (width ?? 40.0);
        final double minDimension = maxH < maxW ? maxH : maxW;
        final double iconSize = (minDimension * 0.45).clamp(14.0, 36.0);

        Widget content = Container(
          color: isDark ? AppColors.darkCard : const Color(0xFFD9D9D9),
          width: width,
          height: height,
          alignment: Alignment.center,
          child: Icon(
            Icons.broken_image_rounded,
            color: isDark ? Colors.white60 : Colors.white,
            size: iconSize,
          ),
        );

        if (radius > 0) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: content,
          );
        }
        return content;
      },
    );
  }

  /// Avatar fallback: the user's initial on AppColors.main, or Icons.person; never a broken-image icon.
  static Widget buildProfileFallback(
    BuildContext context, {
    double? width,
    double? height,
    double radius = 0.0,
    String? userName,
  }) {
    final String rawName = userName?.trim() ?? '';
    final bool isValidName =
        rawName.isNotEmpty &&
        RegExp(r'[a-zA-Z0-9]').hasMatch(rawName.substring(0, 1));
    final String firstLetter = isValidName
        ? rawName.substring(0, 1).toUpperCase()
        : '';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxH = constraints.maxHeight != double.infinity
            ? constraints.maxHeight
            : (height ?? 40.0);
        final double maxW = constraints.maxWidth != double.infinity
            ? constraints.maxWidth
            : (width ?? 40.0);
        final double minDimension = maxH < maxW ? maxH : maxW;

        final Widget innerWidget;
        if (firstLetter.isNotEmpty) {
          innerWidget = Container(
            color: AppColors.main,
            width: width,
            height: height,
            alignment: Alignment.center,
            child: Center(
              child: Text(
                firstLetter,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: (minDimension * 0.45).clamp(10.0, 48.0),
                ),
              ),
            ),
          );
        } else {
          final double iconSize = (minDimension * 0.55).clamp(14.0, 48.0);
          innerWidget = Container(
            color: isDark ? AppColors.darkCard : const Color(0xFFD9D9D9),
            width: width,
            height: height,
            alignment: Alignment.center,
            child: Icon(
              Icons.person,
              color: isDark ? Colors.white70 : Colors.white,
              size: iconSize,
            ),
          );
        }

        if (radius > 0) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: innerWidget,
          );
        }
        return innerWidget;
      },
    );
  }

  @override
  State<CachedImage> createState() => _CachedImageState();
}

class _CachedImageState extends State<CachedImage> {
  late String? currentImageUrl;
  bool hasTriedSecondUrl = false;
  String? _token;

  Uint8List? _imageBytes;
  bool? _isSvg;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    currentImageUrl = widget.imageUrl;
    _initializeFromCacheOrFetch();
  }

  void _initializeFromCacheOrFetch() {
    if (currentImageUrl == null || currentImageUrl!.isEmpty) {
      _imageBytes = null;
      _isLoading = false;
      _hasError = false;
      return;
    }

    final url = currentImageUrl!;

    if (DocumentPayloadUtils.isDataUri(url) || DocumentPayloadUtils.isBase64(url)) {
      final bytes = DocumentPayloadUtils.extractBytes(url);
      _imageBytes = bytes;
      _isSvg = bytes != null ? CachedImage._detectSvg(bytes, url) : false;
      _isLoading = false;
      _hasError = bytes == null;
      return;
    }

    final baseKey = CachedImage._getBaseKey(url);

    // 1. Stale-while-revalidate: Render cached image immediately if available
    if (CachedImage._memoryCache.containsKey(baseKey)) {
      _imageBytes = CachedImage._memoryCache[baseKey];
      _isSvg = CachedImage._svgCache[baseKey] ?? false;
      _isLoading = false;
      _hasError = false;

      // If URL version changed (e.g. new ?t=...), silently update in background
      if (CachedImage._cachedVersions[baseKey] != url) {
        _revalidateInBackground(url, baseKey);
      }
      return;
    }

    // 2. Fallback check for recent failure cooldown
    if (CachedImage._isFailed(url)) {
      _imageBytes = null;
      _isLoading = false;
      _hasError = true;
      return;
    }

    // 3. Cold load without cached image
    _checkCacheAndLoad();
  }

  @override
  void didUpdateWidget(CachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.imageUrl2 != widget.imageUrl2) {
      currentImageUrl = widget.imageUrl;
      hasTriedSecondUrl = false;

      if (currentImageUrl == null || currentImageUrl!.isEmpty) {
        setState(() {
          _imageBytes = null;
          _isLoading = false;
          _hasError = false;
        });
        return;
      }

      final url = currentImageUrl!;

      if (DocumentPayloadUtils.isDataUri(url) || DocumentPayloadUtils.isBase64(url)) {
        final bytes = DocumentPayloadUtils.extractBytes(url);
        setState(() {
          _imageBytes = bytes;
          _isSvg = bytes != null ? CachedImage._detectSvg(bytes, url) : false;
          _isLoading = false;
          _hasError = bytes == null;
        });
        return;
      }

      final baseKey = CachedImage._getBaseKey(url);

      if (CachedImage._memoryCache.containsKey(baseKey)) {
        setState(() {
          _imageBytes = CachedImage._memoryCache[baseKey];
          _isSvg = CachedImage._svgCache[baseKey] ?? false;
          _isLoading = false;
          _hasError = false;
        });

        if (CachedImage._cachedVersions[baseKey] != url) {
          _revalidateInBackground(url, baseKey);
        }
      } else {
        _checkCacheAndLoad();
      }
    }
  }

  Future<void> _revalidateInBackground(String url, String baseKey) async {
    await _loadToken();
    try {
      final bytes = await CachedImage._fetchWithDeduplication(url, token: _token);
      if (bytes != null && bytes.isNotEmpty) {
        final isSvg = CachedImage._detectSvg(bytes, url);
        CachedImage._memoryCache[baseKey] = bytes;
        CachedImage._svgCache[baseKey] = isSvg;
        CachedImage._cachedVersions[baseKey] = url;
        CachedImage._clearFailure(url);

        if (mounted && currentImageUrl == url) {
          setState(() {
            _imageBytes = bytes;
            _isSvg = isSvg;
            _isLoading = false;
            _hasError = false;
          });
        }
      }
    } catch (_) {
      // Stale-while-revalidate: Preserve displaying existing image on background failure
      CachedImage._recordFailure(url);
    }
  }

  Future<void> _checkCacheAndLoad() async {
    if (currentImageUrl == null || currentImageUrl!.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = false;
          _imageBytes = null;
        });
      }
      return;
    }

    final url = currentImageUrl!;

    if (DocumentPayloadUtils.isDataUri(url) || DocumentPayloadUtils.isBase64(url)) {
      final bytes = DocumentPayloadUtils.extractBytes(url);
      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _isSvg = bytes != null ? CachedImage._detectSvg(bytes, url) : false;
          _isLoading = false;
          _hasError = bytes == null;
        });
      }
      return;
    }

    final baseKey = CachedImage._getBaseKey(url);

    if (CachedImage._isFailed(url) && !CachedImage._memoryCache.containsKey(baseKey)) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
      return;
    }

    if (CachedImage._memoryCache.containsKey(baseKey)) {
      if (mounted) {
        setState(() {
          _imageBytes = CachedImage._memoryCache[baseKey];
          _isSvg = CachedImage._svgCache[baseKey] ?? false;
          _isLoading = false;
          _hasError = false;
        });
      }
      if (CachedImage._cachedVersions[baseKey] != url) {
        _revalidateInBackground(url, baseKey);
      }
      return;
    }

    // Only show shimmer if there are no existing bytes for this avatar
    if (mounted) {
      setState(() {
        _isLoading = _imageBytes == null;
        _hasError = false;
      });
    }

    await _loadToken();
    await _fetchImageFile();
  }

  Future<void> _loadToken() async {
    if (GetIt.instance.isRegistered<TokenStorage>()) {
      try {
        final tokenStorage = GetIt.instance<TokenStorage>();
        _token = await tokenStorage.readBearerToken();
      } catch (e) {
        debugPrint('CachedImage: Failed to read bearer token: $e');
      }
    }
  }

  Future<void> _fetchImageFile() async {
    if (currentImageUrl == null || currentImageUrl!.isEmpty) return;

    final targetUrl = currentImageUrl!;
    final baseKey = CachedImage._getBaseKey(targetUrl);

    try {
      final bytes = await CachedImage._fetchWithDeduplication(targetUrl, token: _token);

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Empty image bytes');
      }

      final isSvg = CachedImage._detectSvg(bytes, targetUrl);

      // Save to static in-memory cache, replacing old version in-place
      CachedImage._memoryCache[baseKey] = bytes;
      CachedImage._svgCache[baseKey] = isSvg;
      CachedImage._cachedVersions[baseKey] = targetUrl;
      CachedImage._clearFailure(targetUrl);

      if (mounted && currentImageUrl == targetUrl) {
        setState(() {
          _imageBytes = bytes;
          _isSvg = isSvg;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      CachedImage._recordFailure(targetUrl);
      if (mounted) {
        if (!hasTriedSecondUrl &&
            widget.imageUrl2 != null &&
            widget.imageUrl2!.isNotEmpty &&
            currentImageUrl == widget.imageUrl) {
          currentImageUrl = widget.imageUrl2;
          hasTriedSecondUrl = true;
          _fetchImageFile();
        } else {
          final hasStaleBytes = CachedImage._memoryCache.containsKey(baseKey);
          setState(() {
            if (hasStaleBytes) {
              _imageBytes = CachedImage._memoryCache[baseKey];
              _isSvg = CachedImage._svgCache[baseKey] ?? false;
              _hasError = false;
            } else {
              _hasError = true;
            }
            _isLoading = false;
          });
        }
      }
    }
  }

  Widget _buildShimmerPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      highlightColor: AppColors.shimmerHighlight(isDark),
      baseColor: AppColors.shimmerBase(isDark),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.all(Radius.circular(widget.radius)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(widget.radius)),
          child: AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              color: isDark ? AppColors.darkTopCard : AppColors.midLight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackIconOrName() {
    final bool isProfileImage = widget.isProfile || widget.userName != null;

    if (isProfileImage) {
      return CachedImage.buildProfileFallback(
        context,
        width: widget.width,
        height: widget.height,
        radius: widget.radius,
        userName: widget.userName,
      );
    }

    return CachedImage.buildBrokenImageFallback(
      context,
      width: widget.width,
      height: widget.height,
      radius: widget.radius,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Empty URL fallback
    if (currentImageUrl == null || currentImageUrl!.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: Container(
          color: isDark ? AppColors.darkCard : AppColors.white,
          height: widget.height,
          width: widget.width,
          child: widget.errorWidget ?? _buildFallbackIconOrName(),
        ),
      );
    }

    // 2. Loading state (Shimmer only on first load before memory cache is set)
    if (_isLoading) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: SizedBox(
          height: widget.height,
          width: widget.width,
          child: _buildShimmerPlaceholder(),
        ),
      );
    }

    // 3. Error state
    if (_hasError || _imageBytes == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: SizedBox(
          height: widget.height,
          width: widget.width,
          child: widget.errorWidget ?? _buildFallbackIconOrName(),
        ),
      );
    }

    // 4. Render image from memory (SVG or Raster)
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: _isSvg == true
          ? SvgPicture.memory(
              _imageBytes!,
              fit: widget.fit ?? BoxFit.cover,
              height: widget.height,
              width: widget.width,
            )
          : Image.memory(
              _imageBytes!,
              fit: widget.fit ?? BoxFit.cover,
              height: widget.height,
              width: widget.width,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                return widget.errorWidget ?? _buildFallbackIconOrName();
              },
            ),
    );
  }
}
