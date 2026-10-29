import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:ui';
import 'package:flutter_svg/svg.dart';
import 'dart:developer' as developer;
import 'package:office_app/core/constants/app_assets.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/services/session_reset_service.dart';
import '../../../injection_container.dart' as di;
import '../../../core/services/realtime_sync_service.dart';
import '../../../data/models/profile_response_model.dart';
import '../../../domain/usecases/switch_company_usecase.dart';
import '../common/gradient_circle_painter.dart';
import '../common/cached_image.dart';
import '../common/custom_snackbar.dart';
import '../settings/company_selection_bottom_sheet.dart';
import '../../viewmodels/pay_slip/payslip_provider.dart';
import '../../viewmodels/expenses/expenses_provider.dart';
import '../../viewmodels/profile/profile_provider.dart';
import '../../viewmodels/home/home_provider.dart';
import '../../viewmodels/user/access_provider.dart';
import '../../viewmodels/attendance/attendance_provider.dart';
import 'package:provider/provider.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  void _openCompanySelection(BuildContext context, ProfileModel? profile) {
    if (profile == null) return;
    final currentComp = profile.selectedCompanyName ?? profile.company;
    final availableCompanies = (profile.companies.isNotEmpty)
        ? profile.companies
              .where((c) => c.id != null && c.name != null)
              .map(
                (c) => CompanyItem(
                  id: c.id!,
                  name: c.name!,
                  isDefault: c.isDefault ?? false,
                ),
              )
              .toList()
        : null;

    CompanySelectionBottomSheet.show(
      context,
      currentCompany: currentComp,
      companies: availableCompanies,
      onCompanySelected: (selectedItem) async {
        if (selectedItem.name == currentComp) {
          return;
        }

        final profileProvider = context.read<ProfileProvider>();
        final accessProvider = context.read<AccessProvider>();
        final homeProvider = context.read<HomeProvider>();
        final attendanceProvider = context.read<AttendanceProvider>();
        final payslipProvider = context.read<PayslipProvider>();
        final expensesProvider = context.read<ExpensesProvider>();

        final switchCompanyUseCase = di.sl<SwitchCompanyUseCase>();

        Future<void> runSwitch() async {
          // 1. Perform company switch & atomic token replacement
          await switchCompanyUseCase(selectedItem.id);

          // 2. Reset all session-scoped provider states FIRST
          di.sl<SessionResetService>().resetAll();

          // 3. Stop active WebSockets
          final realtimeService = di.sl<RealtimeSyncService>();
          await realtimeService.stop();

          // 4. Load Home API & all company-dependent data
          await Future.wait([
            profileProvider.fetchProfileData(),
            accessProvider.fetchAccessDetails(),
            homeProvider.fetchHomeData(attendanceProvider),
            payslipProvider.fetchPayslip(),
            expensesProvider.fetchExpenseSummary(),
            expensesProvider.fetchInitialExpensesList(),
          ]);

          // 5. Reconnect WebSockets using new access token
          await realtimeService.start();
        }

        try {
          await runSwitch();
        } catch (e, stackTrace) {
          developer.log(
            '❌ [CompanySwitch Error] $e',
            error: e,
            stackTrace: stackTrace,
            name: 'HomeHeader',
          );
          if (context.mounted) {
            CustomSnackbar.show(
              context,
              message:
                  AppLocalizations.of(context)?.failedToSwitchCompany ??
                  'Failed to switch company. Please try again.',
            );
          }
          rethrow;
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Consumer<ProfileProvider>(
              builder: (context, provider, child) {
                final profile = provider.profileData;
                final isLoading = provider.isLoading && profile == null;

                return Row(
                  children: [
                    SizedBox(
                      width: 39.w,
                      height: 39.w,
                      child: CachedImage(
                        imageUrl: !isLoading ? profile?.avatarUrl : null,
                        userName: !isLoading ? profile?.name : null,
                        isProfile: true,
                        fit: BoxFit.cover,
                        radius: 100,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLoading || profile == null
                                ? '${AppLocalizations.of(context)?.hello ?? 'Hello'}, ...'
                                : '${AppLocalizations.of(context)?.hello ?? 'Hello'}, ${profile.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              height: 20 / 16,
                              letterSpacing: 0,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.white
                                  : AppColors.black,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          GestureDetector(
                            onTap: () =>
                                _openCompanySelection(context, profile),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 4.h),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      profile?.selectedCompanyName ??
                                          profile?.company ??
                                          '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w400,
                                        height: 14 / 12,
                                        letterSpacing: 1.0,
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? AppColors.midLight
                                            : const Color(0xFF404040),
                                      ),
                                    ),
                                  ),
                                  if (!isLoading &&
                                      profile != null &&
                                      (profile.selectedCompanyName ??
                                              profile.company)
                                          .isNotEmpty) ...[
                                    SizedBox(width: 5.w),
                                    RotatedBox(
                                      quarterTurns: 1,
                                      child: Icon(
                                        Icons.chevron_right_rounded,
                                        size: 20.sp,
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? AppColors.midLight
                                            : const Color(
                                                0xFF5B4039,
                                              ).withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // Notification Icon
          GestureDetector(
            onTap: () {
              if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
              context.read<HomeProvider>().markNotificationsAsRead();
              Navigator.pushNamed(context, AppRouter.notification);
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(86.36.r),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: CustomPaint(
                      painter: GradientCirclePainter(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors:
                              Theme.of(context).brightness == Brightness.dark
                              ? [
                                  Colors.white.withValues(alpha: 0.3),
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.3),
                                ]
                              : [
                                  Colors.white,
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white,
                                ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                        strokeWidth: 1.5.w,
                      ),
                      child: Container(
                        width: 38.w,
                        height: 38.w,
                        padding: EdgeInsets.all(8.64.w),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF5E340E).withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: SvgPicture.asset(
                          AppAssets.notification,
                          colorFilter:
                              Theme.of(context).brightness == Brightness.dark
                              ? const ColorFilter.mode(
                                  AppColors.white,
                                  BlendMode.srcIn,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                // Unread indicator dot
                Consumer<HomeProvider>(
                  builder: (context, homeProvider, child) {
                    final hasUnread =
                        homeProvider.homeData?.home?.hasUnreadNotifications ??
                        false;
                    if (!hasUnread) return const SizedBox.shrink();

                    return Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        width: 9.w,
                        height: 9.w,
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.w),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
