import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/profile_response_model.dart';
import '../../viewmodels/profile/profile_provider.dart';
import '../common/cached_image.dart';
import 'settings_profile_shimmer.dart';

class SettingsProfileCard extends StatelessWidget {
  final ProfileProvider profileProvider;
  final ProfileModel? profile;

  const SettingsProfileCard({
    super.key,
    required this.profileProvider,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    if (profileProvider.isLoading && profile == null) {
      return const SettingsProfileShimmer();
    }

    final currentProfile = profile ?? ProfileModel.empty();

    // When currentProfile != null, Dart type promotes currentProfile to ProfileModel
    return Container(
      padding: EdgeInsets.only(
        top: 15.h,
        right: 20.w,
        bottom: 15.h,
        left: 16.w,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkCard
            : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0D000000),
            offset: const Offset(0, 1),
            blurRadius: 2.r,
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50.w,
            height: 50.w,
            child: CachedImage(
              imageUrl: currentProfile.avatarUrl,
              userName: currentProfile.name,
              isProfile: true,
              fit: BoxFit.cover,
              radius: 100,
            ),
          ),
          SizedBox(width: 13.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentProfile.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.white
                        : Colors.black,
                    height: 1.0,
                    letterSpacing: 0,
                  ),
                ),
                if ((currentProfile.email ?? '').isNotEmpty) ...[
                  SizedBox(height: 1.h),
                  Text(
                    currentProfile.email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.white.withValues(alpha: 0.7)
                          : Colors.black,
                      height: 1.0,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
