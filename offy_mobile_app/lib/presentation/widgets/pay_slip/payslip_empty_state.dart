import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/constants/app_assets.dart';
import '../empty_state/empty_state_view.dart';

class PayslipEmptyState extends StatelessWidget {
  final String searchQuery;
  final bool hasActiveFilters;
  final String? defaultTitle;
  final String? defaultSubtitle;

  const PayslipEmptyState({
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
      title = defaultTitle ?? 'No payslips found';
      subtitle = 'No payslips match your current search and filters.';
    } else {
      title = defaultTitle ?? (l10n?.emptyPayslip ?? 'No payslips available');
      subtitle = defaultSubtitle ??
          (l10n?.noHistoryAvailable ?? 'No history available');
    }

    final emptyView = EmptyStateView(
      imagePath: AppAssets.noPayslips,
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
