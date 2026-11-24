import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../cached_image.dart';

/// Reusable document / attachment badge chip (Figma Frame 2609829, Group 13 & Group 14)
class AppDocumentBadgeChip extends StatelessWidget {
  final String label;
  final Color badgeColor;
  final String? imagePath;
  final String? imageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final double? width;
  final double? height;
  final double? badgeWidth;

  const AppDocumentBadgeChip({
    super.key,
    required this.label,
    required this.badgeColor,
    this.imagePath,
    this.imageUrl,
    this.onTap,
    this.onRemove,
    this.width,
    this.height,
    this.badgeWidth,
  });

  bool _isImageFile(String? path) {
    if (path == null || path.isEmpty) return false;
    final clean = path.split('?').first.toLowerCase();
    return clean.endsWith('.png') ||
        clean.endsWith('.jpg') ||
        clean.endsWith('.jpeg') ||
        clean.endsWith('.webp') ||
        clean.endsWith('.heic') ||
        clean.endsWith('.gif') ||
        clean.endsWith('.bmp') ||
        clean.endsWith('.svg');
  }

  @override
  Widget build(BuildContext context) {
    final chipWidth = width ?? 87.w;
    final chipHeight = height ?? 29.h;
    final tagWidth = badgeWidth ?? 36.w;

    final rawPath = imagePath ?? imageUrl;
    final isLocal = rawPath != null && File(rawPath).existsSync();
    final resolvedUrl = (imageUrl != null && imageUrl!.isNotEmpty)
        ? ((imageUrl!.startsWith('/') && !imageUrl!.startsWith('//'))
            ? '${ApiConstants.baseUrl}$imageUrl'
            : imageUrl)
        : ((imagePath != null && imagePath!.startsWith('/') && !isLocal)
            ? '${ApiConstants.baseUrl}$imagePath'
            : null);

    final path = isLocal ? rawPath : (resolvedUrl ?? rawPath);
    final isPdf =
        label.toUpperCase() == 'PDF' ||
        (path != null && path.toLowerCase().split('?').first.endsWith('.pdf'));

    final isImg = label.toUpperCase() == 'IMG' || _isImageFile(path);

    Widget buildFallback({bool isBrokenImage = false}) {
      final IconData iconData;
      if (isPdf) {
        iconData = Icons.picture_as_pdf_rounded;
      } else if (isBrokenImage || isImg) {
        iconData = Icons.broken_image_rounded;
      } else if (label.toUpperCase() == 'JSON') {
        iconData = Icons.data_object_rounded;
      } else if (label.toUpperCase() == 'CSV') {
        iconData = Icons.table_chart_rounded;
      } else if (label.toUpperCase() == 'TXT') {
        iconData = Icons.description_rounded;
      } else {
        iconData = Icons.insert_drive_file_rounded;
      }

      return Container(
        width: chipWidth,
        height: chipHeight,
        color: const Color(0xFFD9D9D9),
        alignment: Alignment.center,
        child: Icon(iconData, color: Colors.white, size: 16.r),
      );
    }

    Widget bgContent;
    if (imagePath != null && isLocal && _isImageFile(imagePath)) {
      bgContent = Image.file(
        File(imagePath!),
        width: chipWidth,
        height: chipHeight,
        cacheWidth: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            buildFallback(isBrokenImage: true),
      );
    } else if (resolvedUrl != null &&
        resolvedUrl.startsWith('http') &&
        (isImg || _isImageFile(resolvedUrl))) {
      bgContent = CachedImage(
        imageUrl: resolvedUrl,
        width: chipWidth,
        height: chipHeight,
        fit: BoxFit.cover,
        errorWidget: buildFallback(isBrokenImage: true),
      );
    } else {
      bgContent = buildFallback();
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Rectangle 1296 Base Background
          Container(
            width: chipWidth,
            height: chipHeight,
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9),
              borderRadius: BorderRadius.circular(7.r),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7.r),
              child: bgContent,
            ),
          ),
          // Rectangle 1297 Badge Tag
          Container(
            width: tagWidth,
            height: chipHeight,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(7.r),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.white,
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: -3.h,
              right: -4.w,
              child: GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.all(8.r),
                  child: Container(
                    width: 20.w,
                    height: 20.h,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFEAEA),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.close_rounded,
                      size: 15.38.r,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
