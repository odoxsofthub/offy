import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/constants/app_assets.dart';
import '../empty_state/empty_state_view.dart';

class ExpensesEmptyState extends StatelessWidget {
  final String searchQuery;
  final bool hasActiveFilters;
  final VoidCallback? onAddNewExpense;

  const ExpensesEmptyState({
    super.key,
    required this.searchQuery,
    required this.hasActiveFilters,
    this.onAddNewExpense,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasSearch = searchQuery.trim().isNotEmpty;

    final String title;
    final String subtitle;
    bool showActionButton = false;
    String? actionButtonText;
    IconData? actionButtonIcon;
    VoidCallback? onActionButtonTap;

    if (hasSearch || hasActiveFilters) {
      title = l10n?.noExpensesFound ?? 'No expenses found';
      subtitle = l10n?.noExpensesMatchSearchAndFilters ??
          'No expenses match your current search and filters.';
    } else {
      title = l10n?.noExpensesFound ?? 'No expenses found';
      subtitle =
          l10n?.youHaventLoggedAnyExpensesYet ??
          "You haven't logged any expenses yet.";
      if (onAddNewExpense != null) {
        showActionButton = true;
        actionButtonText = l10n?.addNewExpense ?? 'Add new expense';
        actionButtonIcon = Icons.add;
        onActionButtonTap = onAddNewExpense;
      } else {
        showActionButton = false;
      }
    }

    final emptyView = EmptyStateView(
      imagePath: AppAssets.noExpenses,
      title: title,
      subtitle: subtitle,
      showActionButton: showActionButton,
      actionButtonText: actionButtonText,
      actionButtonIcon: actionButtonIcon,
      onActionButtonTap: onActionButtonTap,
    );

    if (showActionButton) {
      return emptyView;
    }

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
