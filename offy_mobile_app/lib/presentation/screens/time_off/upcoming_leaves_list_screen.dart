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
import '../../widgets/time_off/time_off_list_shimmer.dart';
import '../../widgets/time_off/leave_item.dart';
import '../../widgets/time_off/leave_period_banner.dart';
import '../../widgets/time_off/time_off_empty_state.dart';
import '../../../../l10n/app_localizations.dart';

class UpcomingLeavesListScreen extends StatefulWidget {
  const UpcomingLeavesListScreen({super.key});

  @override
  State<UpcomingLeavesListScreen> createState() =>
      _UpcomingLeavesListScreenState();
}

class _UpcomingLeavesListScreenState extends State<UpcomingLeavesListScreen> {
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final TimeOffProvider _provider;

  bool _isFilterOpen = false;
  String? _lastReportedError;
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
        target: TimeOffListType.upcoming,
        executeFetch: false,
      );
      if (_provider.getSearchQuery(TimeOffListType.upcoming).isNotEmpty) {
        await _provider.clearSearch(
          executeFetch: false,
          target: TimeOffListType.upcoming,
        );
      }
      await _provider.fetchInitialUpcomingLeaves();
      if (_provider.availableTypes.isEmpty) {
        _provider.fetchAvailableTypes();
      }
      _provider.syncActiveFilters(target: TimeOffListType.upcoming);
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
      context.read<TimeOffProvider>().fetchMoreUpcomingLeaves();
    }
  }

  void _handleBackTap() {
    _searchFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    if (_isFilterOpen) {
      _discardFilters();
    } else {
      if (_provider.hasActiveFiltersFor(TimeOffListType.upcoming)) {
        _provider.resetServerFilters(
          source: FilterSource.timeoff,
          target: TimeOffListType.upcoming,
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
        target: TimeOffListType.upcoming,
      );
    } else {
      context.read<TimeOffProvider>().discardFilterChanges(target: TimeOffListType.upcoming);
    }
  }

  /// Closing without Apply keeps the filters that were last applied.
  void _discardFilters() {
    setState(() => _isFilterOpen = false);
    context.read<TimeOffProvider>().discardFilterChanges(target: TimeOffListType.upcoming);
  }

  /// The only place the filter API is called.
  void _applyFilters() {
    final provider = context.read<TimeOffProvider>();
    setState(() => _isFilterOpen = false);
    provider.clearNeutralStateSelections(target: TimeOffListType.upcoming);
    if (!provider.isFiltering && provider.hasFilterChanges(target: TimeOffListType.upcoming)) {
      provider.applyServerFilters(
        source: FilterSource.timeoff,
        target: TimeOffListType.upcoming,
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
            .getSelectedDateRange(TimeOffListType.upcoming)
            ?.start,
        'endDate': provider
            .getSelectedDateRange(TimeOffListType.upcoming)
            ?.end,
      },
    );
    if (picked is DateTimeRange && mounted) {
      context.read<TimeOffProvider>().setCustomDateRange(
        picked,
        target: TimeOffListType.upcoming,
      );
    } else if (picked == false && mounted) {
      context.read<TimeOffProvider>().clearCustomDateRange(
        target: TimeOffListType.upcoming,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<TimeOffProvider>();
    final leaves = provider.upcomingLeaves;

    final hasActiveFilters =
        provider.hasActiveFiltersFor(TimeOffListType.upcoming);

    final isSearching = provider.isSearching;
    final isFiltering = provider.isFiltering;
    final isDebouncing = provider.isDebouncing;
    final isInteractionBlocked = provider.isInteractionBlocked;
    final isPaginating =
        provider.isFetchingMoreUpcoming && !isFiltering && !isSearching;

    final listItems = <_UpcomingLeaveListItem>[];
    for (final group in leaves) {
      if (group.timeline.isNotEmpty) {
        listItems.add(
          _UpcomingLeaveBannerItem(
            timeline: group.timeline,
            isFirst: listItems.isEmpty,
          ),
        );
      }
      for (int i = 0; i < group.leaves.length; i++) {
        listItems.add(
          _UpcomingLeaveEntryItem(
            leave: group.leaves[i],
            isLast: i == group.leaves.length - 1,
          ),
        );
      }
    }

    final totalLeavesCount = leaves.fold<int>(
      0,
      (sum, group) => sum + group.leaves.length,
    );

    final hasMonthHeading =
        listItems.any((item) => item is _UpcomingLeaveBannerItem);

    // Show shimmer always while initial loading on screen open, or when empty and fetching
    final showShimmer =
        _isInitialLoading ||
        (totalLeavesCount == 0 && provider.isFetchingUpcomingLeaves);

    // Show error snackbar without wiping existing list
    if (provider.errorMessage != null &&
        provider.errorMessage != _lastReportedError) {
      _lastReportedError = provider.errorMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _lastReportedError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_lastReportedError!),
              backgroundColor: AppColors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    } else if (provider.errorMessage == null) {
      _lastReportedError = null;
    }

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
            if (provider.hasActiveFiltersFor(TimeOffListType.upcoming)) {
              provider.resetServerFilters(
                source: FilterSource.timeoff,
                target: TimeOffListType.upcoming,
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
                        AppLocalizations.of(context)?.upcomingLeaves ??
                        'Upcoming Leaves',
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
                                      target: TimeOffListType.upcoming,
                                    );
                              },
                              onSubmitted: (val) {
                                context.read<TimeOffProvider>().submitSearch(
                                  val,
                                  target: TimeOffListType.upcoming,
                                );
                              },
                              onClearTap: () {
                                _searchController.clear();
                                context.read<TimeOffProvider>().clearSearch(
                                  target: TimeOffListType.upcoming,
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
                          TimeOffListType.upcoming,
                        ),
                        onOptionSelected: (opt) {
                          provider.selectFilterOption(
                            opt,
                            target: TimeOffListType.upcoming,
                          );
                        },
                        options: provider.filterOptions,
                        isOptionsLoading: provider.isFetchingFilterOptions,
                        isContentLoading: provider.isFetchingFilterContent,
                        buckets: provider.monthBuckets,
                        selectedPreset: provider.getSelectedMonthBucket(
                          TimeOffListType.upcoming,
                        ),
                        onPresetSelected: (b) {
                          provider.selectMonthBucket(
                            b,
                            target: TimeOffListType.upcoming,
                          );
                        },
                        monthItems: provider.getCurrentMonthItems(
                          TimeOffListType.upcoming,
                        ),
                        selectedMonths: provider.getSelectedMonthIds(
                          TimeOffListType.upcoming,
                        ),
                        bucketsWithSelection: provider.getBucketsWithSelection(
                          TimeOffListType.upcoming,
                        ),
                        hasDateFilter: provider.isCustomRangeActiveFor(
                          TimeOffListType.upcoming,
                        )
                            ? (provider.getSelectedDateRange(
                                  TimeOffListType.upcoming,
                                ) !=
                                null)
                            : (provider.isMonthActiveFor(
                                  TimeOffListType.upcoming,
                                ) &&
                                provider
                                    .getSelectedMonthIds(
                                      TimeOffListType.upcoming,
                                    )
                                    .isNotEmpty),
                        hasAnyMonthSelected: provider
                            .getSelectedMonthIds(
                              TimeOffListType.upcoming,
                            )
                            .isNotEmpty,
                        isMonthActive: provider.isMonthActiveFor(
                          TimeOffListType.upcoming,
                        ),
                        onMonthToggled: (m) {
                          provider.toggleMonth(
                            m,
                            target: TimeOffListType.upcoming,
                          );
                        },
                        typeItems: provider.getCurrentTypeItems(
                          TimeOffListType.upcoming,
                        ),
                        selectedTypeIds: provider.getSelectedTypeIds(
                          TimeOffListType.upcoming,
                        ),
                        onTypeIdToggled: (typeId) {
                          final id = typeId is int
                              ? typeId
                              : int.tryParse(typeId.toString()) ?? 0;
                          provider.toggleType(
                            id,
                            target: TimeOffListType.upcoming,
                          );
                        },
                        statusItems: provider.getCurrentStatusItems(
                          TimeOffListType.upcoming,
                        ),
                        selectedStatusIds: provider.getSelectedStatusIds(
                          TimeOffListType.upcoming,
                        ),
                        onStatusIdToggled: (statusId) {
                          provider.toggleStatus(
                            statusId as String,
                            target: TimeOffListType.upcoming,
                          );
                        },
                        selectedDateRange: provider.getSelectedDateRange(
                          TimeOffListType.upcoming,
                        ),
                        isCustomRangeActive: provider.isCustomRangeActiveFor(
                          TimeOffListType.upcoming,
                        ),
                        onDateRangeTap: _handleDateRangeTap,
                        onSelectMonth: () => provider.selectMonthOption(
                          target: TimeOffListType.upcoming,
                        ),
                        onCustomRangeActivated: () =>
                            provider.activateCustomDateRange(
                          target: TimeOffListType.upcoming,
                        ),
                        onDeactivateMonth: () =>
                            provider.deactivateMonthFilter(
                          target: TimeOffListType.upcoming,
                        ),
                        customRangeAvailable: provider.isCustomRangeAvailable,
                        onApply: _applyFilters,
                        onReset: () => provider.clearFilterSelections(target: TimeOffListType.upcoming),
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
                                  TimeOffListType.upcoming,
                                ),
                                hasActiveFilters: hasActiveFilters,
                                defaultTitle: AppLocalizations.of(
                                  context,
                                )?.noUpcomingLeaves,
                                defaultSubtitle: AppLocalizations.of(
                                  context,
                                )?.noUpcomingLeavesSubtitle,
                              )
                            : RefreshIndicator(
                                onRefresh: () async {
                                  await context
                                      .read<TimeOffProvider>()
                                      .fetchInitialUpcomingLeaves(
                                        isRefresh: true,
                                      );
                                },
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
                                        if (item is _UpcomingLeaveBannerItem) {
                                          return LeavePeriodBanner(
                                            title: item.timeline,
                                            isFirst: item.isFirst,
                                          );
                                        } else if (item is _UpcomingLeaveEntryItem) {
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

sealed class _UpcomingLeaveListItem {}

class _UpcomingLeaveBannerItem extends _UpcomingLeaveListItem {
  final String timeline;
  final bool isFirst;

  _UpcomingLeaveBannerItem({
    required this.timeline,
    this.isFirst = false,
  });
}

class _UpcomingLeaveEntryItem extends _UpcomingLeaveListItem {
  final TimeOffLeaveItemModel leave;
  final bool isLast;

  _UpcomingLeaveEntryItem({
    required this.leave,
    this.isLast = false,
  });
}
