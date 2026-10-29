import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import 'leave_item.dart';

class LeaveHistoryShimmer extends StatelessWidget {
  final int itemCount;

  const LeaveHistoryShimmer({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        itemCount,
        (index) => Shimmer.fromColors(
          baseColor: AppColors.shimmerBase(isDark),
          highlightColor: AppColors.shimmerHighlight(isDark),
          child: LeaveItem(
            month: 'JUL',
            day: '00',
            title:
                AppLocalizations.of(context)?.loadingLeave ??
                'Loading Leave...',
            durationText: '0 Days',
            isApproved: false,
          ),
        ),
      ),
    );
  }
}
