import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:office_app/presentation/widgets/home/home_shimmer.dart';
import '../../../l10n/app_localizations.dart';

import '../../widgets/navigation/custom_bottom_navigation_bar.dart';
import '../../widgets/navigation/navigation_item.dart';
import '../../widgets/common/custom_snackbar.dart';

import '../../../core/services/app_update_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../viewmodels/home/home_navigation_provider.dart';
import '../../viewmodels/home/home_provider.dart';
import '../../viewmodels/attendance/attendance_provider.dart';
import '../../viewmodels/attendance/attendance_log_provider.dart';
import '../../viewmodels/expenses/expenses_provider.dart';
import '../../viewmodels/profile/profile_provider.dart';
import '../../widgets/home/home_header.dart';
import '../../widgets/home/summary_cards.dart';
import '../attendance/attendance_page.dart';
import '../expenses/expenses_page.dart';
import '../profile/profile_page.dart';

import '../../viewmodels/user/access_provider.dart';
import '../../viewmodels/pay_slip/payslip_provider.dart';
import '../../../domain/usecases/register_device_token_usecase.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/network/network_interceptor.dart';
import '../../../injection_container.dart' as di;

class _TabEntry {
  final HomeTab tab;
  final Widget page;
  final NavigationItemData navItem;

  const _TabEntry({
    required this.tab,
    required this.page,
    required this.navItem,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Offline screen "back" returns to the previous tab; registered here because
    // only this context sees HomeNavigationProvider (NetworkAwareWrapper's doesn't).
    NetworkInterceptor.instance.registerTabNavigateBack(() {
      if (!mounted) return;
      context.read<HomeNavigationProvider>().goBackToPreviousTab();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      AppUpdateService.instance.showOptionalIfDue();
      final platform = Theme.of(context).platform;
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      final attendanceProvider = Provider.of<AttendanceProvider>(
        context,
        listen: false,
      );
      final accessProvider = Provider.of<AccessProvider>(
        context,
        listen: false,
      );
      final payslipProvider = Provider.of<PayslipProvider>(
        context,
        listen: false,
      );
      final profileProvider = Provider.of<ProfileProvider>(
        context,
        listen: false,
      );

      homeProvider.fetchHomeData(attendanceProvider);
      await accessProvider.fetchAccessDetails();
      payslipProvider.fetchPayslip();
      profileProvider.fetchProfileData();

      // Push Notifications Setup
      final isPushEnabled =
          accessProvider.accessDetails?.config?.pushNotificationsEnabled ??
          false;

      if (isPushEnabled && !kIsWeb) {
        final pushService = di.sl<PushNotificationService>();
        pushService.init();
        pushService.requestPermission().then((granted) async {
          if (granted) {
            final token = await pushService.getToken();
            if (token != null) {
              final deviceType = platform == TargetPlatform.iOS
                  ? 'ios'
                  : 'android';
              di.sl<RegisterDeviceTokenUseCase>()(
                token: token,
                deviceType: deviceType,
              );
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    NetworkInterceptor.instance.unregisterTabNavigateBack();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 1. Always refresh permission state silently across all tabs
      context.read<AccessProvider>().fetchAccessDetails(silent: true);

      // 2. Only fetch Home tab card summaries if currently viewing Home
      final navProvider = context.read<HomeNavigationProvider>();
      if (navProvider.currentTab == HomeTab.home) {
        _fetchHomeData(silent: true);
      }
    }
  }

  Future<void> _fetchHomeData({bool silent = false}) async {
    final homeProvider = context.read<HomeProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();
    final accessProv = context.read<AccessProvider>();
    final profileProvider = context.read<ProfileProvider>();
    await Future.wait([
      homeProvider.fetchHomeData(attendanceProvider, silent: silent),
      accessProv.fetchAccessDetails(silent: silent),
      profileProvider.fetchProfileData(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accessProvider = context.watch<AccessProvider>();
    final hasAttendance = accessProvider.hasFeature('attendance');
    final hasExpense = accessProvider.hasFeature('expense');
    final loc = AppLocalizations.of(context);

    return Consumer<HomeNavigationProvider>(
      builder: (context, provider, child) {
        final entries = <_TabEntry>[
          // 0: Home
          _TabEntry(
            tab: HomeTab.home,
            page: _buildHomeTab(context, isDark, accessProvider),
            navItem: NavigationItemData(
              selectedAsset: isDark
                  ? AppAssets.homeSelectedDark
                  : AppAssets.homeSelected,
              unselectedAsset: AppAssets.homeUnselected,
              label: loc?.home ?? 'Home',
            ),
          ),

          // 1: Attendance
          if (hasAttendance)
            _TabEntry(
              tab: HomeTab.attendance,
              page: ChangeNotifierProvider.value(
                value: di.sl<AttendanceLogProvider>(),
                child: const AttendancePage(),
              ),
              navItem: NavigationItemData(
                selectedAsset: isDark
                    ? AppAssets.attendanceSelectedDark
                    : AppAssets.attendanceSelected,
                unselectedAsset: AppAssets.attendanceUnselected,
                label: loc?.attendance ?? 'Attendance',
              ),
            ),

          // 2: Expenses
          if (hasExpense)
            _TabEntry(
              tab: HomeTab.expense,
              page: ChangeNotifierProvider.value(
                value: di.sl<ExpensesProvider>(),
                child: const ExpensesPage(),
              ),
              navItem: NavigationItemData(
                selectedAsset: isDark
                    ? AppAssets.expensesSelectedDark
                    : AppAssets.expensesSelected,
                unselectedAsset: AppAssets.expensesUnselected,
                label: loc?.expenses ?? 'Expenses',
              ),
            ),

          // 3: Profile
          _TabEntry(
            tab: HomeTab.profile,
            page: ChangeNotifierProvider.value(
              value: di.sl<ProfileProvider>(),
              child: const ProfilePage(),
            ),
            navItem: NavigationItemData(
              selectedAsset: AppAssets.profileSelected,
              unselectedAsset: AppAssets.profileUnselected,
              label: loc?.profile ?? 'Profile',
            ),
          ),
        ];

        // Reconcile current semantic tab against active entries
        final revokedTab = provider.currentTab;
        var matchedIndex = entries.indexWhere((e) => e.tab == revokedTab);
        if (matchedIndex == -1) {
          // Current tab was revoked! Gracefully fall back to Home
          matchedIndex = 0;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              provider.resetToHome();
              final String featureName;
              switch (revokedTab) {
                case HomeTab.attendance:
                  featureName = loc?.attendance ?? 'Attendance';
                  break;
                case HomeTab.expense:
                  featureName = 'Expense';
                  break;
                default:
                  featureName = 'Feature';
              }
              CustomSnackbar.show(
                context,
                message: '$featureName access has been revoked',
              );
            }
          });
        }
        final currentIndex = matchedIndex;
        final pages = entries.map((e) => e.page).toList();
        final navItems = entries.map((e) => e.navItem).toList();

        return PopScope(
          canPop: currentIndex == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (currentIndex != 0) {
              CustomSnackbar.clear(context);
              _fetchHomeData();
              provider.resetToHome();
            }
          },
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark
                  ? Brightness.light
                  : Brightness.dark,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarIconBrightness: isDark
                  ? Brightness.light
                  : Brightness.dark,
              systemNavigationBarContrastEnforced: false,
            ),
            child: Scaffold(
              extendBody: false,
              backgroundColor: isDark ? AppColors.darkBg : AppColors.white,
              body: SafeArea(
                top: false,
                bottom: false,
                child: pages[currentIndex],
              ),
              bottomNavigationBar: CustomBottomNavigationBar(
                currentIndex: currentIndex,
                items: navItems,
                onItemSelected: (index) {
                  CustomSnackbar.clear(context);
                  final navProvider = context.read<HomeNavigationProvider>();
                  if (index == 0 && navProvider.currentTab != HomeTab.home) {
                    _fetchHomeData();
                  }
                  navProvider.changeTab(entries[index].tab, index);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHomeTab(
    BuildContext context,
    bool isDark,
    AccessProvider accessProvider,
  ) {
    final hasAttendance = accessProvider.hasFeature('attendance');
    final hasTimeOff = accessProvider.hasFeature('time_off');
    final hasExpense = accessProvider.hasFeature('expense');
    final hasCalendar = accessProvider.hasFeature('calendar');
    final hasPayslip = accessProvider.hasFeature('payslip');
    final isEmptyHome =
        !hasAttendance &&
        !hasTimeOff &&
        !hasExpense &&
        !hasCalendar &&
        !hasPayslip;

    return Container(
      decoration: isDark
          ? const BoxDecoration(color: AppColors.darkBg)
          : const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.light, AppColors.light, Colors.white],
                stops: [0.0, 0.5375, 1.0],
              ),
            ),
      child: Stack(
        children: [
          if (!isEmptyHome)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: MediaQuery.paddingOf(context).top + 209.h,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkTopCard : AppColors.midLight,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20.r),
                    bottomRight: Radius.circular(20.r),
                  ),
                ),
              ),
            ),
          Column(
            children: [
              if (isEmptyHome)
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkTopCard : AppColors.midLight,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20.r),
                      bottomRight: Radius.circular(20.r),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.only(top: 18.h, bottom: 12.h),
                      child: const HomeHeader(),
                    ),
                  ),
                )
              else
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 18.h),
                    child: const HomeHeader(),
                  ),
                ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final homeProvider = context.watch<HomeProvider>();
                    final isInitialLoading =
                        (accessProvider.isLoading &&
                            accessProvider.accessDetails == null) ||
                        (homeProvider.isLoading &&
                            homeProvider.homeData == null);

                    if (isInitialLoading) {
                      return const HomeShimmer();
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return RefreshIndicator(
                          onRefresh: _fetchHomeData,
                          child: ScrollConfiguration(
                            behavior: ScrollConfiguration.of(
                              context,
                            ).copyWith(scrollbars: false, overscroll: false),
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: IntrinsicHeight(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16.w,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(height: 20.h),
                                        const Expanded(child: SummaryCards()),
                                        SizedBox(height: 20.h),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
