import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:office_app/core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';

class NavigationItemData {
  final String selectedAsset;
  final String unselectedAsset;
  final String label;

  const NavigationItemData({
    required this.selectedAsset,
    required this.unselectedAsset,
    required this.label,
  });
}

class NavigationItemWidget extends StatelessWidget {
  final String selectedAsset;
  final String unselectedAsset;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final double scale;

  const NavigationItemWidget({
    super.key,
    required this.selectedAsset,
    required this.unselectedAsset,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              alignment: Alignment.center,
              child:
                  (isSelected ? selectedAsset : unselectedAsset).endsWith(
                    '.svg',
                  )
                  ? SvgPicture.asset(
                      isSelected ? selectedAsset : unselectedAsset,
                      width: 30.w, // icon size: 30
                      height: 30.w,
                      colorFilter:
                          Theme.of(context).brightness == Brightness.light
                          ? null
                          : !isSelected
                          ? ColorFilter.mode(AppColors.darkNav, BlendMode.srcIn)
                          : selectedAsset == AppAssets.profileSelected
                          ? ColorFilter.mode(
                              AppColors.midLight,
                              BlendMode.srcIn,
                            )
                          : null,
                    )
                  : Image.asset(
                      isSelected ? selectedAsset : unselectedAsset,
                      width: 30.w,
                      height: 30.w,
                    ),
            ),
            SizedBox(height: 10.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp * scale,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).brightness == Brightness.dark
                    ? (isSelected ? AppColors.midLight : AppColors.darkNav)
                    : (isSelected ? AppColors.black : AppColors.navColor),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
