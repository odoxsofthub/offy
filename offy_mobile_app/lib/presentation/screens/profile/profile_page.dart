import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:office_app/data/models/profile_response_model.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';

import '../../viewmodels/profile/profile_provider.dart';
import '../../widgets/profile/profile_shimmer.dart';
import '../../widgets/profile/profile_header_card.dart';
import '../../widgets/profile/profile_info_section.dart';
import '../../widgets/profile/profile_tab_bar.dart';
import '../../widgets/profile/work_tab_content.dart';
import '../../widgets/profile/personal_tab_content.dart';
import '../../widgets/profile/docs_tab_content.dart';
import '../../../injection_container.dart' as di;
import '../../viewmodels/privacy_policy/privacy_policy_provider.dart';
import '../../viewmodels/terms_conditions/terms_conditions_provider.dart';
import '../settings/settings_page.dart';

import '../../viewmodels/home/home_navigation_provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _activeTab = 0;
  bool _isTabTapping = false;
  late final PageController _pageController;
  late final ScrollController _outerScrollController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _activeTab);
    _outerScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<HomeNavigationProvider>().consumeSuppressNextTabFetch()) {
        return;
      }
      context.read<ProfileProvider>().fetchProfileData();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _outerScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.profileData;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final scaffoldBgColor = isDark ? AppColors.darkTopCard : AppColors.light;
    final double tabBarHeight = 22.sp + 36.h;
    final double gapHeight = 22.h;

    final profileData = profile ?? ProfileModel.empty();

    Widget bodyContent;
    if (profileProvider.isLoading && profile == null) {
      bodyContent = const ProfileShimmer();
    } else {
      bodyContent = SafeArea(
        bottom: false,
        child: Container(
          color: isDark ? AppColors.darkBg : AppColors.white,
          child: RefreshIndicator(
            onRefresh: () async {
              await context.read<ProfileProvider>().fetchProfileData();
            },
            color: AppColors.main,
            child: NestedScrollView(
              controller: _outerScrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                      ProfileHeaderCard(
                        avatarUrl: profileData.avatarUrl,
                        name: profileData.name,
                        onSettingsTap: () {
                          final provider = context.read<ProfileProvider>();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (routeContext) => MultiProvider(
                                providers: [
                                  ChangeNotifierProvider.value(value: provider),
                                  ChangeNotifierProvider(
                                    create: (_) =>
                                        di.sl<PrivacyPolicyProvider>(),
                                  ),
                                  ChangeNotifierProvider(
                                    create: (_) =>
                                        di.sl<TermsConditionsProvider>(),
                                  ),
                                ],
                                child: const SettingsPage(),
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 14.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: ProfileInfoSection(
                          name: profileData.name,
                          jobTitle: profileData.jobTitle,
                        ),
                      ),
                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                    context,
                  ),
                  sliver: SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyTabBarDelegate(
                      height: tabBarHeight,
                      paddingTop: 0,
                      bottomGap: gapHeight,
                      child: ProfileTabBar(
                        currentIndex: _activeTab,
                        onTabChanged: (index) {
                          if (_activeTab == index) return;
                          _isTabTapping = true;
                          setState(() {
                            _activeTab = index;
                          });
                          if (index == 2) {
                            context.read<ProfileProvider>().reloadAllDocuments();
                          }
                          _pageController
                              .animateToPage(
                                index,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              )
                              .then((_) {
                                if (!mounted) return;
                                if (_activeTab == index) {
                                  if (_pageController.hasClients &&
                                      _pageController.page?.round() != index) {
                                    _pageController.jumpToPage(index);
                                  }
                                  if (_isTabTapping) {
                                    setState(() {
                                      _isTabTapping = false;
                                    });
                                  }
                                }
                              })
                              .catchError((_) {
                                if (!mounted) return;
                                if (_activeTab == index) {
                                  if (_pageController.hasClients &&
                                      _pageController.page?.round() != index) {
                                    _pageController.jumpToPage(index);
                                  }
                                  if (_isTabTapping) {
                                    setState(() {
                                      _isTabTapping = false;
                                    });
                                  }
                                }
                              });
                        },
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: SafeArea(
              top: false,
              bottom: true,
              child: Builder(
                builder: (innerContext) {
                  return PageView(
                    controller: _pageController,
                    physics: _isTabTapping
                        ? const NeverScrollableScrollPhysics()
                        : const PageScrollPhysics(),
                    onPageChanged: (index) {
                      if (_isTabTapping) {
                        if (index == _activeTab) {
                          _isTabTapping = false;
                        }
                        return;
                      }
                      setState(() {
                        _activeTab = index;
                      });
                      if (index == 2) {
                        context.read<ProfileProvider>().reloadAllDocuments();
                      }
                    },
                    children: [
                      WorkTabContent(
                        key: const PageStorageKey('work_tab'),
                        profile: profileData,
                      ),
                      PersonalTabContent(
                        key: const PageStorageKey('personal_tab'),
                        profile: profileData,
                      ),
                      DocsTabContent(
                        key: const PageStorageKey('docs_tab'),
                        profile: profileData,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isDark ? AppColors.darkBg : Colors.white,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(backgroundColor: scaffoldBgColor, body: bodyContent),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  final double paddingTop;
  final double bottomGap;

  _StickyTabBarDelegate({
    required this.child,
    required this.height,
    required this.paddingTop,
    required this.bottomGap,
  });

  @override
  double get minExtent => height + paddingTop + bottomGap;

  @override
  double get maxExtent => height + paddingTop + bottomGap;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double extent = (maxExtent - shrinkOffset).clamp(
      minExtent,
      maxExtent,
    );
    return SizedBox(
      height: extent,
      child: Container(
        color: isDark ? AppColors.darkBg : AppColors.white,
        padding: EdgeInsets.only(top: paddingTop, bottom: bottomGap),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) {
    return oldDelegate.child != child ||
        oldDelegate.height != height ||
        oldDelegate.paddingTop != paddingTop ||
        oldDelegate.bottomGap != bottomGap;
  }
}
