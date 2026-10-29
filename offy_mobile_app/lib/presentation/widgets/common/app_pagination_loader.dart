import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

class AppPaginationLoader extends StatelessWidget {
  final EdgeInsetsGeometry? padding;
  final Color? color;

  const AppPaginationLoader({
    super.key,
    this.padding,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.only(top: 4.h, bottom: 16.h),
      child: Center(
        child: CircularProgressIndicator(
          color: color ?? AppColors.main,
        ),
      ),
    );
  }
}
