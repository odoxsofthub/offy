import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';

/// Displays a styled validation error message matching the global Figma error text spec.
/// Prepends '*' to the message with no space, renders nothing when [errorText] is null or empty.
class CustomErrorText extends StatelessWidget {
  final String? errorText;

  const CustomErrorText({super.key, required this.errorText});

  @override
  Widget build(BuildContext context) {
    if (errorText == null || errorText!.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayMessage = errorText!.startsWith('*')
        ? errorText!
        : '*$errorText';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 10.h),
        Text(
          displayMessage,
          style: TextStyle(
            fontStyle: FontStyle.normal,
            fontWeight: FontWeight.w400,
            fontSize: 12.sp,
            height: 16 / 12,
            letterSpacing: 0.6,
            color: AppColors.red,
          ),
        ),
      ],
    );
  }
}
