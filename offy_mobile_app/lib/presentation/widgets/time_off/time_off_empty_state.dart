import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/constants/app_assets.dart';
import '../empty_state/empty_state_view.dart';

class TimeOffEmptyState extends StatelessWidget {
  final String searchQuery;
  final bool hasActiveFilters;
  final String? defaultTitle;
  final String? defaultSubtitle;

  const TimeOffEmptyState({
    super.key,
    required this.searchQuery,
    required this.hasActiveFilters,
    this.defaultTitle,
    this.defaultSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasSearch = searchQuery.trim().isNotEmpty;

    final String title;
    final String subtitle;
    if (hasSearch || hasActiveFilters) {
      title = defaultTitle ?? 'No leaves found';
      subtitle = 'No leaves match your current search and filters.';
    } else {
      title = defaultTitle ?? (l10n?.noUpcomingLeaves ?? 'No leaves found');
      subtitle = defaultSubtitle ??
          (l10n?.noUpcomingLeavesSubtitle ?? 'You do not have any leaves.');
    }

    final emptyView = EmptyStateView(
      imagePath: AppAssets.noAttendances,
      title: title,
      subtitle: subtitle,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: emptyView,
          ),
        );
      },
    );
  }
}
