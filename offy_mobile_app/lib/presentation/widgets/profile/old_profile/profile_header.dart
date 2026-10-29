import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../viewmodels/profile/profile_provider.dart';
import '../../common/custom_settings_button.dart';
import '../../../screens/settings/settings_page.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(
            top: 6.h,
            bottom: 13.73.h,
          ),
          child: Row(
            children: [
              SizedBox(width: 41.27.w + 16.73.w), // Balance settings button & its padding to center "Profile"
              Expanded(
                child: Center(
                  child: Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.white
                          : AppColors.black,
                      height: 20 / 22,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: 16.73.w),
                child: CustomSettingsButton(
                  onTap: () {
                    final profileProvider = context.read<ProfileProvider>();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (routeContext) => ChangeNotifierProvider.value(
                          value: profileProvider,
                          child: const SettingsPage(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
