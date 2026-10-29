import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SubmitClaimButton extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback? onTap;

  const SubmitClaimButton({
    super.key,
    required this.isSubmitting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.r),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF5722), Color(0xFFFF8A65)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x40FF5722),
              blurRadius: 15.r,
              offset: Offset(0, 8.h),
            ),
          ],
        ),
        child: InkWell(
          onTap: isSubmitting ? null : onTap,
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            width: double.infinity,
            height: 56.h,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: isSubmitting
                  ? [
                      SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.0,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Submitting...',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                          letterSpacing: 0.0,
                          color: Colors.white,
                        ),
                      ),
                    ]
                  : [
                      Text(
                        AppLocalizations.of(context)?.submitClaim ?? 'Submit Claim',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                          letterSpacing: 0.0,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8.01.w),
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 16.w,
                      ),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}
