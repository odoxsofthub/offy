import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../viewmodels/profile/profile_provider.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

import '../../common/custom_snackbar.dart';
import '../../common/cached_image.dart';

class ProfileCoverCard extends StatefulWidget {
  final ScrollController outerScrollController;

  const ProfileCoverCard({super.key, required this.outerScrollController});

  @override
  State<ProfileCoverCard> createState() => _ProfileCoverCardState();
}

class _ProfileCoverCardState extends State<ProfileCoverCard> {
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    CustomSnackbar.show(
      context,
      message:
          AppLocalizations.of(context)?.copiedToClipboard ??
          'Copied to clipboard!',
    );
  }

  Widget _buildInfoRow({
    required String assetPath,
    required String text,
    required bool isExpanded,
    bool showCopy = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SvgPicture.asset(
          assetPath,
          colorFilter: const ColorFilter.mode(AppColors.main, BlendMode.srcIn),
          width: 20.w,
          height: 20.w,
        ),
        SizedBox(width: !isExpanded ? 6.w : 10.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.sp,
              color: AppColors.midLight,
              fontWeight: FontWeight.w400,
              height: 20 / 12,
              letterSpacing: 0,
            ),
          ),
        ),
        if (showCopy)
          GestureDetector(
            onTap: () => _copyToClipboard(text),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.all(8.w),
              child: SvgPicture.asset(
                AppAssets.copy,
                colorFilter: const ColorFilter.mode(
                  AppColors.midLight,
                  BlendMode.srcIn,
                ),
                width: 20.w,
                height: 20.w,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.profileData;
    final isLoading = profileProvider.isLoading && profile == null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading || profile == null) {
      return Shimmer.fromColors(
        baseColor: AppColors.shimmerBase(isDark),
        highlightColor: AppColors.shimmerHighlight(isDark),
        child: AspectRatio(
          aspectRatio: 370 / 348,
          child: Container(
            width: double.infinity,
            color: isDark ? AppColors.darkCard : AppColors.white,
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 360.h),
      child: AspectRatio(
        aspectRatio: 67 / 58,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardHeight = constraints.maxHeight;
            return Container(
              width: double.infinity,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CachedImage(
                      imageUrl: profile.avatarUrl,
                      userName: profile.name,
                      isProfile: true,
                      fit: BoxFit.cover,
                      radius: 0,
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      clipBehavior: Clip.hardEdge,
                      constraints: BoxConstraints(
                        minHeight: 186.h,
                        maxHeight: profileProvider.isExpanded
                            ? cardHeight
                            : 186.h,
                      ),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 1),
                            Colors.black.withValues(alpha: 0.8),
                            Colors.black.withValues(alpha: 0.4),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 0.8, 1.0],
                        ),
                      ),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification notification) {
                          if (notification is OverscrollNotification) {
                            if (widget.outerScrollController.hasClients) {
                              final overscroll = notification.overscroll;
                              final targetOffset =
                                  (widget.outerScrollController.offset +
                                          overscroll)
                                      .clamp(
                                        0.0,
                                        widget
                                            .outerScrollController
                                            .position
                                            .maxScrollExtent,
                                      );
                              widget.outerScrollController.position.jumpTo(
                                targetOffset,
                              );
                            }
                          }
                          return false;
                        },
                        child: SingleChildScrollView(
                          physics: profileProvider.isExpanded
                              ? const ClampingScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          reverse: !profileProvider.isExpanded,
                          child: Padding(
                            padding: !profileProvider.isExpanded
                                ? EdgeInsets.fromLTRB(20.w, 33.h, 20.w, 12.h)
                                : EdgeInsets.fromLTRB(20.w, 68.h, 20.w, 13.h),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            profile.name,
                                            maxLines: profileProvider.isExpanded
                                                ? 3
                                                : 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 32.sp,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                              height: 1.0,
                                              letterSpacing: 0,
                                            ),
                                          ),
                                          if ((profile.jobTitle ?? '').isNotEmpty)
                                            Text(
                                              profile.jobTitle!,
                                              maxLines:
                                                  profileProvider.isExpanded
                                                  ? 2
                                                  : 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 18.sp,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w400,
                                                height: 1.6,
                                                letterSpacing: 0,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        profileProvider.setExpanded(
                                          !profileProvider.isExpanded,
                                        );
                                      },
                                      child: Container(
                                        width: 32.w,
                                        height: 32.w,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                        ),
                                        child: Icon(
                                          profileProvider.isExpanded
                                              ? Icons
                                                    .keyboard_arrow_down_rounded
                                              : Icons
                                                    .keyboard_arrow_right_rounded,
                                          color: Colors.white,
                                          size: 20.w,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 10.h),
                                    child: Divider(
                                      color: AppColors.midLight.withValues(
                                        alpha: 0.5,
                                      ),
                                      height: 0.h,
                                      thickness: 0.6.h,
                                    ),
                                  ),
                                  if ((profile.email ?? '').isNotEmpty)
                                    _buildInfoRow(
                                      assetPath: AppAssets.sms,
                                      text: profile.email!,
                                      isExpanded: profileProvider.isExpanded,
                                      showCopy: !profileProvider.isExpanded,
                                    ),
                                  if (profileProvider.isExpanded) ...[
                                    // Phone / Mobile Row
                                    if ((profile.phone ?? '').isNotEmpty ||
                                        (profile.mobile ?? '').isNotEmpty) ...[
                                      SizedBox(height: 10.h),
                                      _buildInfoRow(
                                        assetPath: AppAssets.call,
                                        text: (profile.phone ?? '').isNotEmpty
                                            ? profile.phone!
                                            : (profile.mobile ?? ''),
                                        isExpanded: profileProvider.isExpanded,
                                      ),
                                    ],
                                    // Company / Department Row
                                    if (profile.company.isNotEmpty ||
                                        profile.department.isNotEmpty) ...[
                                      SizedBox(height: 10.h),
                                      _buildInfoRow(
                                        assetPath: AppAssets.building,
                                        text: profile.company.isNotEmpty
                                            ? '${profile.company}${profile.department.isNotEmpty ? ' / ${profile.department}' : ''}'
                                            : profile.department,
                                        isExpanded: profileProvider.isExpanded,
                                      ),
                                    ],
                                    // Work Location Row
                                    if ((profile.workLocation ?? '').isNotEmpty) ...[
                                      SizedBox(height: 10.h),
                                      _buildInfoRow(
                                        assetPath: AppAssets.house2,
                                        text: profile.workLocation!,
                                        isExpanded: profileProvider.isExpanded,
                                      ),
                                    ],
                                    SizedBox(height: 8.h),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
