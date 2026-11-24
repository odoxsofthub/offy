import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../common/cached_image.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../viewmodels/profile/profile_provider.dart';

class ReportToSection extends StatelessWidget {
  const ReportToSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final reportTo = provider.profileData?.reportTo;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (provider.isLoading && provider.profileData == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REPORT TO',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.secondary,
              height: 15 / 12,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: 10.h),
          Shimmer.fromColors(
            baseColor: AppColors.shimmerBase(isDark),
            highlightColor: AppColors.shimmerHighlight(isDark),
            child: Container(
              width: double.infinity,
              height: 56.h,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.white,
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
          ),
        ],
      );
    }

    if (provider.profileData == null) {
      return const SizedBox.shrink();
    }

    if (reportTo == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REPORT TO',
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
                'No reporting manager assigned',
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
        Text(
          'REPORT TO',
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
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 9.h),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkCard
                : AppColors.light,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 38.w,
                height: 38.w,
                child: CachedImage(
                  imageUrl: reportTo.avatarUrl,
                  userName: reportTo.name,
                  fit: BoxFit.cover,
                  radius: 100,
                ),
              ),
              SizedBox(width: 11.5.w),
              Expanded(
                child: Text(
                  reportTo.name,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.white
                        : AppColors.tertiary,
                    height: 15 / 14,
                    letterSpacing: 0,
                  ),
                  maxLines: 2,
                ),
              ),
              if (reportTo.canConnect) ...[
                SizedBox(width: 4.w),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkNav.withValues(alpha: 0.6)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(100.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4.r,
                          offset: Offset(0, 2.h),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 9.w),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 6.5.h),
                          child: Text(
                            'Connect',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w400,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.white
                                  : AppColors.tertiary,
                              height: 15 / 12,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 4.h),
                          child: SvgPicture.asset(
                            AppAssets.sms,
                            colorFilter: ColorFilter.mode(
                              Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.white
                                  : AppColors.tertiary,
                              BlendMode.srcIn,
                            ),
                            width: 20.w,
                            height: 20.w,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ],
    );
  }
}
