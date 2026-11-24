import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../common/cached_image.dart';
import '../common/custom_settings_button.dart';

class ProfileHeaderCard extends StatelessWidget {
  final String avatarUrl;
  final String name;
  final VoidCallback onSettingsTap;

  const ProfileHeaderCard({
    super.key,
    required this.avatarUrl,
    required this.name,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final double avatarSize = 110.w;
    final double halfAvatar = avatarSize / 2;
    final totalHeight = statusBarHeight + 96.h + halfAvatar;

    return SizedBox(
      width: double.infinity,
      height: totalHeight,
      child: Stack(
        children: [
          // AppBar at the top
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            height: statusBarHeight + 96.h,
            child: ProfileAppBar(onSettingsTap: onSettingsTap),
          ),
          // Avatar centered horizontally and straddling the bottom of AppBar vertically (half up, half down)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: ProfileAvatar(avatarUrl: avatarUrl, name: name),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileAppBar extends StatelessWidget {
  final VoidCallback onSettingsTap;

  const ProfileAppBar({super.key, required this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkTopCard : AppColors.light,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20.r),
          bottomRight: Radius.circular(20.r),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 96.h,
          padding: EdgeInsets.symmetric(horizontal: 16.73.w),
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: EdgeInsets.only(top: 6.h),
              child: CustomSettingsButton(onTap: onSettingsTap),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  final String avatarUrl;
  final String name;

  const ProfileAvatar({super.key, required this.avatarUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double avatarSize = 110.w;

    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? AppColors.darkBg : AppColors.white,
          width: 2.4.w,
        ),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15.r),
        child: CachedImage(
          imageUrl: avatarUrl,
          userName: name,
          isProfile: true,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
