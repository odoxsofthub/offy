import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../common/cached_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../viewmodels/profile/profile_provider.dart';

class MyTeamSection extends StatelessWidget {
  const MyTeamSection({super.key});

  Widget _buildTeamMember(
    BuildContext context, {
    required String name,
    required String imageUrl,
    required bool isOnline,
  }) {
    return Column(
      children: [
        Stack(
          children: [
            SizedBox(
              width: 53.w,
              height: 53.w,
              child: CachedImage(
                imageUrl: imageUrl,
                userName: name,
                fit: BoxFit.cover,
                radius: 100.r,
                height: 53.w,
                width: 53.w,
              ),
            ),
            if (isOnline)
              Positioned(
                top: 3.w,
                right: 3.w,
                child: Container(
                  width: 10.w,
                  height: 10.w,
                  decoration: const BoxDecoration(
                    color: Color(0xFF34C759),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 5.h),
        SizedBox(
          width: 53.w,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.white
                  : AppColors.tertiary,
              height: 15 / 10,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final team = provider.profileData?.team ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (provider.isLoading && provider.profileData == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MY TEAM',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.secondary,
              height: 15 / 12,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: 10.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: List.generate(
                4,
                (index) => Padding(
                  padding: EdgeInsets.only(right: 24.w),
                  child: Shimmer.fromColors(
                    baseColor: AppColors.shimmerBase(isDark),
                    highlightColor: AppColors.shimmerHighlight(isDark),
                    child: Column(
                      children: [
                        Container(
                          width: 53.w,
                          height: 53.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? AppColors.darkCard : AppColors.white,
                          ),
                        ),
                        SizedBox(height: 5.h),
                        Container(
                          width: 40.w,
                          height: 10.h,
                          color: isDark ? AppColors.darkCard : AppColors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (provider.profileData == null) {
      return const SizedBox.shrink();
    }

    if (team.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 33.h),
          Text(
            'MY TEAM',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.secondary,
              height: 15 / 12,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: 10.h),
          Container(
            height: 150.h,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x0F2A2A2A),
                  offset: const Offset(0, 4),
                  blurRadius: 20.r,
                ),
              ],
            ),
            child: Center(
              child: Text(
                'No team members found',
                style: TextStyle(
                  color: isDark ? const Color(0xFFEAE1D8) : Colors.grey[600],
                  fontSize: 14.sp,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 33.h),
        Text(
          'MY TEAM',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.secondary,
            height: 15 / 12,
            letterSpacing: 0,
          ),
        ),
        SizedBox(height: 10.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: team.map((member) {
              return Padding(
                padding: EdgeInsets.only(right: 24.w),
                child: _buildTeamMember(
                  context,
                  name: member.name,
                  imageUrl: member.avatarUrl,
                  isOnline: member.isOnline,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
