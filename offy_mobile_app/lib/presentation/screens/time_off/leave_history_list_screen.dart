import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/navigation/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/filter_model.dart';
import '../../../data/models/timeoff_response_model.dart';
import '../../viewmodels/time_off/time_off_provider.dart';
import '../../widgets/common/app_pagination_loader.dart';
import '../../widgets/common/custom_screen_header.dart';
import '../../widgets/common/custom_search_bar.dart';
import '../../widgets/common/filter/app_filter_split_layout.dart';
import '../../widgets/time_off/leave_item.dart';
import '../../widgets/time_off/time_off_list_shimmer.dart';
import '../../widgets/time_off/leave_period_banner.dart';
import '../../widgets/time_off/time_off_empty_state.dart';
import '../../../../l10n/app_localizations.dart';

class LeaveHistoryListScreen extends StatefulWidget {
  const LeaveHistoryListScreen({super.key});

  @override
  State<LeaveHistoryListScreen> createState() => _LeaveHistoryListScreenState();
}

class _LeaveHistoryListScreenState extends State<LeaveHistoryListScreen> {
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final TimeOffProvider _provider;

  bool _isFilterOpen = false;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _provider = context.read<TimeOffProvider>();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _scrollController.addListener(_onScroll);

    // Cancel any stale search debounce upon entering the screen
    _provider.cancelDebounce();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Always ensure the cancel/clear filter request happens on entering the screen
      await _provider.resetServerFilters(
        source: FilterSource.timeoff,
        target: TimeOffListType.history,
        executeFetch: false,
      );
      if (_provider.getSearchQuery(TimeOffListType.history).isNotEmpty) {
        await _provider.clearSearch(
          executeFetch: false,
          target: TimeOffListType.history,
        );
      }
      await _provider.fetchInitialHistory();
      if (_provider.availableTypes.isEmpty) {
        _provider.fetchAvailableTypes();
      }
      _provider.syncActiveFilters(target: TimeOffListType.history);
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<TimeOffProvider>().fetchMoreHistory();
    }
  }

  void _handleBackTap() {
    _searchFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    if (_isFilterOpen) {
      _discardFilters();
    } else {
      if (_provider.hasActiveFiltersFor(TimeOffListType.history)) {
        _provider.resetServerFilters(
          source: FilterSource.timeoff,
          target: TimeOffListType.history,
          executeFetch: false,
        );
      }
      Navigator.pop(context);
    }
  }

  void _handleFilterTap() {
    _searchFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    context.read<TimeOffProvider>().cancelDebounce();
    final willOpen = !_isFilterOpen;
    setState(() {
      _isFilterOpen = willOpen;
    });
    if (willOpen) {
      context.read<TimeOffProvider>().initFilters(
        source: FilterSource.timeoff,
        target: TimeOffListType.history,
      );
    } else {
      context.read<TimeOffProvider>().discardFilterChanges(target: TimeOffListType.history);
    }
  }

  /// Closing without Apply keeps the filters that were last applied.
  void _discardFilters() {
    setState(() => _isFilterOpen = false);
    context.read<TimeOffProvider>().discardFilterChanges(target: TimeOffListType.history);
  }

  /// The only place the filter API is called.
  void _applyFilters() {
    final provider = context.read<TimeOffProvider>();
    setState(() => _isFilterOpen = false);
    provider.clearNeutralStateSelections(target: TimeOffListType.history);
    if (!provider.isFiltering && provider.hasFilterChanges(target: TimeOffListType.history)) {
      provider.applyServerFilters(
        source: FilterSource.timeoff,
        target: TimeOffListType.history,
      );
    }
  }

  void _handleDateRangeTap() async {
    _searchFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    final provider = context.read<TimeOffProvider>();

    final picked = await Navigator.pushNamed(
      context,
      AppRouter.customDateRange,
      arguments: {
        'startDate': provider
            .getSelectedDateRange(TimeOffListType.history)
            ?.start,
        'endDate': provider
            .getSelectedDateRange(TimeOffListType.history)
            ?.end,
      },
    );
    if (picked is DateTimeRange && mounted) {
      context.read<TimeOffProvider>().setCustomDateRange(
        picked,
        target: TimeOffListType.history,
      );
    } else if (picked == false && mounted) {
      context.read<TimeOffProvider>().clearCustomDateRange(
        target: TimeOffListType.history,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<TimeOffProvider>();
    final historyLeaves = provider.history;

    final hasActiveFilters =
        provider.hasActiveFiltersFor(TimeOffListType.history);

    final isSearching = provider.isSearching;
    final isFiltering = provider.isFiltering;
    final isDebouncing = provider.isDebouncing;
    final isInteractionBlocked = provider.isInteractionBlocked;
    final isPaginating =
        provider.isFetchingMoreHistory && !isFiltering && !isSearching;

    final listItems = <_LeaveHistoryListItem>[];
    for (final group in historyLeaves) {
      if (group.timeline.isNotEmpty) {
        listItems.add(
          _LeaveHistoryBannerItem(
            timeline: group.timeline,
            isFirst: listItems.isEmpty,
          ),
        );
      }
      for (int i = 0; i < group.leaves.length; i++) {
        listItems.add(
          _LeaveHistoryEntryItem(
            leave: group.leaves[i],
            isLast: i == group.leaves.length - 1,
          ),
        );
      }
    }

    final totalLeavesCount = historyLeaves.fold<int>(
      0,
      (sum, group) => sum + group.leaves.length,
    );

    final hasMonthHeading =
        listItems.any((item) => item is _LeaveHistoryBannerItem);

    // Show shimmer always while initial loading on screen open, or when empty and fetching
    final showShimmer =
        _isInitialLoading ||
        (totalLeavesCount == 0 && provider.isFetchingHistory);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: isDark ? AppColors.darkTopCard : AppColors.midLight,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isDark ? AppColors.darkBg : Colors.white,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: PopScope(
        canPop: !_isFilterOpen,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            final provider = context.read<TimeOffProvider>();
            if (provider.hasActiveFiltersFor(TimeOffListType.history)) {
              provider.resetServerFilters(
                source: FilterSource.timeoff,
                target: TimeOffListType.history,
                executeFetch: false,
              );
            }
            return;
          }
          if (_isFilterOpen) {
            _discardFilters();
          }
        },
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Scaffold(
            backgroundColor: isDark
                ? AppColors.darkTopCard
                : AppColors.midLight,
            body: Container(
              decoration: isDark
                  ? const BoxDecoration(color: AppColors.darkBg)
                  : const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFF3E9E0), Colors.white],
                        stops: [0.5375, 1.0],
                      ),
                    ),
              child: Column(
                children: [
                  CustomScreenHeader(
                    onBackTap: _handleBackTap,
                    isSubmitting: false,
                    title:
                        AppLocalizations.of(context)?.leaveHistory ??
                        'Leave History',
                    centerTitle: false,
                    hasBottomRadius:
                        !_isFilterOpen && !(hasMonthHeading || showShimmer),
                    bottom: _isFilterOpen
                        ? null
                        : Padding(
                            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
                            child: CustomSearchBar(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onChanged: (val) {
                                context
                                    .read<TimeOffProvider>()
                                    .onSearchQueryChanged(
                                      val,
                                      target: TimeOffListType.history,
                                    );
                              },
                              onSubmitted: (val) {
                                context.read<TimeOffProvider>().submitSearch(
                                  val,
                                  target: TimeOffListType.history,
                                );
                              },
                              onClearTap: () {
                                _searchController.clear();
                                context.read<TimeOffProvider>().clearSearch(
                                  target: TimeOffListType.history,
                                );
                              },
                              onFilterTap: _handleFilterTap,
                              isSearching:
                                  !showShimmer && (isSearching || isDebouncing),
                              isFiltering: !showShimmer && isFiltering,
                              hasActiveFilters: hasActiveFilters,
                            ),
                          ),
                  ),
                  if (_isFilterOpen)
                    Expanded(
                      child: AppFilterSplitLayout(
                        selectedOption: provider.getSelectedFilterOption(
                          TimeOffListType.history,
                        ),
                        onOptionSelected: (opt) {
                          provider.selectFilterOption(
                            opt,
                            target: TimeOffListType.history,
                          );
                        },
                        options: provider.filterOptions,
                        isOptionsLoading: provider.isFetchingFilterOptions,
                        isContentLoading: provider.isFetchingFilterContent,
                        buckets: provider.monthBuckets,
                        selectedPreset: provider.getSelectedMonthBucket(
                          TimeOffListType.history,
                        ),
                        onPresetSelected: (b) {
                          provider.selectMonthBucket(
                            b,
                            target: TimeOffListType.history,
                          );
                        },
                        monthItems: provider.getCurrentMonthItems(
                          TimeOffListType.history,
                        ),
                        selectedMonths: provider.getSelectedMonthIds(
                          TimeOffListType.history,
                        ),
                        bucketsWithSelection: provider.getBucketsWithSelection(
                          TimeOffListType.history,
                        ),
                        hasDateFilter: provider.isCustomRangeActiveFor(
                          TimeOffListType.history,
                        )
                            ? (provider.getSelectedDateRange(
                                  TimeOffListType.history,
                                ) !=
                                null)
                            : (provider.isMonthActiveFor(
                                  TimeOffListType.history,
                                ) &&
                                provider
                                    .getSelectedMonthIds(
                                      TimeOffListType.history,
                                    )
                                    .isNotEmpty),
                        hasAnyMonthSelected: provider
                            .getSelectedMonthIds(
                              TimeOffListType.history,
                            )
                            .isNotEmpty,
                        isMonthActive: provider.isMonthActiveFor(
                          TimeOffListType.history,
                        ),
                        onMonthToggled: (m) {
                          provider.toggleMonth(
                            m,
                            target: TimeOffListType.history,
                          );
                        },
                        typeItems: provider.getCurrentTypeItems(
                          TimeOffListType.history,
                        ),
                        selectedTypeIds: provider.getSelectedTypeIds(
                          TimeOffListType.history,
                        ),
                        onTypeIdToggled: (typeId) {
                          final id = typeId is int
                              ? typeId
                              : int.tryParse(typeId.toString()) ?? 0;
                          provider.toggleType(
                            id,
                            target: TimeOffListType.history,
                          );
                        },
                        statusItems: provider.getCurrentStatusItems(
                          TimeOffListType.history,
                        ),
                        selectedStatusIds: provider.getSelectedStatusIds(
                          TimeOffListType.history,
                        ),
                        onStatusIdToggled: (statusId) {
                          provider.toggleStatus(
                            statusId as String,
                            target: TimeOffListType.history,
                          );
                        },
                        selectedDateRange: provider.getSelectedDateRange(
                          TimeOffListType.history,
                        ),
                        isCustomRangeActive: provider.isCustomRangeActiveFor(
                          TimeOffListType.history,
                        ),
                        onDateRangeTap: _handleDateRangeTap,
                        onSelectMonth: () => provider.selectMonthOption(
                          target: TimeOffListType.history,
                        ),
                        onCustomRangeActivated: () =>
                            provider.activateCustomDateRange(
                          target: TimeOffListType.history,
                        ),
                        onDeactivateMonth: () =>
                            provider.deactivateMonthFilter(
                          target: TimeOffListType.history,
                        ),
                        customRangeAvailable: provider.isCustomRangeAvailable,
                        onApply: _applyFilters,
                        onReset: () => provider.clearFilterSelections(target: TimeOffListType.history),
                        isApplying: provider.isFiltering,
                      ),
                    )
                  else
                    Expanded(
                      child: SafeArea(
                        top: false,
                        child: showShimmer
                            ? SingleChildScrollView(
                                padding: EdgeInsets.only(bottom: 16.h),
                                child: const TimeOffListShimmer(),
                              )
                            : totalLeavesCount == 0
                            ? TimeOffEmptyState(
                                searchQuery: provider.getSearchQuery(
                                  TimeOffListType.history,
                                ),
                                hasActiveFilters: hasActiveFilters,
                                defaultTitle: AppLocalizations.of(
                                  context,
                                )?.noHistoryAvailable,
                                defaultSubtitle: 'No leave history available.',
                              )
                            : RefreshIndicator(
                                onRefresh: () => provider.fetchInitialHistory(
                                  isRefresh: true,
                                ),
                                color: const Color(0xFFFD5223),
                                child: AbsorbPointer(
                                  absorbing: isInteractionBlocked,
                                  child: AnimatedOpacity(
                                    opacity: isInteractionBlocked ? 0.55 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: ListView.builder(
                                      controller: _scrollController,
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: EdgeInsets.only(bottom: 16.h),
                                      itemCount:
                                          listItems.length +
                                          (isPaginating ? 1 : 0),
                                      itemBuilder: (context, index) {
                                        if (index == listItems.length) {
                                          return const AppPaginationLoader();
                                        }

                                        final item = listItems[index];
                                        if (item is _LeaveHistoryBannerItem) {
                                          return LeavePeriodBanner(
                                            title: item.timeline,
                                            isFirst: item.isFirst,
                                          );
                                        } else if (item is _LeaveHistoryEntryItem) {
                                          return Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 16.w,
                                            ),
                                            child: LeaveItem(
                                              leave: item.leave,
                                              isLast: item.isLast,
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
}

sealed class _LeaveHistoryListItem {}

class _LeaveHistoryBannerItem extends _LeaveHistoryListItem {
  final String timeline;
  final bool isFirst;

  _LeaveHistoryBannerItem({
    required this.timeline,
    this.isFirst = false,
  });
}

class _LeaveHistoryEntryItem extends _LeaveHistoryListItem {
  final TimeOffLeaveItemModel leave;
  final bool isLast;

  _LeaveHistoryEntryItem({
    required this.leave,
    this.isLast = false,
  });
}
