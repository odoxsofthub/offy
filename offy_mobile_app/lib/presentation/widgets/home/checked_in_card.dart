import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/svg.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../viewmodels/attendance/attendance_provider.dart';
import '../../viewmodels/home/home_provider.dart';
import '../../viewmodels/user/access_provider.dart';
import '../common/action_failure_dialog.dart';
import 'attendance_confirmation_dialog.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/error_messages.dart';
import '../../../../l10n/app_localizations.dart';

class CheckedInCard extends StatelessWidget {
  const CheckedInCard({super.key});

  String _formatTime(String? isoTime) {
    return AppDateFormatter.formatTimeStr(isoTime);
  }

  String _formatDate(String? isoTime) {
    return AppDateFormatter.formatDateStr(isoTime);
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    return Consumer<AttendanceProvider>(
      builder: (context, provider, child) {
        final isCheckedIn = provider.isCheckedIn;
        final isCheckedOut = provider.isCheckedOut;
        final isSyncing = homeProvider.isLoading;
        final isButtonDisabled = provider.isLoading || isSyncing;

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF39200A)
                : const Color(0xFFF9F2EA),
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0x12000000),
                blurRadius: 8.r,
                offset: Offset(0, 5.h),
              ),
            ],
          ),

          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                top: -37.h,
                left: -45.w,
                child: Transform.rotate(
                  angle: -9.26 * 3.1415926535897932 / 180,
                  child: ImageFiltered(
                    // Figma/CSS blur radius of 51px converts to sigma = radius / 2 in Flutter
                    imageFilter: ImageFilter.blur(
                      sigmaX: 51 / 2,
                      sigmaY: 51 / 2,
                    ),
                    child: ClipOval(
                      child: Container(
                        width: 271.w,
                        height: 108.h,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color.fromRGBO(83, 48, 11, 0.51)
                            : const Color(0xFFF8D4AE),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 88.h,
                left: 130.w,
                child: Transform.rotate(
                  angle: -9.26 * 3.1415926535897932 / 180,
                  child: ImageFiltered(
                    // Figma/CSS blur radius of 54px converts to sigma = radius / 2 in Flutter
                    imageFilter: ImageFilter.blur(
                      sigmaX: 54 / 2,
                      sigmaY: 54 / 2,
                    ),
                    child: ClipOval(
                      child: Container(
                        width: 405.w,
                        height: 172.h,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0x806A230B)
                            : const Color(0xFFFF9774),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: (isCheckedIn || isCheckedOut)
                    ? EdgeInsets.zero
                    : EdgeInsets.symmetric(vertical: 6.5.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8.w,
                                      height: 8.w,
                                      decoration: BoxDecoration(
                                        color: isCheckedIn
                                            ? AppColors.green
                                            : AppColors.red, // Status color
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      AppLocalizations.of(
                                            context,
                                          )?.currentStatus.toUpperCase() ??
                                          'CURRENT STATUS',
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w500,
                                        height: 14 / 11,
                                        letterSpacing: 0,
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? AppColors.main
                                            : AppColors.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 11.h),
                                Text(
                                  isCheckedIn
                                      ? AppLocalizations.of(
                                              context,
                                            )?.checkedIn ??
                                            'Checked In'
                                      : (isCheckedOut
                                            ? AppLocalizations.of(
                                                    context,
                                                  )?.checkedOut ??
                                                  'Checked Out'
                                            : AppLocalizations.of(
                                                    context,
                                                  )?.readyToStart ??
                                                  'Ready to start'),
                                  style: TextStyle(
                                    fontSize: 30.sp,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppColors.white
                                        : AppColors.black,
                                    height: 20 / 30,
                                  ),
                                ),
                                SizedBox(height: 15.h),
                                if (isCheckedIn)
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 8.h,
                                    ),
                                    child: Wrap(
                                      spacing: 6.w,
                                      runSpacing: 4.h,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          AppLocalizations.of(
                                                context,
                                              )?.arrival ??
                                              'Arrival',
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            color:
                                                Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? AppColors.white
                                                : AppColors.black,
                                            fontWeight: FontWeight.w400,
                                            height: 14 / 14,
                                          ),
                                        ),
                                        Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text: _formatTime(
                                                  provider.checkInTime,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 14.sp,
                                                  fontWeight: FontWeight.w500,
                                                  height: 14 / 14,
                                                  letterSpacing: 0,
                                                  color:
                                                      Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.dark
                                                      ? AppColors.white
                                                      : AppColors.black,
                                                ),
                                              ),
                                              if (_formatDate(
                                                provider.checkInTime,
                                              ).isNotEmpty)
                                                TextSpan(
                                                  text:
                                                      ', ${_formatDate(provider.checkInTime)}',
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.w500,
                                                    height: 14 / 14,
                                                    letterSpacing: 0,
                                                    color:
                                                        Theme.of(
                                                              context,
                                                            ).brightness ==
                                                            Brightness.dark
                                                        ? AppColors.white
                                                        : AppColors.black,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (isCheckedOut)
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 8.h,
                                    ),
                                    child: Wrap(
                                      spacing: 6.w,
                                      runSpacing: 4.h,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          AppLocalizations.of(context)?.ended ??
                                              'Ended',
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            color:
                                                Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? AppColors.white
                                                : AppColors.black,
                                            fontWeight: FontWeight.w400,
                                            height: 14 / 14,
                                          ),
                                        ),
                                        Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text: _formatTime(
                                                  provider.checkOutTime,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 14.sp,
                                                  fontWeight: FontWeight.w500,
                                                  height: 14 / 14,
                                                  letterSpacing: 0,
                                                  color:
                                                      Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.dark
                                                      ? AppColors.white
                                                      : AppColors.black,
                                                ),
                                              ),
                                              if (_formatDate(
                                                provider.checkOutTime,
                                              ).isNotEmpty)
                                                TextSpan(
                                                  text:
                                                      ', ${_formatDate(provider.checkOutTime)}',
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.w500,
                                                    height: 14 / 14,
                                                    letterSpacing: 0,
                                                    color:
                                                        Theme.of(
                                                              context,
                                                            ).brightness ==
                                                            Brightness.dark
                                                        ? AppColors.white
                                                        : AppColors.black,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Text(
                                    AppLocalizations.of(
                                          context,
                                        )?.startYourDay ??
                                        'Start your day with a check-in.',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w400,
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppColors.white
                                          : AppColors.black,
                                      height: 14 / 16,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (isCheckedIn)
                          Image.asset(
                            AppAssets.checkInImage,
                            width: 142.w,
                            height: 142.h,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(),
                          )
                        else if (isCheckedOut)
                          Image.asset(
                            AppAssets.checkOutImage,
                            width: 142.w,
                            height: 142.h,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(),
                          ),
                      ],
                    ),
                    // Check Out / Check In Button
                    Padding(
                      padding: (isCheckedIn || isCheckedOut)
                          ? EdgeInsets.fromLTRB(10.w, 8.h, 10.2, 10.h)
                          : EdgeInsets.fromLTRB(10.w, 34.h, 10.2, 10.h),
                      child: InkWell(
                        onTap: isButtonDisabled
                            ? null
                            : () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) =>
                                      AttendanceConfirmationDialog(
                                        isCheckOut: isCheckedIn,
                                      ),
                                );
                                if (confirm != true || !context.mounted) return;

                                final accessProvider = context
                                    .read<AccessProvider>();
                                final homeProvider = context
                                    .read<HomeProvider>();
                                final success = await provider.toggleAttendance(
                                  accessProvider,
                                  onSyncHome: () => homeProvider.fetchHomeData(
                                    provider,
                                    silent: true,
                                  ),
                                  onTooFar: (distance, isCheckOut) {
                                    final loc = AppLocalizations.of(context);
                                    final actionStr = isCheckOut
                                        ? (loc?.checkOutAction ?? 'check out')
                                        : (loc?.checkInAction ?? 'check in');
                                    return loc?.tooFarFromOffice(
                                          distance,
                                          actionStr,
                                        ) ??
                                        'You are too far from the office. You must be within $distance meters to $actionStr.';
                                  },
                                );
                                if (!success && provider.errorMessage != null) {
                                  if (context.mounted) {
                                    if (provider.errorMessage ==
                                        'LOCATION_REQUIRED') {
                                      showDialog(
                                        context: context,
                                        builder: (context) {
                                          final loc = AppLocalizations.of(
                                            context,
                                          );
                                          final actionStr = isCheckedIn
                                              ? (loc?.checkOutAction ??
                                                    'check out')
                                              : (loc?.checkInAction ??
                                                    'check in');
                                          return AlertDialog(
                                            title: Text(
                                              loc?.locationRequired ??
                                                  'Location Required',
                                            ),
                                            content: Text(
                                              loc?.locationRequiredDesc(
                                                    actionStr,
                                                  ) ??
                                                  'Location is required to $actionStr. Please enable location services and grant permissions.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: Text(
                                                  loc?.cancel ?? 'Cancel',
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  Geolocator.openAppSettings();
                                                },
                                                child: Text(
                                                  loc?.openSettings ??
                                                      'Open Settings',
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    } else if (provider.errorMessage !=
                                        ErrorMessages.requestCancelled) {
                                      showDialog(
                                        context: context,
                                        builder: (_) => ActionFailureDialog(
                                          errorMessage: provider.errorMessage,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                        borderRadius: BorderRadius.circular(8.r),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isSyncing ? 0.8 : 1.0,
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              vertical: 16.h,
                              horizontal: 10.w,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.r),
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : null,
                              gradient:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? null
                                  : const LinearGradient(
                                      begin: Alignment.centerRight,
                                      end: Alignment.centerLeft,
                                      colors: [
                                        Color(0xFF000000),
                                        Color(0xFF62220E),
                                      ],
                                      stops: [0.4208, 0.9862],
                                    ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (provider.isLoading)
                                  SizedBox(
                                    width: 20.w,
                                    height: 20.w,
                                    child: CircularProgressIndicator(
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppColors.secondary
                                          : Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                else
                                  Text(
                                    isCheckedIn
                                        ? (AppLocalizations.of(
                                                context,
                                              )?.checkOutBtn ??
                                              'Check Out')
                                        : (AppLocalizations.of(
                                                context,
                                              )?.checkInBtn ??
                                              'Check In'),
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppColors.secondary
                                          : Colors.white,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w500,
                                      height: 20 / 16,
                                    ),
                                  ),
                                if (!provider.isLoading) ...[
                                  SizedBox(width: 12.w),
                                  SvgPicture.asset(
                                    isCheckedIn
                                        ? AppAssets.logout
                                        : AppAssets.login,
                                    height: 24.w,
                                    width: 24.w,
                                    colorFilter:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const ColorFilter.mode(
                                            AppColors.secondary,
                                            BlendMode.srcIn,
                                          )
                                        : null,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
