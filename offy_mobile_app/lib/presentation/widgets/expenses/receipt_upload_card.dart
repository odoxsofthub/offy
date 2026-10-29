import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../domain/entities/attachment_entity.dart';
import 'dashed_border_painter.dart';
import 'custom_close_button.dart';
import '../common/cached_image.dart';
import '../common/chat/app_document_launcher.dart';

class ReceiptUploadCard extends StatelessWidget {
  final bool isSubmitting;
  final bool isCompressing;
  final int compressingCount;
  final List<XFile> selectedImages;
  final List<AttachmentEntity> existingAttachments;
  final VoidCallback onAddImageTap;
  final ValueChanged<int> onRemoveImageTap;
  final ValueChanged<int>? onRemoveExistingAttachmentTap;

  const ReceiptUploadCard({
    super.key,
    required this.isSubmitting,
    this.isCompressing = false,
    this.compressingCount = 0,
    required this.selectedImages,
    this.existingAttachments = const [],
    required this.onAddImageTap,
    required this.onRemoveImageTap,
    this.onRemoveExistingAttachmentTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (selectedImages.isEmpty &&
        existingAttachments.isEmpty &&
        compressingCount == 0) {
      return GestureDetector(
        onTap: (isSubmitting || isCompressing) ? null : onAddImageTap,
        child: CustomPaint(
          painter: DashedBorderPainter(
            color: isDark ? AppColors.darkNav : const Color(0x80E4BEB4),
            strokeWidth: 2.0.w,
            borderRadius: 12.r,
            gap: 4.0,
            dash: 6.0,
          ),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: 26.h,
              right: 32.w,
              bottom: 26.h,
              left: 32.w,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF34271C) : Colors.white,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? const Color.fromRGBO(255, 219, 209, 0.1)
                        : const Color(0xFFFFDBD1),
                  ),
                  alignment: Alignment.center,
                  child: isCompressing
                      ? SizedBox(
                          width: 28.w,
                          height: 28.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark
                                  ? const Color(0xFF9F4122)
                                  : AppColors.secondary,
                            ),
                          ),
                        )
                      : SvgPicture.asset(
                          AppAssets.galleryAdd,
                          colorFilter: ColorFilter.mode(
                            isDark
                                ? const Color(0xFF9F4122)
                                : AppColors.secondary,
                            BlendMode.srcIn,
                          ),
                          width: 30.5.w,
                          height: 30.5.w,
                        ),
                ),
                SizedBox(height: 16.h),
                Text(
                  isCompressing
                      ? (AppLocalizations.of(context)?.processingDocuments ??
                          'Processing Documents...')
                      : (AppLocalizations.of(context)?.uploadReceipt ??
                          'Upload Receipt'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    letterSpacing: 0.0,
                    color: isDark ? Colors.white : AppColors.black,
                  ),
                ),
                Text(
                  isCompressing
                      ? (AppLocalizations.of(context)?.pleaseWaitFilesPrepared ??
                          'Please wait while files are being prepared')
                      : (AppLocalizations.of(context)?.tapToCapture ??
                          'Tap to capture or select a file'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    letterSpacing: 0.0,
                    color: isDark
                        ? const Color(0xFFF3E9E0)
                        : AppColors.tertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      final totalItemCount = existingAttachments.length +
          selectedImages.length +
          compressingCount;

      return CustomPaint(
        painter: DashedBorderPainter(
          color: isDark
              ? const Color.fromRGBO(228, 190, 180, 0.1)
              : const Color(0x80E4BEB4),
          strokeWidth: 2.0.w,
          borderRadius: 12.r,
          gap: 4.0,
          dash: 6.0,
        ),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: 16.h,
            right: 17.w,
            bottom: 16.h,
            left: 17.w,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? const Color.fromRGBO(255, 255, 255, 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 87.w,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.antiAlias,
                  padding: EdgeInsets.zero,
                  itemCount: totalItemCount,
                  separatorBuilder: (_, _) => SizedBox(width: 12.w),
                  itemBuilder: (context, index) {
                    // 1. Existing remote attachments
                    if (index < existingAttachments.length) {
                      final attachment = existingAttachments[index];
                      final isImage = attachment.isImage;
                      final isPdf = attachment.isPdf;

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: (isSubmitting || isCompressing)
                                ? null
                                : () {
                                    AppDocumentLauncher.open(
                                      context,
                                      path: attachment.url,
                                      allAttachments: existingAttachments,
                                      name: attachment.fileName,
                                      kind: attachment.kind,
                                    );
                                  },
                            child: isImage
                                ? Container(
                                    width: 87.w,
                                    height: 87.w,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD9D9D9),
                                      borderRadius:
                                          BorderRadius.circular(5.r),
                                    ),
                                    child: CachedImage(
                                      imageUrl: attachment.displayUrl,
                                      width: 87.w,
                                      height: 87.w,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Container(
                                    width: 87.w,
                                    height: 87.w,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4.w,
                                      vertical: 8.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF3D2A1D)
                                          : const Color(0xFFFFF0EC),
                                      borderRadius:
                                          BorderRadius.circular(5.r),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF6B4232)
                                            : const Color(0xFFFFCCBE),
                                        width: 1.w,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isPdf
                                              ? Icons.picture_as_pdf_rounded
                                              : Icons.insert_drive_file_rounded,
                                          color: isPdf
                                              ? const Color(0xFFD32F2F)
                                              : (isDark
                                                  ? AppColors.light
                                                  : AppColors.secondary),
                                          size: 32.w,
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          attachment.fileName,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                              ? Colors.white70
                                              : AppColors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          Positioned(
                            top: -2.w,
                            right: -3.w,
                            child: CustomCloseButton(
                              onTap: (isSubmitting || isCompressing)
                                  ? null
                                  : () => onRemoveExistingAttachmentTap
                                      ?.call(index),
                            ),
                          ),
                        ],
                      );
                    }

                    final selectedIndex = index - existingAttachments.length;

                    // 2. Selected local images/files
                    if (selectedIndex < selectedImages.length) {
                      final imageFile = selectedImages[selectedIndex];
                      final path = imageFile.path.toLowerCase();
                      final isImage =
                          path.endsWith('.jpg') ||
                          path.endsWith('.jpeg') ||
                          path.endsWith('.png') ||
                          path.endsWith('.webp') ||
                          path.endsWith('.heic') ||
                          path.endsWith('.gif') ||
                          path.endsWith('.bmp');
                      final isPdf = path.endsWith('.pdf');

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: (isSubmitting || isCompressing)
                                ? null
                                : () {
                                    final localAttachments = selectedImages
                                        .map((f) => AttachmentEntity(
                                            url: f.path, name: f.name))
                                        .toList();
                                    AppDocumentLauncher.open(
                                      context,
                                      path: imageFile.path,
                                      allAttachments: localAttachments,
                                      name: imageFile.name,
                                    );
                                  },
                            child: isImage
                                ? Container(
                                    width: 87.w,
                                    height: 87.w,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD9D9D9),
                                      borderRadius: BorderRadius.circular(5.r),
                                      image: DecorationImage(
                                        image: ResizeImage(
                                          FileImage(File(imageFile.path)),
                                          width: 200,
                                          height: 200,
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 87.w,
                                    height: 87.w,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4.w,
                                      vertical: 8.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF3D2A1D)
                                          : const Color(0xFFFFF0EC),
                                      borderRadius: BorderRadius.circular(5.r),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF6B4232)
                                            : const Color(0xFFFFCCBE),
                                        width: 1.w,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isPdf
                                              ? Icons.picture_as_pdf_rounded
                                              : Icons.insert_drive_file_rounded,
                                          color: isPdf
                                              ? const Color(0xFFD32F2F)
                                              : (isDark
                                                    ? AppColors.light
                                                    : AppColors.secondary),
                                          size: 32.w,
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          imageFile.name.isNotEmpty
                                              ? imageFile.name
                                              : path.split('/').last,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.white70
                                                : AppColors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          Positioned(
                            top: -2.w,
                            // Matches Figma absolute left coordinates
                            right: -3.w,
                            child: CustomCloseButton(
                              onTap: (isSubmitting || isCompressing)
                                  ? null
                                  : () => onRemoveImageTap(selectedIndex),
                            ),
                          ),
                        ],
                      );
                    }

                    // 3. Loading placeholder items if compressing
                    return Container(
                      width: 87.w,
                      height: 87.w,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF3D2A1D)
                            : const Color(0xFFFFF0EC),
                        borderRadius: BorderRadius.circular(5.r),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF6B4232)
                              : const Color(0xFFFFCCBE),
                          width: 1.w,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 24.w,
                        height: 24.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark
                                ? const Color(0xFF9F4122)
                                : AppColors.secondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 20.h),
              GestureDetector(
                onTap: (isSubmitting || isCompressing) ? null : onAddImageTap,
                child: CustomPaint(
                  painter: DashedBorderPainter(
                    color: isDark ? AppColors.light : AppColors.secondary,
                    strokeWidth: 1.0.w,
                    borderRadius: 9.r,
                    gap: 2.0,
                    dash: 2.0,
                  ),
                  child: Container(
                    width: double.infinity,
                    height: 54.h,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.transparent : Colors.white,
                      borderRadius: BorderRadius.circular(9.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          AppAssets.galleryAdd,
                          colorFilter: ColorFilter.mode(
                            isDark
                                ? AppColors.light
                                : AppColors.secondary,
                            BlendMode.srcIn,
                          ),
                          width: 30.w,
                          height: 30.w,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          AppLocalizations.of(context)?.addMoreImages ??
                              'Add more images',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            color: isDark
                                ? AppColors.light
                                : AppColors.secondary,
                          ),
                        ),
                      ],
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
}
