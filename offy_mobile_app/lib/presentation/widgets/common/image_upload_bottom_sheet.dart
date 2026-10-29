import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import 'upload_action_option_card.dart';
import 'custom_snackbar.dart';

class ImageUploadBottomSheet extends StatelessWidget {
  final Function(List<XFile>) onImagesSelected;
  final bool isExpense;
  final ImagePicker _picker = ImagePicker();

  ImageUploadBottomSheet({
    super.key,
    required this.onImagesSelected,
    this.isExpense = false,
  });

  static void show(
    BuildContext context, {
    required Function(List<XFile>) onImagesSelected,
    bool isExpense = false,
  }) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xB2000000),
      builder: (BuildContext context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: ImageUploadBottomSheet(
          onImagesSelected: onImagesSelected,
          isExpense: isExpense,
        ),
      ),
    );
  }

  Future<void> _showPermissionSettingsDialog(
    BuildContext context,
    String title,
    String content,
  ) async {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(ctx)?.cancel ?? 'Cancel'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              child: Text(
                AppLocalizations.of(ctx)?.openSettings ?? 'Open Settings',
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImageFromCamera(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    final status = await Permission.camera.status;
    if (status.isPermanentlyDenied) {
      if (!context.mounted) return;
      await _showPermissionSettingsDialog(
        context,
        loc?.cameraPermissionRequired ?? 'Camera Permission Required',
        isExpense
            ? (loc?.cameraPermissionPermanentlyDeniedReceipt ??
                'Camera permission has been permanently denied. Please enable camera access in your system settings to capture receipt photos.')
            : (loc?.cameraPermissionPermanentlyDeniedPhoto ??
                'Camera permission has been permanently denied. Please enable camera access in your system settings to capture photos.'),
      );
      return;
    }

    if (!status.isGranted) {
      final result = await Permission.camera.request();
      if (!result.isGranted) {
        if (!context.mounted) return;
        CustomSnackbar.show(
          context,
          message: isExpense
              ? (loc?.cameraPermissionRequiredReceipt ??
                  'Camera permission is required to take receipt photos.')
              : (loc?.cameraPermissionRequiredPhoto ??
                  'Camera permission is required to take photos.'),
        );
        return;
      }
    }

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        onImagesSelected([image]);
      }
    } catch (e) {
      if (!context.mounted) return;
      CustomSnackbar.show(
        context,
        message: loc?.errorCapturingImage('$e') ?? 'Error capturing image: $e',
      );
    }
  }

  Future<void> _pickFiles(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    try {
      final List<PlatformFile> result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'heic',
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
        ],
      );
      if (result.isNotEmpty) {
        final files = result
            .where((f) => f.path != null)
            .map((f) => XFile(f.path!))
            .toList();
        if (files.isNotEmpty) {
          onImagesSelected(files);
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      CustomSnackbar.show(
        context,
        message: loc?.errorPickingFiles('$e') ?? 'Error picking files: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isDark
            ? AppColors.darkTopCard
            : AppColors.light,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(24.w, 10.h, 24.w, 0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkTopCard : AppColors.light,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x1F000000),
                    offset: const Offset(0, -8),
                    blurRadius: 40.r,
                    spreadRadius: 0,
                  ),
                ],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32.r),
                  topRight: Radius.circular(32.r),
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Handle for Mobile
                  Container(
                    width: 48.w,
                    height: 6.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4BEB4).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(9999.r),
                    ),
                  ),
                  SizedBox(height: 32.h),
                  // Header
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        AppLocalizations.of(context)?.addAttachment ??
                            'Add Attachment',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w600,
                          height: 32 / 24,
                          letterSpacing: -0.24,
                          color: isDark ? AppColors.white : AppColors.black,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        isExpense
                            ? (AppLocalizations.of(context)?.howProvideReceipt ??
                                'How would you like to provide your receipt?')
                            : (AppLocalizations.of(context)?.howProvideAttachment ??
                                'How would you like to provide your attachment?'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.sp,
                          height: 20 / 14,
                          fontWeight: FontWeight.w400,
                          color: isDark
                              ? const Color(0xFFEAE1D8)
                              : AppColors.tertiary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 32.h),
                  // Action Options
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UploadActionOptionCard(
                        title:
                            AppLocalizations.of(context)?.takePhoto ??
                            'Take Photo',
                        subtitle: isExpense
                            ? (AppLocalizations.of(context)?.captureReceiptCamera ??
                                'Capture receipt with camera')
                            : (AppLocalizations.of(context)?.capturePhotoCamera ??
                                'Capture photo with camera'),
                        iconWidget: Container(
                          width: 56.w,
                          height: 56.w,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFFF5722), Color(0xFFFF8A65)],
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFFF5722,
                                ).withValues(alpha: 0.25),
                                offset: const Offset(0, 8),
                                blurRadius: 15.r,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.camera_alt_rounded,
                              color: AppColors.white,
                              size: 25.w,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _pickImageFromCamera(context);
                        },
                      ),
                      SizedBox(height: 16.h),
                      UploadActionOptionCard(
                        title: isExpense
                            ? (AppLocalizations.of(context)?.uploadReceipts ??
                                'Upload Receipts')
                            : (AppLocalizations.of(context)?.uploadFiles ??
                                'Upload Files'),
                        subtitle: isExpense
                            ? (AppLocalizations.of(context)?.selectReceiptFiles ??
                                'Select receipt from files')
                            : (AppLocalizations.of(context)?.selectAttachmentFiles ??
                                'Select attachment from files'),
                        iconWidget: Container(
                          width: 56.w,
                          height: 56.w,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFFB5A0,
                            ).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              AppAssets.files,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFFB02F00),
                                BlendMode.srcIn,
                              ),
                              width: 20.w,
                              height: 18.w,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _pickFiles(context);
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 32.h),
                  // Cancel Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 24.h),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context)?.cancel ?? 'Cancel',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFFB02F00),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);
}
}
