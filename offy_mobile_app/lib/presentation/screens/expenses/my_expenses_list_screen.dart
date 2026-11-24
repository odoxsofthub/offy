import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:office_app/presentation/widgets/expenses/expenses_list_shimmer.dart';

import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../data/models/filter_model.dart';
import '../../../data/models/expense_response_model.dart';
import '../../viewmodels/expenses/expenses_provider.dart';
import '../../viewmodels/user/access_provider.dart';
import '../../widgets/common/app_pagination_loader.dart';
import '../../widgets/common/custom_screen_header.dart';
import '../../widgets/common/custom_search_bar.dart';
import '../../widgets/expenses/expense_item_widget.dart';
import '../../widgets/expenses/expense_period_banner.dart';
import '../../widgets/expenses/expenses_empty_state.dart';
import '../../widgets/common/filter/app_filter_split_layout.dart';
import '../../../../l10n/app_localizations.dart';
import 'submit_expense_page.dart';

class MyExpensesListScreen extends StatefulWidget {
  const MyExpensesListScreen({super.key});

  @override
  State<MyExpensesListScreen> createState() => _MyExpensesListScreenState();
}

class _MyExpensesListScreenState extends State<MyExpensesListScreen> {
  late ScrollController _scrollController;
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;
  late final ExpensesProvider _provider;

  bool _isFilterOpen = false;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _provider = context.read<ExpensesProvider>();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();

    // Cancel any stale search debounce upon entering the screen
    _provider.cancelDebounce();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Always ensure the cancel/clear filter request happens on entering the screen
      await _provider.resetServerFilters(
        source: FilterSource.expense,
        executeFetch: false,
      );
      if (_provider.currentSearchQuery.isNotEmpty) {
        await _provider.clearSearch(executeFetch: false);
      }
      await _provider.fetchInitialExpensesList();
      if (_provider.categories.isEmpty) {
        _provider.fetchCategories();
      }
      _provider.syncActiveFilters(source: FilterSource.expense);
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ExpensesProvider>().fetchMoreExpenses();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleBackTap() {
    _searchFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    if (_isFilterOpen) {
      _discardFilters();
    } else {
      if (_provider.hasActiveFilters) {
        _provider.resetServerFilters(
          source: FilterSource.expense,
          executeFetch: false,
        );
      }
      Navigator.pop(context);
    }
  }

  void _handleFilterTap() {
    _searchFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    context.read<ExpensesProvider>().cancelDebounce();
    final willOpen = !_isFilterOpen;
    setState(() {
      _isFilterOpen = willOpen;
    });
    if (willOpen) {
      context.read<ExpensesProvider>().initFilters(
            source: FilterSource.expense,
          );
    } else {
      context.read<ExpensesProvider>().discardFilterChanges();
    }
  }

  /// Closing without Apply keeps the filters that were last applied.
  void _discardFilters() {
    setState(() => _isFilterOpen = false);
    context.read<ExpensesProvider>().discardFilterChanges();
  }

  /// The only place the filter API is called.
  void _applyFilters() {
    final provider = context.read<ExpensesProvider>();
    setState(() => _isFilterOpen = false);
    provider.clearNeutralStateSelections();
    if (!provider.isFiltering && provider.hasFilterChanges) {
      provider.applyServerFilters(source: FilterSource.expense);
    }
  }

  void _handleDateRangeTap() async {
    _searchFocusNode.unfocus();
    final provider = context.read<ExpensesProvider>();

    final picked = await Navigator.pushNamed(
      context,
      AppRouter.customDateRange,
      arguments: {
        'startDate': provider.selectedDateRange?.start,
        'endDate': provider.selectedDateRange?.end,
      },
    );
    if (picked is DateTimeRange && mounted) {
      context.read<ExpensesProvider>().setCustomDateRange(picked);
    } else if (picked == false && mounted) {
      context.read<ExpensesProvider>().clearCustomDateRange();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpensesProvider>();
    final accessProvider = context.watch<AccessProvider>();
    final hasExpense = accessProvider.hasFeature('expense');
    final expenses = provider.allExpenses;
    final currencySymbol =
        accessProvider.accessDetails?.company?.defaultCompanyCurrency?.symbol ??
        '\$';
    final listItems = _buildListItems(expenses, currencySymbol, provider);
    final hasBanner = listItems.any((item) => item is _BannerListItem);
    final isFetchingList = provider.isFetchingList;
    final isSearching = provider.isSearching;
    final isFiltering = provider.isFiltering;
    final isDebouncing = provider.isDebouncing;
    final isInteractionBlocked = provider.isInteractionBlocked;
    final isPaginating =
        provider.isFetchingMore && !isFiltering && !isSearching;

    // Show shimmer always while initial loading on screen open, or when empty and fetching
    final showShimmer =
        _isInitialLoading ||
        (expenses.isEmpty &&
            (!provider.hasLoadedInitialData || isFetchingList));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: isDark ? AppColors.darkTopCard : AppColors.midLight,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: PopScope(
        canPop: !_isFilterOpen,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            final provider = context.read<ExpensesProvider>();
            if (provider.hasActiveFilters) {
              provider.resetServerFilters(
                source: FilterSource.expense,
                executeFetch: false,
              );
            }
            return;
          }
          if (_isFilterOpen) _discardFilters();
        },
        child: GestureDetector(
          onTap: () {
            _searchFocusNode.unfocus();
            FocusScope.of(context).unfocus();
          },
          behavior: HitTestBehavior.translucent,
          child: Scaffold(
            backgroundColor: isDark ? AppColors.darkBg : AppColors.midLight,
            body: Container(
                decoration: isDark
                    ? const BoxDecoration(color: AppColors.darkBg)
                    : const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.light, Colors.white],
                          stops: [0.5375, 1.0],
                        ),
                      ),
                child: Column(
                  children: [
                    CustomScreenHeader(
                      onBackTap: _handleBackTap,
                      title:
                          AppLocalizations.of(context)?.myExpenses ??
                          'My Expenses',
                      hasBottomRadius:
                          !_isFilterOpen && !(hasBanner || showShimmer),
                      bottom: _isFilterOpen
                          ? null
                          : Padding(
                              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
                              child: CustomSearchBar(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                onChanged: (val) {
                                  context
                                      .read<ExpensesProvider>()
                                      .onSearchQueryChanged(val);
                                },
                                onSubmitted: (val) {
                                  context.read<ExpensesProvider>().submitSearch(
                                    val,
                                  );
                                },
                                onClearTap: () {
                                  _searchController.clear();
                                  context
                                      .read<ExpensesProvider>()
                                      .clearSearch();
                                },
                                onFilterTap: _handleFilterTap,
                                isSearching:
                                    !showShimmer && (isSearching || isDebouncing),
                                isFiltering: !showShimmer && isFiltering,
                                hasActiveFilters:
                                    provider.hasActiveFilters ||
                                    (provider.isMonthActive &&
                                        provider.selectedMonthIds.isNotEmpty) ||
                                    provider.selectedCategoryIds.isNotEmpty ||
                                    provider.selectedStatusIds.isNotEmpty ||
                                    (provider.isCustomRangeActive &&
                                        provider.selectedDateRange != null),
                              ),
                            ),
                    ),
                    if (_isFilterOpen)
                      Expanded(
                        child: AppFilterSplitLayout(
                          source: FilterSource.expense,
                          selectedOption: provider.selectedFilterOption,
                          onOptionSelected: (opt) {
                            provider.selectFilterOption(opt);
                          },
                          options: provider.filterOptions,
                          isOptionsLoading: provider.isFetchingFilterOptions,
                          isContentLoading: provider.isFetchingFilterContent,
                          buckets: provider.monthBuckets,
                          selectedPreset: provider.selectedMonthBucket,
                          onPresetSelected: (b) {
                            provider.selectMonthBucket(b);
                          },
                          monthItems: provider.currentMonthItems,
                          selectedMonths: provider.selectedMonthIds,
                          bucketsWithSelection: provider.bucketsWithSelection,
                          hasDateFilter: provider.isCustomRangeActive
                              ? (provider.selectedDateRange != null)
                              : (provider.isMonthActive &&
                                  provider.selectedMonthIds.isNotEmpty),
                          hasAnyMonthSelected:
                              provider.selectedMonthIds.isNotEmpty,
                          isMonthActive: provider.isMonthActive,
                          onMonthToggled: (m) {
                            provider.toggleMonth(m);
                          },
                          categoryItems: provider.currentCategoryItems,
                          selectedCategoryIds: provider.selectedCategoryIds,
                          onCategoryIdToggled: (catId) {
                            final id = catId is int
                                ? catId
                                : int.tryParse(catId.toString()) ?? 0;
                            provider.toggleCategory(id);
                          },
                          statusItems: provider.currentStatusItems,
                          selectedStatusIds: provider.selectedStatusIds,
                          onStatusIdToggled: (statusId) {
                            provider.toggleStatus(statusId as String);
                          },
                          selectedDateRange: provider.selectedDateRange,
                          isCustomRangeActive: provider.isCustomRangeActive,
                          onDateRangeTap: _handleDateRangeTap,
                          onSelectMonth: provider.selectMonthOption,
                          onCustomRangeActivated:
                              provider.activateCustomDateRange,
                          onDeactivateMonth: provider.deactivateMonthFilter,
                          customRangeAvailable: provider.isCustomRangeAvailable,
                          onApply: _applyFilters,
                          onReset: provider.clearFilterSelections,
                          isApplying: provider.isFiltering,
                        ),
                      )
                    else
                      Expanded(
                        child: SafeArea(
                          top: false,
                          child: showShimmer
                              ? RefreshIndicator(
                                  onRefresh: () async {
                                    await context
                                        .read<ExpensesProvider>()
                                        .fetchInitialExpensesList();
                                  },
                                  color: const Color(0xFFD66A46),
                                  child: SingleChildScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: EdgeInsets.only(
                                      bottom: 16.h,
                                    ),
                                    child: const ExpensesListShimmer(),
                                  ),
                                )
                              : expenses.isEmpty
                              ? ExpensesEmptyState(
                                  searchQuery: provider.currentSearchQuery,
                                  hasActiveFilters:
                                      provider.hasActiveFilters ||
                                      provider.selectedMonthIds.isNotEmpty ||
                                      provider.selectedCategoryIds.isNotEmpty ||
                                      provider.selectedStatusIds.isNotEmpty ||
                                      (provider.isCustomRangeActive &&
                                          provider.selectedDateRange != null),
                                  onAddNewExpense: hasExpense
                                      ? () async {
                                          _searchFocusNode.unfocus();
                                          FocusScope.of(context).unfocus();
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              settings: const RouteSettings(
                                                name: AppRouter.submitExpense,
                                              ),
                                              builder: (context) =>
                                                  const SubmitExpensePage(),
                                            ),
                                          );
                                          if (result == true && context.mounted) {
                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                                  if (context.mounted) {
                                                    context
                                                        .read<ExpensesProvider>()
                                                        .fetchInitialExpensesList();
                                                  }
                                                });
                                          }
                                        }
                                      : null,
                                )
                              : RefreshIndicator(
                                  onRefresh: () async {
                                    await context
                                        .read<ExpensesProvider>()
                                        .fetchInitialExpensesList(
                                          isRefresh: true,
                                        );
                                  },
                                  color: const Color(0xFFD66A46),
                                  child: AbsorbPointer(
                                    absorbing: isInteractionBlocked,
                                    child: AnimatedOpacity(
                                      opacity: isInteractionBlocked ? 0.55 : 1.0,
                                      duration: const Duration(milliseconds: 200),
                                      child: ListView.builder(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        controller: _scrollController,
                                        keyboardDismissBehavior:
                                            ScrollViewKeyboardDismissBehavior
                                                .onDrag,
                                        padding: EdgeInsets.only(
                                          bottom: 16.h,
                                        ),
                                        itemCount:
                                            listItems.length +
                                            (isPaginating ? 1 : 0),
                                        itemBuilder: (context, index) {
                                          if (index == listItems.length) {
                                            return const AppPaginationLoader();
                                          }
                                          final item = listItems[index];
                                          if (item is _BannerListItem) {
                                            return ExpensePeriodBanner(
                                              title: item.title,
                                              amount: item.amount,
                                              isFirst: item.isFirst,
                                            );
                                          } else if (item is _ExpenseEntryItem) {
                                            return Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 16.w,
                                              ),
                                              child: IgnorePointer(
                                                ignoring:
                                                    isSearching || isDebouncing,
                                                child: ExpenseItemWidget(
                                                  expense: item.expense,
                                                  onBeforeNavigate: () {
                                                    _searchFocusNode.unfocus();
                                                  },
                                                ),
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }

  List<_ExpenseListItem> _buildListItems(
    List<RecentExpenseModel> expenses,
    String currencySymbol,
    ExpensesProvider provider,
  ) {
    if (provider.expenseGroups.isNotEmpty) {
      final items = <_ExpenseListItem>[];
      for (final group in provider.expenseGroups) {
        final amountText = group.totalAmountDisplay.isNotEmpty
            ? group.totalAmountDisplay
            : (group.totalAmount > 0
                  ? NumberFormat.currency(
                      symbol: currencySymbol,
                      decimalDigits: 2,
                    ).format(group.totalAmount)
                  : '');

        items.add(
          _BannerListItem(
            title: group.timeline,
            amount: amountText,
            isFirst: items.isEmpty,
          ),
        );

        for (final exp in group.expenses) {
          items.add(_ExpenseEntryItem(exp));
        }
      }
      return items;
    }

    if (expenses.isEmpty) return const [];

    final items = <_ExpenseListItem>[];

    if (provider.isCustomRangeActive && provider.selectedDateRange != null) {
      final start = provider.selectedDateRange!.start;
      final end = provider.selectedDateRange!.end;
      final title = _formatDateRange(start, end);
      final total = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
      final formattedTotal = NumberFormat.currency(
        symbol: currencySymbol,
        decimalDigits: 2,
      ).format(total);

      items.add(
        _BannerListItem(title: title, amount: formattedTotal, isFirst: true),
      );

      for (final exp in expenses) {
        items.add(_ExpenseEntryItem(exp));
      }
    } else {
      final Map<String, List<RecentExpenseModel>> grouped = {};
      for (final exp in expenses) {
        final dt = DateTime.tryParse(exp.date) ?? DateTime.now();
        final key = DateFormat('MMMM yyyy').format(dt);
        grouped.putIfAbsent(key, () => []).add(exp);
      }

      for (final entry in grouped.entries) {
        final monthKey = entry.key;
        final monthExpenses = entry.value;
        final monthTotal = monthExpenses.fold<double>(
          0.0,
          (sum, e) => sum + e.amount,
        );
        final formattedTotal = NumberFormat.currency(
          symbol: currencySymbol,
          decimalDigits: 2,
        ).format(monthTotal);

        items.add(
          _BannerListItem(
            title: monthKey,
            amount: formattedTotal,
            isFirst: items.isEmpty,
          ),
        );

        for (final exp in monthExpenses) {
          items.add(_ExpenseEntryItem(exp));
        }
      }
    }

    return items;
  }

  String _formatDateRange(DateTime start, DateTime end) {
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return DateFormat('MMM d, yyyy').format(start);
    } else if (start.year == end.year) {
      return '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}';
    } else {
      return '${DateFormat('MMM d, yyyy').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}';
    }
  }
}

sealed class _ExpenseListItem {}

class _BannerListItem extends _ExpenseListItem {
  final String title;
  final String amount;
  final bool isFirst;

  _BannerListItem({
    required this.title,
    required this.amount,
    this.isFirst = false,
  });
}

class _ExpenseEntryItem extends _ExpenseListItem {
  final RecentExpenseModel expense;

  _ExpenseEntryItem(this.expense);
}
