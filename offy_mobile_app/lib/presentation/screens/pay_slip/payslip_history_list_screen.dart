import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/utils/date_formatter.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/payslip_year_grouping.dart';
import '../../../l10n/app_localizations.dart';
import '../../../data/models/filter_model.dart';
import '../../widgets/common/app_pagination_loader.dart';
import '../../widgets/common/custom_screen_header.dart';
import '../../widgets/common/custom_search_bar.dart';
import '../../widgets/common/filter/app_filter_split_layout.dart';
import '../../viewmodels/pay_slip/payslip_provider.dart';
import '../../widgets/pay_slip/payslip_empty_state.dart';
import '../../widgets/pay_slip/payslip_history_item.dart';
import 'payslip_details_screen.dart';
import '../../viewmodels/user/access_provider.dart';

class PayslipHistoryListScreen extends StatefulWidget {
  const PayslipHistoryListScreen({super.key});

  @override
  State<PayslipHistoryListScreen> createState() =>
      _PayslipHistoryListScreenState();
}

class _PayslipHistoryListScreenState extends State<PayslipHistoryListScreen> {
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final PayslipProvider _provider;

  bool _isFilterOpen = false;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _provider = context.read<PayslipProvider>();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _scrollController.addListener(_onScroll);

    // Cancel any stale search debounce upon entering the screen
    _provider.cancelDebounce();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Always ensure the cancel/clear filter request happens on entering the screen
      await _provider.resetServerFilters(
        source: FilterSource.payslip,
        executeFetch: false,
      );
      if (_provider.currentSearchQuery.isNotEmpty) {
        await _provider.clearSearch(executeFetch: false);
      }
      await _provider.fetchInitialHistoryPayslips();
      _provider.syncActiveFilters(source: FilterSource.payslip);
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
      context.read<PayslipProvider>().fetchMoreHistoryPayslips();
    }
  }

  void _handleBackTap() {
    _searchFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    if (_isFilterOpen) {
      _discardFilters();
    } else {
      if (_provider.hasActiveFilters) {
        _provider.resetServerFilters(
          source: FilterSource.payslip,
          executeFetch: false,
        );
      }
      Navigator.pop(context);
    }
  }

  void _handleFilterTap() {
    _searchFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    context.read<PayslipProvider>().cancelDebounce();
    final willOpen = !_isFilterOpen;
    setState(() {
      _isFilterOpen = willOpen;
    });
    if (willOpen) {
      context.read<PayslipProvider>().initFilters(source: FilterSource.payslip);
    } else {
      context.read<PayslipProvider>().discardFilterChanges();
    }
  }

  /// Closing without Apply keeps the filters that were last applied.
  void _discardFilters() {
    setState(() => _isFilterOpen = false);
    context.read<PayslipProvider>().discardFilterChanges();
  }

  /// The only place the filter API is called.
  void _applyFilters() {
    final provider = context.read<PayslipProvider>();
    setState(() => _isFilterOpen = false);
    provider.clearNeutralStateSelections();
    if (!provider.isFiltering && provider.hasFilterChanges) {
      provider.applyServerFilters(source: FilterSource.payslip);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PayslipProvider>();
    final historyList = provider.historyPayslips;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencySymbol =
        context
            .read<AccessProvider>()
            .accessDetails
            ?.company
            ?.defaultCompanyCurrency
            ?.symbol ??
        '';

    final yearLabelStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 12.sp,
      height: 16 / 12,
      letterSpacing: 1.2.sp,
      color: isDark ? AppColors.white : const Color(0xFF907067),
    );

    final cardContainerDecoration = BoxDecoration(
      color: isDark ? AppColors.darkCard : Colors.white,
      borderRadius: BorderRadius.circular(12.r),
      boxShadow: [
        BoxShadow(
          color: const Color(0x0D000000),
          offset: const Offset(0, 1),
          blurRadius: 2.r,
        ),
      ],
    );

    final hasActiveFilters =
        provider.hasActiveFilters ||
        provider.selectedMonthIds.isNotEmpty;

    final isSearching = provider.isSearching;
    final isFiltering = provider.isFiltering;
    final isDebouncing = provider.isDebouncing;
    final isInteractionBlocked = provider.isInteractionBlocked;
    final isPaginating =
        provider.isFetchingMoreHistory && !isFiltering && !isSearching;

    final filteredList = historyList;

    final groupedHistory = PayslipYearGrouping.group(filteredList);

    // Show shimmer always while initial loading on screen open, or when empty and fetching
    final showShimmer =
        _isInitialLoading ||
        (filteredList.isEmpty && provider.isFetchingHistory);

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
            final provider = context.read<PayslipProvider>();
            if (provider.hasActiveFilters) {
              provider.resetServerFilters(
                source: FilterSource.payslip,
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
                        AppLocalizations.of(context)?.payslipHistory ??
                        'Payslip History',
                    centerTitle: false,
                    hasBottomRadius: !_isFilterOpen,
                    bottom: _isFilterOpen
                        ? null
                        : Padding(
                            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
                            child: CustomSearchBar(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onChanged: (val) {
                                context
                                    .read<PayslipProvider>()
                                    .onSearchQueryChanged(val);
                              },
                              onSubmitted: (val) {
                                context.read<PayslipProvider>().submitSearch(
                                  val,
                                );
                              },
                              onClearTap: () {
                                _searchController.clear();
                                context.read<PayslipProvider>().clearSearch();
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
                        selectedOption: provider.selectedFilterOption,
                        onOptionSelected: (opt) {
                          provider.selectFilterOption(opt);
                        },
                        options: provider.filterOptions,
                        optionsShimmerCount: 1,
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
                        hasDateFilter: provider.isMonthActive &&
                            provider.selectedMonthIds.isNotEmpty,
                        hasAnyMonthSelected:
                            provider.selectedMonthIds.isNotEmpty,
                        isMonthActive: provider.isMonthActive,
                        onMonthToggled: (m) {
                          provider.toggleMonth(m);
                        },
                        onSelectMonth: provider.selectMonthOption,
                        onClearMonthSelection: provider.clearMonthSelection,
                        onDeactivateMonth: provider.deactivateMonthFilter,
                        customRangeAvailable: provider.customRangeAvailable,
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
                            ? Padding(
                                padding: EdgeInsets.all(16.w),
                                child: Shimmer.fromColors(
                                  baseColor: AppColors.shimmerBase(isDark),
                                  highlightColor: AppColors.shimmerHighlight(
                                    isDark,
                                  ),
                                  child: SingleChildScrollView(
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${DateTime.now().year}',
                                          style: yearLabelStyle,
                                        ),
                                        SizedBox(height: 10.h),
                                        Container(
                                          decoration: cardContainerDecoration,
                                          child: Column(
                                            children: List.generate(
                                              6,
                                              (index) => PayslipHistoryItem(
                                                monthLabel: 'JAN',
                                                yearLabel: '26',
                                                title: 'Payslip Loading...',
                                                subtitle: 'Net Pay',
                                                amount: '${currencySymbol}0.00',
                                                hasTopBorder: index > 0,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : filteredList.isEmpty
                            ? PayslipEmptyState(
                                searchQuery: provider.currentSearchQuery,
                                hasActiveFilters: hasActiveFilters,
                                defaultTitle: AppLocalizations.of(
                                  context,
                                )?.emptyPayslip,
                                defaultSubtitle:
                                    provider.errorMessage ??
                                    AppLocalizations.of(
                                      context,
                                    )?.noHistoryAvailable,
                              )
                            : RefreshIndicator(
                                onRefresh: () =>
                                    provider.fetchInitialHistoryPayslips(
                                      isRefresh: true,
                                    ),
                                child: AbsorbPointer(
                                  absorbing: isInteractionBlocked,
                                  child: AnimatedOpacity(
                                    opacity: isInteractionBlocked ? 0.55 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: SingleChildScrollView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      controller: _scrollController,
                                  padding: EdgeInsets.only(
                                    top: 14.h,
                                    left: 16.w,
                                    right: 16.w,
                                    bottom: 16.h,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ...groupedHistory.map((section) {
                                        final items = section.payslips;

                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              section.label.toUpperCase(),
                                              style: yearLabelStyle,
                                            ),
                                            SizedBox(height: 10.h),
                                            Container(
                                              decoration:
                                                  cardContainerDecoration,
                                              child: Column(
                                                children: items.asMap().entries.map((
                                                  e,
                                                ) {
                                                  final index = e.key;
                                                  final item = e.value;

                                                  String monthLabel = '';
                                                  String yearLabel = '';
                                                  String subtitle = '';
                                                  if (item
                                                      .distributedDate
                                                      .isNotEmpty) {
                                                    final dt =
                                                        DateTime.tryParse(
                                                          item.distributedDate,
                                                        );
                                                    if (dt != null) {
                                                      subtitle =
                                                          AppLocalizations.of(
                                                            context,
                                                          )?.distributedDate(
                                                            AppDateFormatter.mmmDd(
                                                              dt,
                                                            ),
                                                          ) ??
                                                          'Payment: ${AppDateFormatter.mmmDd(dt)}';
                                                    }
                                                  }

                                                  final labelDateStr =
                                                      item.dateTo.isNotEmpty
                                                      ? item.dateTo
                                                      : item.dateFrom;
                                                  if (labelDateStr.isNotEmpty) {
                                                    final dt =
                                                        DateTime.tryParse(
                                                          labelDateStr,
                                                        );
                                                    if (dt != null) {
                                                      monthLabel =
                                                          AppDateFormatter.mmmUppercase(
                                                            dt,
                                                          );
                                                      yearLabel =
                                                          (dt.year % 100)
                                                              .toString()
                                                              .padLeft(2, '0');
                                                    }
                                                  }

                                                  if (yearLabel.isEmpty &&
                                                      item.period.isNotEmpty) {
                                                    final match = RegExp(
                                                      r'\b\d{4}\b',
                                                    ).firstMatch(item.period);
                                                    if (match != null) {
                                                      final fullYear = match
                                                          .group(0)!;
                                                      yearLabel =
                                                          fullYear.length >= 2
                                                          ? fullYear.substring(
                                                              fullYear.length -
                                                                  2,
                                                            )
                                                          : fullYear;
                                                    }
                                                    if (monthLabel.isEmpty) {
                                                      final monthMatch = RegExp(
                                                        r'[A-Za-z]+',
                                                      ).firstMatch(item.period);
                                                      if (monthMatch != null) {
                                                        final mStr = monthMatch
                                                            .group(0)!;
                                                        monthLabel =
                                                            mStr.length >= 3
                                                            ? mStr
                                                                  .substring(
                                                                    0,
                                                                    3,
                                                                  )
                                                                  .toUpperCase()
                                                            : mStr.toUpperCase();
                                                      }
                                                    }
                                                  }

                                                  return IgnorePointer(
                                                    ignoring:
                                                        isSearching ||
                                                        isDebouncing,
                                                    child: PayslipHistoryItem(
                                                      monthLabel: monthLabel,
                                                      yearLabel: yearLabel,
                                                      title: item.period,
                                                      subtitle: subtitle,
                                                      amount: item.netPay != null
                                                          ? '$currencySymbol${item.netPay}'
                                                          : '${currencySymbol}0.00',
                                                      hasTopBorder: index > 0,
                                                      onTap: () {
                                                        final provider = context
                                                            .read<
                                                              PayslipProvider
                                                            >();
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) =>
                                                                ChangeNotifierProvider.value(
                                                                  value:
                                                                      provider,
                                                                  child: PayslipDetailsScreen(
                                                                    payslipItem:
                                                                        item,
                                                                  ),
                                                                ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                            SizedBox(height: 24.h),
                                          ],
                                        );
                                      }),
                                      if (isPaginating) const AppPaginationLoader(),
                                    ],
                                  ),
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
