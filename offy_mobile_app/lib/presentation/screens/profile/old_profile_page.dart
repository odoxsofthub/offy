import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/home/home_navigation_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/profile/old_profile/profile_header.dart';
import '../../widgets/profile/old_profile/profile_cover_card.dart';
import '../../widgets/profile/old_profile/my_team_section.dart';
import '../../widgets/profile/old_profile/report_to_section.dart';

class OldProfilePage extends StatefulWidget {
  const OldProfilePage({super.key});

  @override
  State<OldProfilePage> createState() => _OldProfilePageState();
}

class _OldProfilePageState extends State<OldProfilePage> {
  final ScrollController _outerScrollController = ScrollController();

  @override
  void dispose() {
    _outerScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<HomeNavigationProvider>();
    return Container(
      decoration: Theme.of(context).brightness == Brightness.dark
          ? const BoxDecoration(color: AppColors.darkBg)
          : const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF3E9E0), Color(0xFFF3E9E0), Colors.white],
                stops: [0.0, 0.5375, 1.0],
              ),
            ),
      child: Column(
        children: [
          SizedBox(height: 12.h),
          const ProfileHeader(),
          Expanded(
            child: SingleChildScrollView(
              controller: _outerScrollController,
              child: SafeArea(
                top: false,
                bottom: true,
                left: false,
                right: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileCoverCard(
                      key: ValueKey(navProvider.currentIndex),
                      outerScrollController: _outerScrollController,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: const MyTeamSection(),
                    ),
                    SizedBox(height: 26.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: const ReportToSection(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
