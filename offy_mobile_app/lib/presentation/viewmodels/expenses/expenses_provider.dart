import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:office_app/domain/usecases/delete_log_note_usecase.dart';
import 'package:office_app/domain/usecases/update_log_note_usecase.dart';
import '../../../domain/usecases/get_expense_summary_usecase.dart';
import '../../../domain/usecases/get_expenses_list_usecase.dart';
import '../../../domain/usecases/get_expense_categories_usecase.dart';
import '../../../domain/usecases/submit_expense_usecase.dart';
import '../../../domain/usecases/delete_expense_usecase.dart';
import '../../../domain/usecases/get_log_notes_usecase.dart';
import '../../../domain/usecases/create_log_note_usecase.dart';
import '../../../domain/usecases/get_expense_filter_options_usecase.dart';
import '../../../domain/usecases/get_expense_filter_content_usecase.dart';
import '../../../domain/usecases/apply_expense_filter_usecase.dart';
import '../../../data/models/expense_response_model.dart';
import '../../../data/models/expense_category_model.dart';
import '../../../data/models/filter_model.dart';
import '../../../data/models/log_note_model.dart';

import '../../../core/base/session_provider.dart';
import '../../../core/errors/api_error_handler.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/lost_submission_checker.dart';

class ExpensesProvider extends SessionProvider {
  final GetExpenseSummaryUseCase getExpenseSummaryUseCase;
  final GetExpensesListUseCase getExpensesListUseCase;
  final GetExpenseCategoriesUseCase getExpenseCategoriesUseCase;
  final SubmitExpenseUseCase submitExpenseUseCase;
  final DeleteExpenseUseCase deleteExpenseUseCase;
  final GetLogNotesUseCase getLogNotesUseCase;
  final CreateLogNoteUseCase createLogNoteUseCase;
  final UpdateLogNoteUseCase updateLogNoteUseCase;
  final DeleteLogNoteUseCase deleteLogNoteUseCase;
  final GetExpenseFilterOptionsUseCase getExpenseFilterOptionsUseCase;
  final GetExpenseFilterContentUseCase getExpenseFilterContentUseCase;
  final ApplyExpenseFilterUseCase applyExpenseFilterUseCase;

  ExpensesProvider({
    required this.getExpenseSummaryUseCase,
    required this.getExpensesListUseCase,
    required this.getExpenseCategoriesUseCase,
    required this.submitExpenseUseCase,
    required this.deleteExpenseUseCase,
    required this.getLogNotesUseCase,
    required this.createLogNoteUseCase,
    required this.updateLogNoteUseCase,
    required this.deleteLogNoteUseCase,
    required this.getExpenseFilterOptionsUseCase,
    required this.getExpenseFilterContentUseCase,
    required this.applyExpenseFilterUseCase,
    super.sessionResetService,
  });

  @override
  void resetState() {
    _debounceTimer?.cancel();
    _isSearching = false;
    _isFiltering = false;
    _currentSearchQuery = '';
    _activeFilters.clear();
    _searchFilterRequestId = 0;
    _activeSearchRequestId = 0;
    _hasLoadedInitialData = false;
    _isFetchingCategories = false;
    _categories = [];
    _summary = null;
    _allExpenses = [];
    _expenseGroups = [];
    _currentPage = 1;
    _hasMore = true;
    _expenseDetails.clear();
    _expenseLogs.clear();
    _isLoading = false;
    _isSubmitting = false;
    _isFetchingList = false;
    _isFetchingMore = false;
    _isLoadingLogs = false;
    _isAddingLogNote = false;
    _errorMessage = null;
    _isFetchingFilterOptions = false;
    _filterOptions = [];
    _selectedFilterOption = FilterOption.month;
    _isFetchingFilterContent = false;
    _cachedFilterContent.clear();
    _cachedMonthBucketItems.clear();
    _monthBuckets = [];
    _selectedMonthBucket = 'recent';
    _appliedMonthBucket = 'recent';
    _currentMonthItems = [];
    _currentCategoryItems = [];
    _selectedMonthIds.clear();
    _selectedCategoryIds.clear();
    _selectedDateRange = null;
    _isCustomRangeActive = false;
    _filterContentRequestId = 0;
    _monthBucketRequestId = 0;
    _filterOptionsFuture = null;
    _isInitialized = false;
    _inFlightApplyFilters = null;
    _inFlightResetFilters = null;
    ++_filterOperationId;
    notifyListeners();
  }

  // State for categories
  bool _isFetchingCategories = false;
  bool get isFetchingCategories => _isFetchingCategories;

  List<ExpenseCategoryModel> _categories = [];
  List<ExpenseCategoryModel> get categories => _categories;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  ExpenseSummaryModel? _summary;
  ExpenseSummaryModel? get summary => _summary;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingLogs = false;
  bool get isLoadingLogs => _isLoadingLogs;

  bool _isAddingLogNote = false;
  bool get isAddingLogNote => _isAddingLogNote;

  bool _isSubmittingLogNote = false;
  bool get isSubmittingLogNote => _isSubmittingLogNote;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Search & Filter state
  bool _isSearching = false;
  bool get isSearching => _isSearching;

  bool _isFiltering = false;
  bool get isFiltering => _isFiltering;

  bool get isDebouncing => _debounceTimer?.isActive ?? false;

  bool get isInteractionBlocked => _isSearching || _isFiltering || isDebouncing;

  void cancelDebounce() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer?.cancel();
      notifyListeners();
    }
  }

  String _currentSearchQuery = '';
  String get currentSearchQuery => _currentSearchQuery;

  final Map<String, dynamic> _activeFilters = {};
  Map<String, dynamic> get activeFilters => Map.unmodifiable(_activeFilters);

  bool _isMonthActive = false;
  bool get isMonthActive => _isMonthActive;

  bool get hasSearchQuery => _currentSearchQuery.trim().isNotEmpty;
  bool get hasActiveFilters =>
      _activeFilters.isNotEmpty ||
      (_isMonthActive && selectedMonthIds.isNotEmpty) ||
      selectedCategoryIds.isNotEmpty ||
      selectedStatusIds.isNotEmpty ||
      (isCustomRangeActive && selectedDateRange != null);

  bool isOptionActive(FilterOption option) {
    switch (option) {
      case FilterOption.month:
      case FilterOption.dateRange:
        return isCustomRangeActive
            ? (selectedDateRange != null)
            : (_isMonthActive && selectedMonthIds.isNotEmpty);
      case FilterOption.category:
        return selectedCategoryIds.isNotEmpty;
      case FilterOption.leaveType:
        return false;
      case FilterOption.status:
        return selectedStatusIds.isNotEmpty;
    }
  }

  // Applied Filter Snapshot (for deep dirty checking)
  Set<String> _snapshotAppliedMonths = {};
  Set<int> _snapshotAppliedCategoryIds = {};
  Set<String> _snapshotAppliedStatusIds = {};
  DateTimeRange? _snapshotAppliedDateRange;
  bool _snapshotAppliedIsCustomRange = false;
  bool _snapshotAppliedIsMonthActive = false;

  void _snapshotAppliedFilters() {
    _snapshotAppliedMonths = Set<String>.from(_selectedMonthIds);
    _snapshotAppliedCategoryIds = Set<int>.from(_selectedCategoryIds);
    _snapshotAppliedStatusIds = Set<String>.from(_selectedStatusIds);
    _snapshotAppliedDateRange = _selectedDateRange;
    _snapshotAppliedIsCustomRange = _isCustomRangeActive;
    _snapshotAppliedIsMonthActive = _isMonthActive;
  }

  bool get hasFilterChanges {
    if (_isCustomRangeActive != _snapshotAppliedIsCustomRange) return true;
    if (_isMonthActive != _snapshotAppliedIsMonthActive) return true;
    if (_isCustomRangeActive) {
      if (_selectedDateRange?.start != _snapshotAppliedDateRange?.start ||
          _selectedDateRange?.end != _snapshotAppliedDateRange?.end) {
        return true;
      }
    } else if (_isMonthActive) {
      if (!setEquals(_selectedMonthIds, _snapshotAppliedMonths)) return true;
    }
    if (!setEquals(_selectedCategoryIds, _snapshotAppliedCategoryIds)) {
      return true;
    }
    if (!setEquals(_selectedStatusIds, _snapshotAppliedStatusIds)) {
      return true;
    }
    return false;
  }

  /// Back without Apply: restores the last applied selections (no API call).
  void discardFilterChanges() {
    _selectedMonthIds
      ..clear()
      ..addAll(_snapshotAppliedMonths);
    _selectedCategoryIds
      ..clear()
      ..addAll(_snapshotAppliedCategoryIds);
    _selectedStatusIds
      ..clear()
      ..addAll(_snapshotAppliedStatusIds);
    _selectedDateRange = _snapshotAppliedDateRange;
    _isCustomRangeActive = _snapshotAppliedIsCustomRange;
    _isMonthActive = _snapshotAppliedIsMonthActive;
    notifyListeners();
  }

  /// Reset button: clears the selections only; nothing is sent until Apply.
  void clearFilterSelections() {
    _selectedMonthIds.clear();
    _selectedCategoryIds.clear();
    _selectedStatusIds.clear();
    _selectedDateRange = null;
    _isCustomRangeActive = false;
    _isMonthActive = false;
    notifyListeners();
  }

  Future<FilterOptionsResponseModel>? _filterOptionsFuture;

  Future<FilterOptionsResponseModel> _fetchFilterOptionsDeduped({
    required FilterSource source,
  }) {
    if (_filterOptionsFuture != null) {
      return _filterOptionsFuture!;
    }
    final future = getExpenseFilterOptionsUseCase(source: source);
    _filterOptionsFuture = future;
    return future.whenComplete(() {
      _filterOptionsFuture = null;
    });
  }

  /// Silently synchronizes active filters from the server on startup so that
  /// [hasActiveFilters] reflects the true state and the indicator dot displays immediately.
  Future<void> syncActiveFilters({
    FilterSource source = FilterSource.expense,
  }) async {
    try {
      final response = await _fetchFilterOptionsDeduped(source: source);
      if (_isInitialized) return;
      final data = response.data;
      if (data != null) {
        _filterOptions = List<FilterOptionItemModel>.from(data.options);
        final monthIdx = _filterOptions.indexWhere(
          (o) => o.filterOption == FilterOption.month,
        );
        if (monthIdx > 0) {
          final monthOption = _filterOptions.removeAt(monthIdx);
          _filterOptions.insert(0, monthOption);
        }
        final active = data.active;
        if (active != null) {
          _isInitialized = true;
          _selectedCategoryIds.clear();
          if (active.categoryIds.isNotEmpty) {
            _selectedCategoryIds.addAll(active.categoryIds);
          }
          _selectedStatusIds.clear();
          if (active.statusIds.isNotEmpty) {
            _selectedStatusIds.addAll(active.statusIds);
          }
          if (active.parsedDateRange != null) {
            _selectedDateRange = active.parsedDateRange;
            _isCustomRangeActive = true;
            _isMonthActive = false;
          } else {
            _selectedDateRange = null;
            _isCustomRangeActive = false;
            _isMonthActive = active.monthIds.isNotEmpty;
            _selectedMonthIds.clear();
            if (active.monthIds.isNotEmpty) {
              _selectedMonthIds.addAll(active.monthIds);
            }
          }
        }
        _snapshotAppliedFilters();
        notifyListeners();
      }
    } catch (e) {
      // Non-blocking background sync failures should not disrupt UI display
      debugPrint('ExpensesProvider.syncActiveFilters failed: $e');
    }
  }

  int _searchFilterRequestId = 0;
  int _activeSearchRequestId = 0;
  Timer? _debounceTimer;

  bool _hasLoadedInitialData = false;
  bool get hasLoadedInitialData => _hasLoadedInitialData;

  // Advanced Server Filter State
  bool _isInitialized = false;
  bool _isFetchingFilterOptions = false;
  bool get isFetchingFilterOptions => _isFetchingFilterOptions;

  List<FilterOptionItemModel> _filterOptions = [];
  List<FilterOptionItemModel> get filterOptions => _filterOptions;

  FilterOption _selectedFilterOption = FilterOption.month;
  FilterOption get selectedFilterOption => _selectedFilterOption;

  bool _isFetchingFilterContent = false;
  bool get isFetchingFilterContent => _isFetchingFilterContent;

  final Map<FilterOption, FilterContentResponseModel> _cachedFilterContent = {};
  final Map<String, List<FilterItemModel>> _cachedMonthBucketItems = {};

  List<FilterBucketModel> _monthBuckets = [];
  List<FilterBucketModel> get monthBuckets => _monthBuckets;

  String _selectedMonthBucket = 'recent';
  String get selectedMonthBucket => _selectedMonthBucket;

  String _appliedMonthBucket = 'recent';
  String get appliedMonthBucket => _appliedMonthBucket;

  String get firstBucketKey =>
      _monthBuckets.firstOrNull?.key.toLowerCase() ?? 'recent';

  List<FilterItemModel> _currentMonthItems = [];
  List<FilterItemModel> get currentMonthItems => _currentMonthItems;

  List<FilterItemModel> _currentCategoryItems = [];
  List<FilterItemModel> get currentCategoryItems => _currentCategoryItems;

  List<FilterItemModel> _currentStatusItems = [];
  List<FilterItemModel> get currentStatusItems => _currentStatusItems;

  bool _isCustomRangeAvailable = true;
  bool get isCustomRangeAvailable => _isCustomRangeAvailable;

  final Set<String> _selectedMonthIds = {};
  Set<String> get selectedMonthIds => Set.unmodifiable(_selectedMonthIds);
  Set<String> get currentBucketSelectedMonthIds =>
      Set.unmodifiable(_selectedMonthIds);

  Set<String> get bucketsWithSelection {
    final result = <String>{};
    if (_selectedMonthIds.isEmpty) return result;

    for (final bucket in _monthBuckets) {
      final bKey = bucket.key.toLowerCase();
      final items = _cachedMonthBucketItems[bKey];
      if (items != null) {
        if (items.any((item) => _selectedMonthIds.contains(item.idAsString))) {
          result.add(bKey);
        }
      } else {
        if (bKey != 'recent' &&
            _selectedMonthIds.any((id) => id.toLowerCase().contains(bKey))) {
          result.add(bKey);
        }
      }
    }
    return result;
  }

  String? findFirstBucketWithSelection() {
    if (_selectedMonthIds.isEmpty || _monthBuckets.isEmpty) return null;

    // 1. Cross-reference only against the Recent item list
    final recentItems = _cachedMonthBucketItems['recent'];
    if (recentItems == null) {
      // While recent items are loading, remain on 'recent' to prevent jitter
      return 'recent';
    }
    final hasRecentSelection = recentItems.any(
      (item) => _selectedMonthIds.contains(item.idAsString),
    );
    if (hasRecentSelection) {
      return 'recent';
    }

    // 2. Otherwise, check buckets in order (e.g. 2026, 2025, 2024...)
    for (final b in _monthBuckets) {
      final bKey = b.key.toLowerCase();
      if (bKey == 'recent') continue;

      final items = _cachedMonthBucketItems[bKey];
      if (items != null) {
        if (items.any((item) => _selectedMonthIds.contains(item.idAsString))) {
          return bKey;
        }
      } else {
        if (_selectedMonthIds.any((id) => id.toLowerCase().contains(bKey))) {
          return bKey;
        }
      }
    }
    return null;
  }

  final Set<int> _selectedCategoryIds = {};
  Set<int> get selectedCategoryIds => Set.unmodifiable(_selectedCategoryIds);

  final Set<String> _selectedStatusIds = {};
  Set<String> get selectedStatusIds => Set.unmodifiable(_selectedStatusIds);

  DateTimeRange? _selectedDateRange;
  DateTimeRange? get selectedDateRange => _selectedDateRange;

  bool _isCustomRangeActive = false;
  bool get isCustomRangeActive => _isCustomRangeActive;

  void setCustomDateRange(DateTimeRange? range) {
    _selectedDateRange = range;
    _isCustomRangeActive = range != null;
    if (_isCustomRangeActive) {
      _isMonthActive = false;
    } else {
      _isMonthActive = selectedMonthIds.isNotEmpty;
    }
    notifyListeners();
  }

  void activateCustomDateRange() {
    if (_selectedDateRange != null) {
      _isCustomRangeActive = true;
      _isMonthActive = false;
      notifyListeners();
    }
  }

  void clearCustomDateRange() {
    _selectedDateRange = null;
    _isCustomRangeActive = false;
    _isMonthActive = selectedMonthIds.isNotEmpty;
    notifyListeners();
  }

  void deactivateMonthFilter() {
    _isMonthActive = false;
    _isCustomRangeActive = false;
    notifyListeners();
  }

  void clearNeutralStateSelections() {
    if (!_isCustomRangeActive && _selectedMonthIds.isEmpty) {
      _isMonthActive = false;
    }
    if (!_isCustomRangeActive && !_isMonthActive) {
      _selectedMonthIds.clear();
      _selectedDateRange = null;
      notifyListeners();
    }
  }

  void clearMonthSelection() {
    _selectedMonthIds.clear();
    _isMonthActive = false;
    notifyListeners();
  }

  void selectMonthOption() {
    _isCustomRangeActive = false;
    _isMonthActive = true;
    final firstBucket = findFirstBucketWithSelection();
    if (firstBucket != null && firstBucket != _selectedMonthBucket) {
      selectMonthBucket(firstBucket);
    } else if (firstBucket == null && _monthBuckets.isNotEmpty) {
      // No months selected — default to first bucket chip
      final firstKey = firstBucketKey;
      if (firstKey != _selectedMonthBucket) {
        selectMonthBucket(firstKey);
      }
    }
    notifyListeners();
  }

  int _filterContentRequestId = 0;

  // Pagination state
  List<RecentExpenseModel> _allExpenses = [];
  List<RecentExpenseModel> get allExpenses => _allExpenses;

  List<ExpenseGroupModel> _expenseGroups = [];
  List<ExpenseGroupModel> get expenseGroups => _expenseGroups;

  bool _isFetchingList = false;
  bool get isFetchingList => _isFetchingList;

  bool _isFetchingMore = false;
  bool get isFetchingMore => _isFetchingMore;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  int _currentPage = 1;

  Future<void> fetchExpenseSummary() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await getExpenseSummaryUseCase();
      _summary = response;
      for (final expense in response.recentExpenses) {
        _expenseDetails[expense.id] = expense;
      }
    } on AppException catch (e) {
      _errorMessage = e.message ?? e.toString();
    } catch (e) {
      _errorMessage =
          ApiErrorHandler.handle(e).message ??
          ApiErrorHandler.handle(e).toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchInitialExpensesList({bool isRefresh = false}) async {
    final requestId = ++_searchFilterRequestId;
    _activeSearchRequestId++;
    _isSearching = false;
    _currentPage = 1;
    _hasMore = true;
    if (!_hasLoadedInitialData) {
      _allExpenses = [];
      _expenseGroups = [];
    }
    _isFetchingList = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await getExpensesListUseCase(
        page: _currentPage,
        limit: 20,
        search: _currentSearchQuery.isNotEmpty ? _currentSearchQuery : null,
        filters: _activeFilters.isNotEmpty ? _activeFilters : null,
        forceRefresh: isRefresh,
      );
      if (requestId != _searchFilterRequestId) return;
      _allExpenses = response.items.isNotEmpty
          ? response.items
          : response.groups.expand((g) => g.expenses).toList();
      _expenseGroups = response.groups;
      for (final expense in _allExpenses) {
        _expenseDetails[expense.id] = expense;
      }
      _hasMore = response.pagination.hasNext;
      _hasLoadedInitialData = true;
    } on AppException catch (e) {
      if (requestId != _searchFilterRequestId) return;
      _errorMessage = e.message ?? e.toString();
    } catch (e) {
      if (requestId != _searchFilterRequestId) return;
      _errorMessage =
          ApiErrorHandler.handle(e).message ??
          ApiErrorHandler.handle(e).toString();
    } finally {
      if (requestId == _searchFilterRequestId) {
        _isFetchingList = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchMoreExpenses() async {
    if (_isFetchingList || _isSearching || _isFiltering || !_hasMore) return;

    final requestId = _searchFilterRequestId;
    _isFetchingList = true;
    _isFetchingMore = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final response = await getExpensesListUseCase(
        page: nextPage,
        limit: 20,
        search: _currentSearchQuery.isNotEmpty ? _currentSearchQuery : null,
        filters: _activeFilters.isNotEmpty ? _activeFilters : null,
      );
      if (requestId != _searchFilterRequestId) return;
      _currentPage = nextPage;
      final newItems = response.items.isNotEmpty
          ? response.items
          : response.groups.expand((g) => g.expenses).toList();
      _allExpenses.addAll(newItems);
      _mergeGroups(response.groups);
      for (final expense in newItems) {
        _expenseDetails[expense.id] = expense;
      }
      _hasMore = response.pagination.hasNext;
    } on AppException catch (e) {
      if (requestId != _searchFilterRequestId) return;
      _errorMessage = e.message ?? e.toString();
    } catch (e) {
      if (requestId != _searchFilterRequestId) return;
      _errorMessage =
          ApiErrorHandler.handle(e).message ??
          ApiErrorHandler.handle(e).toString();
    } finally {
      if (requestId == _searchFilterRequestId) {
        _isFetchingList = false;
        _isFetchingMore = false;
        notifyListeners();
      }
    }
  }

  void _mergeGroups(List<ExpenseGroupModel> newGroups) {
    if (newGroups.isEmpty) return;
    for (final newGroup in newGroups) {
      final existingIndex = _expenseGroups.indexWhere(
        (g) => g.timeline == newGroup.timeline,
      );
      if (existingIndex != -1) {
        final existingGroup = _expenseGroups[existingIndex];
        final existingIds = existingGroup.expenses.map((e) => e.id).toSet();
        final mergedExpenses = List<RecentExpenseModel>.from(
          existingGroup.expenses,
        );
        for (final exp in newGroup.expenses) {
          if (!existingIds.contains(exp.id)) {
            mergedExpenses.add(exp);
            existingIds.add(exp.id);
          }
        }
        _expenseGroups[existingIndex] = ExpenseGroupModel(
          timeline: existingGroup.timeline,
          totalAmount: newGroup.totalAmount != 0.0
              ? newGroup.totalAmount
              : existingGroup.totalAmount,
          totalAmountDisplay: newGroup.totalAmountDisplay.isNotEmpty
              ? newGroup.totalAmountDisplay
              : existingGroup.totalAmountDisplay,
          currency: newGroup.currency.isNotEmpty
              ? newGroup.currency
              : existingGroup.currency,
          expenses: mergedExpenses,
        );
      } else {
        _expenseGroups.add(newGroup);
      }
    }
  }

  void onSearchQueryChanged(
    String query, {
    Duration debounceDuration = const Duration(milliseconds: 300),
  }) {
    final trimmed = query.trim();
    if (trimmed == _currentSearchQuery) {
      if (_debounceTimer?.isActive ?? false) {
        _debounceTimer?.cancel();
        notifyListeners();
      }
      return;
    }

    _debounceTimer?.cancel();
    if (trimmed.isEmpty) {
      clearSearch();
      return;
    }

    _debounceTimer = Timer(debounceDuration, () {
      submitSearch(trimmed);
    });
    notifyListeners();
  }

  Future<void> submitSearch(String query) async {
    final wasDebouncing = _debounceTimer?.isActive ?? false;
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed == _currentSearchQuery && !_isSearching && !_isFiltering) {
      if (wasDebouncing) {
        notifyListeners();
      }
      return;
    }

    _currentSearchQuery = trimmed;
    await _executeSearchOrFilter(isSearchOperation: true);
  }

  Future<void> clearSearch({bool executeFetch = true}) async {
    final wasDebouncing = _debounceTimer?.isActive ?? false;
    _debounceTimer?.cancel();
    if (_currentSearchQuery.isEmpty) {
      if (wasDebouncing) {
        notifyListeners();
      }
      return;
    }
    _currentSearchQuery = '';
    if (executeFetch) {
      await _executeSearchOrFilter(isSearchOperation: true);
    } else {
      notifyListeners();
    }
  }

  Future<void> applyFilters(Map<String, dynamic> filters) async {
    _activeFilters.clear();
    _activeFilters.addAll(filters);
    await _executeSearchOrFilter(isSearchOperation: false);
  }

  Future<void> resetFilters() async {
    if (_activeFilters.isEmpty) return;
    _activeFilters.clear();
    await _executeSearchOrFilter(isSearchOperation: false);
  }

  Future<void> initFilters({FilterSource source = FilterSource.expense}) async {
    _selectedFilterOption = FilterOption.month;
    _currentMonthItems = [];
    _currentCategoryItems = [];
    _currentStatusItems = [];
    _monthBuckets = [];
    _cachedFilterContent.clear();
    _cachedMonthBucketItems.clear();
    _isFetchingFilterOptions = true;
    _isFetchingFilterContent = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _fetchFilterOptionsDeduped(source: source);
      final data = response.data;
      if (data != null) {
        _filterOptions = List<FilterOptionItemModel>.from(data.options);
        final monthIdx = _filterOptions.indexWhere(
          (o) => o.filterOption == FilterOption.month,
        );
        if (monthIdx > 0) {
          final monthOption = _filterOptions.removeAt(monthIdx);
          _filterOptions.insert(0, monthOption);
        }
        final active = data.active;
        if (!_isInitialized && active != null) {
          _isInitialized = true;
          _selectedCategoryIds.clear();
          if (active.categoryIds.isNotEmpty) {
            _selectedCategoryIds.addAll(active.categoryIds);
          }
          _selectedStatusIds.clear();
          if (active.statusIds.isNotEmpty) {
            _selectedStatusIds.addAll(active.statusIds);
          }
          if (active.parsedDateRange != null) {
            _selectedDateRange = active.parsedDateRange;
            _isCustomRangeActive = true;
            _isMonthActive = false;
          } else {
            _selectedDateRange = null;
            _isCustomRangeActive = false;
            _selectedMonthIds.clear();
            _isMonthActive = active.monthIds.isNotEmpty;
            if (active.monthIds.isNotEmpty) {
              _selectedMonthIds.addAll(active.monthIds);
            } else {
              _appliedMonthBucket = firstBucketKey;
              _selectedMonthBucket = firstBucketKey;
            }
          }
          _snapshotAppliedFilters();
        }
      }

      final firstActiveOption = _filterOptions
          .map((o) => o.filterOption)
          .cast<FilterOption?>()
          .firstWhere(
            (opt) => opt != null && isOptionActive(opt),
            orElse: () => null,
          );

      if (firstActiveOption != null) {
        _selectedFilterOption = firstActiveOption;
      } else if (_filterOptions.any(
        (o) => o.filterOption == FilterOption.month,
      )) {
        _selectedFilterOption = FilterOption.month;
      } else if (_filterOptions.isNotEmpty) {
        _selectedFilterOption = _filterOptions.first.filterOption;
      }
    } on AppException catch (e) {
      _errorMessage = e.message ?? e.toString();
      _isFetchingFilterContent = false;
    } catch (e) {
      _errorMessage =
          ApiErrorHandler.handle(e).message ??
          ApiErrorHandler.handle(e).toString();
      _isFetchingFilterContent = false;
    } finally {
      _isFetchingFilterOptions = false;
      notifyListeners();
    }

    final firstBucket =
        (_selectedFilterOption == FilterOption.month ||
            _selectedFilterOption == FilterOption.dateRange)
        ? findFirstBucketWithSelection()
        : null;

    await fetchFilterContent(
      source: source,
      option: _selectedFilterOption,
      bucket: firstBucket,
    );
  }

  void _prefetchRemainingMonthBuckets({
    FilterSource source = FilterSource.expense,
  }) {
    for (final b in _monthBuckets) {
      final k = b.key.toLowerCase();
      if (!_cachedMonthBucketItems.containsKey(k)) {
        getExpenseFilterContentUseCase(
              source: source,
              option: FilterOption.month,
              bucket: k,
            )
            .then((res) {
              final items = res.data?.items ?? [];
              _cachedMonthBucketItems[k] = items;
              if (_selectedMonthBucket == k && _currentMonthItems.isEmpty) {
                _currentMonthItems = items;
              }
              notifyListeners();
            })
            .catchError((_) {});
      }
    }
  }

  Future<void> fetchFilterContent({
    FilterSource source = FilterSource.expense,
    required FilterOption option,
    String? bucket,
  }) async {
    if (option == FilterOption.month) {
      final requestId = ++_filterContentRequestId;
      if (!_cachedFilterContent.containsKey(FilterOption.month)) {
        _isFetchingFilterContent = true;
        notifyListeners();

        try {
          final res = await getExpenseFilterContentUseCase(
            source: source,
            option: FilterOption.month,
          );
          if (requestId != _filterContentRequestId) return;
          _cachedFilterContent[FilterOption.month] = res;
          _monthBuckets = res.data?.buckets ?? [];
          final recentIdx = _monthBuckets.indexWhere(
            (b) => b.key.toLowerCase() == 'recent',
          );
          if (recentIdx > 0) {
            final recentBucket = _monthBuckets.removeAt(recentIdx);
            _monthBuckets.insert(0, recentBucket);
          }
          _isCustomRangeAvailable = res.data?.customRangeAvailable ?? true;
          final initialBucket =
              (res.data?.bucket != null && res.data!.bucket!.isNotEmpty)
              ? res.data!.bucket!.toLowerCase()
              : 'recent';
          final initialItems = res.data?.items ?? [];
          if (initialItems.isNotEmpty) {
            _cachedMonthBucketItems[initialBucket] = initialItems;
          }
        } on AppException catch (e) {
          if (requestId != _filterContentRequestId) return;
          _errorMessage = e.message ?? e.toString();
        } catch (e) {
          if (requestId != _filterContentRequestId) return;
          _errorMessage =
              ApiErrorHandler.handle(e).message ??
              ApiErrorHandler.handle(e).toString();
        } finally {
          if (requestId == _filterContentRequestId) {
            _isFetchingFilterContent = false;
            notifyListeners();
          }
        }
      } else {
        final res = _cachedFilterContent[FilterOption.month]!;
        _monthBuckets = res.data?.buckets ?? [];
        final recentIdx = _monthBuckets.indexWhere(
          (b) => b.key.toLowerCase() == 'recent',
        );
        if (recentIdx > 0) {
          final recentBucket = _monthBuckets.removeAt(recentIdx);
          _monthBuckets.insert(0, recentBucket);
        }
        _isCustomRangeAvailable = res.data?.customRangeAvailable ?? true;
      }

      if (requestId != _filterContentRequestId) return;

      final firstWithSel = findFirstBucketWithSelection();
      final targetBucket = (bucket != null && bucket.isNotEmpty)
          ? bucket.toLowerCase()
          : (firstWithSel ??
                (_selectedMonthIds.isNotEmpty &&
                        _appliedMonthBucket.isNotEmpty &&
                        _monthBuckets.any(
                          (b) =>
                              b.key.toLowerCase() ==
                              _appliedMonthBucket.toLowerCase(),
                        )
                    ? _appliedMonthBucket.toLowerCase()
                    : firstBucketKey));
      await fetchMonthBucketItems(source: source, bucket: targetBucket);
      if (requestId != _filterContentRequestId) return;
      _prefetchRemainingMonthBuckets(source: source);
      return;
    }

    if (option == FilterOption.category) {
      if (_cachedFilterContent.containsKey(FilterOption.category)) {
        _currentCategoryItems =
            _cachedFilterContent[FilterOption.category]!.data?.items ?? [];
        notifyListeners();
        return;
      }

      final requestId = ++_filterContentRequestId;
      _isFetchingFilterContent = true;
      notifyListeners();

      try {
        final res = await getExpenseFilterContentUseCase(
          source: source,
          option: FilterOption.category,
        );
        _cachedFilterContent[FilterOption.category] = res;
        if (requestId != _filterContentRequestId) return;
        _currentCategoryItems = res.data?.items ?? [];
      } on AppException catch (e) {
        if (requestId != _filterContentRequestId) return;
        _errorMessage = e.message ?? e.toString();
      } catch (e) {
        if (requestId != _filterContentRequestId) return;
        _errorMessage =
            ApiErrorHandler.handle(e).message ??
            ApiErrorHandler.handle(e).toString();
      } finally {
        if (requestId == _filterContentRequestId) {
          _isFetchingFilterContent = false;
          notifyListeners();
        }
      }
      return;
    }

    if (option == FilterOption.status) {
      if (_cachedFilterContent.containsKey(FilterOption.status)) {
        _currentStatusItems =
            _cachedFilterContent[FilterOption.status]!.data?.items ?? [];
        notifyListeners();
        return;
      }

      final requestId = ++_filterContentRequestId;
      _isFetchingFilterContent = true;
      notifyListeners();

      try {
        final res = await getExpenseFilterContentUseCase(
          source: source,
          option: FilterOption.status,
        );
        _cachedFilterContent[FilterOption.status] = res;
        if (requestId != _filterContentRequestId) return;
        _currentStatusItems = res.data?.items ?? [];
      } on AppException catch (e) {
        if (requestId != _filterContentRequestId) return;
        _errorMessage = e.message ?? e.toString();
      } catch (e) {
        if (requestId != _filterContentRequestId) return;
        _errorMessage =
            ApiErrorHandler.handle(e).message ??
            ApiErrorHandler.handle(e).toString();
      } finally {
        if (requestId == _filterContentRequestId) {
          _isFetchingFilterContent = false;
          notifyListeners();
        }
      }
      return;
    }
  }

  int _monthBucketRequestId = 0;

  Future<void> fetchMonthBucketItems({
    FilterSource source = FilterSource.expense,
    required String bucket,
  }) async {
    final normalizedBucket = bucket.toLowerCase();
    _selectedMonthBucket = normalizedBucket;
    final requestId = ++_monthBucketRequestId;

    if (_cachedMonthBucketItems.containsKey(normalizedBucket)) {
      _currentMonthItems = _cachedMonthBucketItems[normalizedBucket]!;
      notifyListeners();
      return;
    }

    _isFetchingFilterContent = true;
    notifyListeners();

    try {
      final res = await getExpenseFilterContentUseCase(
        source: source,
        option: FilterOption.month,
        bucket: normalizedBucket,
      );
      final items = res.data?.items ?? [];
      _cachedMonthBucketItems[normalizedBucket] = items;
      if (requestId != _monthBucketRequestId ||
          normalizedBucket != _selectedMonthBucket) {
        return;
      }
      _currentMonthItems = items;
    } on AppException catch (e) {
      if (requestId != _monthBucketRequestId) return;
      _errorMessage = e.message ?? e.toString();
    } catch (e) {
      if (requestId != _monthBucketRequestId) return;
      _errorMessage =
          ApiErrorHandler.handle(e).message ??
          ApiErrorHandler.handle(e).toString();
    } finally {
      if (requestId == _monthBucketRequestId) {
        if (_selectedFilterOption == FilterOption.month ||
            _selectedFilterOption == FilterOption.dateRange) {
          _isFetchingFilterContent = false;
        }
        notifyListeners();
      }
    }
  }

  Future<void> selectFilterOption(FilterOption option) async {
    if (_selectedFilterOption == option) return;
    _selectedFilterOption = option;
    _monthBucketRequestId++;
    if (!_cachedFilterContent.containsKey(option)) {
      if (option == FilterOption.status) {
        _currentStatusItems = [];
      } else if (option == FilterOption.month ||
          option == FilterOption.dateRange) {
        _currentMonthItems = [];
      } else {
        _currentCategoryItems = [];
      }
      _isFetchingFilterContent = true;
    }
    notifyListeners();
    final firstBucket =
        (option == FilterOption.month || option == FilterOption.dateRange)
        ? findFirstBucketWithSelection()
        : null;
    await fetchFilterContent(option: option, bucket: firstBucket);
  }

  Future<void> selectMonthBucket(String bucketKey) async {
    final normalized = bucketKey.toLowerCase();
    if (_selectedMonthBucket == normalized && _currentMonthItems.isNotEmpty) {
      return;
    }
    await fetchMonthBucketItems(bucket: normalized);
  }

  void toggleMonth(String monthId) {
    _isCustomRangeActive = false;
    if (_selectedMonthIds.contains(monthId)) {
      _selectedMonthIds.remove(monthId);
    } else {
      _selectedMonthIds.add(monthId);
    }
    _isMonthActive = _selectedMonthIds.isNotEmpty;
    notifyListeners();
  }

  void toggleCategory(int categoryId) {
    if (_selectedCategoryIds.contains(categoryId)) {
      _selectedCategoryIds.remove(categoryId);
    } else {
      _selectedCategoryIds.add(categoryId);
    }
    notifyListeners();
  }

  void toggleStatus(String statusId) {
    if (_selectedStatusIds.contains(statusId)) {
      _selectedStatusIds.remove(statusId);
    } else {
      _selectedStatusIds.add(statusId);
    }
    notifyListeners();
  }

  Future<void>? _inFlightApplyFilters;
  int _filterOperationId = 0;

  Future<void> applyServerFilters({
    FilterSource source = FilterSource.expense,
  }) async {
    if (_isFiltering) return;
    if (!hasFilterChanges) return;

    final currentOpId = ++_filterOperationId;
    cancelDebounce();
    _isFiltering = true;
    _errorMessage = null;
    notifyListeners();

    final completer = Completer<void>();
    _inFlightApplyFilters = completer.future;

    AppException? lastAppException;
    Object? lastError;

    try {
      // 1. Date Filter: Apply Date Range or Month sequentially
      try {
        if (_isCustomRangeActive && _selectedDateRange != null) {
          _selectedMonthIds.clear();
          final fromStr = DateFormat(
            'yyyy-MM-dd',
          ).format(_selectedDateRange!.start);
          final toStr = DateFormat(
            'yyyy-MM-dd',
          ).format(_selectedDateRange!.end);
          await applyExpenseFilterUseCase(
            source: source,
            option: FilterOption.dateRange,
            data: {
              'from_date': fromStr,
              'to_date': toStr,
              'start_date': fromStr,
              'end_date': toStr,
            },
          );
        } else if (_isMonthActive && _selectedMonthIds.isNotEmpty) {
          _appliedMonthBucket = _selectedMonthBucket;
          _selectedDateRange = null;
          final allMonthIds = _selectedMonthIds.toList();
          await applyExpenseFilterUseCase(
            source: source,
            option: FilterOption.month,
            data: {'month_ids': allMonthIds},
          );
        } else {
          _selectedMonthIds.clear();
          _selectedDateRange = null;
          _isCustomRangeActive = false;
          _isMonthActive = false;
          _appliedMonthBucket = firstBucketKey;
          _selectedMonthBucket = firstBucketKey;
          await applyExpenseFilterUseCase(
            source: source,
            option: FilterOption.dateRange,
            data: {},
          );
          await applyExpenseFilterUseCase(
            source: source,
            option: FilterOption.month,
            data: {'month_ids': []},
          );
        }
      } on AppException catch (e) {
        lastAppException = e;
      } catch (e) {
        lastError = e;
      }

      if (currentOpId != _filterOperationId) return;

      // 2. Category Filter (executed regardless of date/month outcome)
      try {
        await applyExpenseFilterUseCase(
          source: source,
          option: FilterOption.category,
          data: {'category_ids': _selectedCategoryIds.toList()},
        );
      } on AppException catch (e) {
        lastAppException = e;
      } catch (e) {
        lastError = e;
      }

      if (currentOpId != _filterOperationId) return;

      // 3. Status Filter (executed regardless of date/month outcome)
      try {
        await applyExpenseFilterUseCase(
          source: source,
          option: FilterOption.status,
          data: {'status_ids': _selectedStatusIds.toList()},
        );
      } on AppException catch (e) {
        lastAppException = e;
      } catch (e) {
        lastError = e;
      }

      if (currentOpId != _filterOperationId) return;

      if (lastAppException == null && lastError == null) {
        _snapshotAppliedFilters();
      }
      await fetchInitialExpensesList(isRefresh: true);

      if (lastAppException != null) {
        _errorMessage = lastAppException.message ?? lastAppException.toString();
      } else if (lastError != null) {
        _errorMessage =
            ApiErrorHandler.handle(lastError).message ??
            ApiErrorHandler.handle(lastError).toString();
      }
    } on AppException catch (e) {
      _errorMessage = e.message ?? e.toString();
    } catch (e) {
      _errorMessage =
          ApiErrorHandler.handle(e).message ??
          ApiErrorHandler.handle(e).toString();
    } finally {
      _isFiltering = false;
      _inFlightApplyFilters = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
      notifyListeners();
    }
  }

  Future<void>? _inFlightResetFilters;

  Future<void> resetServerFilters({
    FilterSource source = FilterSource.expense,
    bool executeFetch = true,
  }) async {
    if (_inFlightResetFilters != null) {
      try {
        await _inFlightResetFilters;
      } catch (e) {
        debugPrint(
          'ExpensesProvider: In-flight reset filters completed with error: $e',
        );
      }
      if (executeFetch) {
        await fetchInitialExpensesList(isRefresh: true);
      }
      return;
    }

    final currentResetOpId = ++_filterOperationId;

    if (_inFlightApplyFilters != null) {
      try {
        await _inFlightApplyFilters;
      } catch (e) {
        debugPrint(
          'ExpensesProvider: In-flight apply filters completed with error: $e',
        );
      }
    }

    cancelDebounce();
    _selectedMonthIds.clear();
    _appliedMonthBucket = 'recent';
    _selectedMonthBucket = 'recent';
    _selectedCategoryIds.clear();
    _selectedStatusIds.clear();
    _selectedDateRange = null;
    _isCustomRangeActive = false;
    _isMonthActive = false;
    _isInitialized = false;
    _snapshotAppliedFilters();
    _isFiltering = true;
    _errorMessage = null;
    notifyListeners();

    final completer = Completer<void>();
    _inFlightResetFilters = completer.future;

    try {
      await applyExpenseFilterUseCase(
        source: source,
        option: FilterOption.dateRange,
        data: {},
      );
      await applyExpenseFilterUseCase(
        source: source,
        option: FilterOption.month,
        data: {'month_ids': []},
      );
      await applyExpenseFilterUseCase(
        source: source,
        option: FilterOption.category,
        data: {'category_ids': []},
      );
      await applyExpenseFilterUseCase(
        source: source,
        option: FilterOption.status,
        data: {'status_ids': []},
      );
      if (currentResetOpId == _filterOperationId && executeFetch) {
        await fetchInitialExpensesList(isRefresh: true);
      }
    } on AppException catch (e) {
      _errorMessage = e.message ?? e.toString();
    } catch (e) {
      _errorMessage =
          ApiErrorHandler.handle(e).message ??
          ApiErrorHandler.handle(e).toString();
    } finally {
      _isFiltering = false;
      _inFlightResetFilters = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
      notifyListeners();
    }
  }

  Future<void> clearSearchAndServerFilters({
    FilterSource source = FilterSource.expense,
  }) async {
    if (_isFiltering) return;
    _debounceTimer?.cancel();
    _currentSearchQuery = '';
    await resetServerFilters(source: source);
  }

  Future<void> clearAll() async {
    final wasDebouncing = _debounceTimer?.isActive ?? false;
    _debounceTimer?.cancel();
    if (_currentSearchQuery.isEmpty && _activeFilters.isEmpty) {
      if (wasDebouncing) {
        notifyListeners();
      }
      return;
    }
    _currentSearchQuery = '';
    _activeFilters.clear();
    await _executeSearchOrFilter(isSearchOperation: true);
  }

  Future<void> _executeSearchOrFilter({required bool isSearchOperation}) async {
    final requestId = ++_searchFilterRequestId;
    int? searchId;
    if (isSearchOperation) {
      searchId = ++_activeSearchRequestId;
      _isSearching = true;
    } else {
      _isFiltering = true;
    }
    _currentPage = 1;
    _hasMore = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await getExpensesListUseCase(
        page: _currentPage,
        limit: 20,
        search: _currentSearchQuery.isNotEmpty ? _currentSearchQuery : null,
        filters: _activeFilters.isNotEmpty ? _activeFilters : null,
      );
      if (requestId != _searchFilterRequestId) return;
      _allExpenses = response.items.isNotEmpty
          ? response.items
          : response.groups.expand((g) => g.expenses).toList();
      _expenseGroups = response.groups;
      for (final expense in _allExpenses) {
        _expenseDetails[expense.id] = expense;
      }
      _hasMore = response.pagination.hasNext;
    } on AppException catch (e) {
      if (requestId != _searchFilterRequestId) return;
      _errorMessage = e.message ?? e.toString();
    } catch (e) {
      if (requestId != _searchFilterRequestId) return;
      _errorMessage =
          ApiErrorHandler.handle(e).message ??
          ApiErrorHandler.handle(e).toString();
    } finally {
      if (isSearchOperation) {
        if (searchId == _activeSearchRequestId) {
          _isSearching = false;
        }
      } else {
        if (requestId == _searchFilterRequestId) {
          _isFiltering = false;
        }
      }
      if (requestId == _searchFilterRequestId) {
        notifyListeners();
      }
    }
  }

  Future<void> fetchCategories() async {
    _isFetchingCategories = true;
    notifyListeners();

    try {
      final response = await getExpenseCategoriesUseCase();
      _categories = response;
    } on AppException catch (e) {
      _errorMessage = e.message ?? e.toString();
    } catch (e) {
      _errorMessage =
          ApiErrorHandler.handle(e).message ??
          ApiErrorHandler.handle(e).toString();
    } finally {
      _isFetchingCategories = false;
      notifyListeners();
    }
  }

  Future<bool> submitNewExpense(
    Map<String, String> data,
    List<XFile> files,
  ) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await submitExpenseUseCase(data, files);
      return success;
    } on SubmissionOutcomeUnknownException catch (e) {
      // The connection dropped after the request went out: the expense may
      // or may not exist. Do not resubmit -- check, tell the user, refresh.
      _errorMessage = e.message;
      _checkLostExpenseSubmission(data);
      return false;
    } on AppException catch (e) {
      _errorMessage = e.message ?? e.toString();
      return false;
    } catch (e) {
      _errorMessage =
          ApiErrorHandler.handle(e).message ??
          ApiErrorHandler.handle(e).toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// After a lost reply: is the expense in the newest unfiltered page?
  /// An edit cannot duplicate, so it only refreshes.
  void _checkLostExpenseSubmission(Map<String, String> data) {
    final isEdit = (data['id'] ?? '').isNotEmpty;
    final amount = double.tryParse(data['amount'] ?? '');
    final date = (data['expense_date'] ?? '').replaceAll('/', '-');
    final description = (data['description'] ?? '').trim();
    final categoryId = int.tryParse(data['category_id'] ?? '');
    final categoryName = _categories
        .where((c) => c.id == categoryId)
        .map((c) => c.name)
        .firstOrNull;
    // The API files a blank description under the category's name.
    final title = description.isNotEmpty ? description : categoryName;

    Future<void> refresh() async {
      await Future.wait([
        fetchInitialExpensesList(isRefresh: true),
        fetchExpenseSummary(),
      ]);
    }

    LostSubmissionChecker.start(
      label: (l10n) => l10n?.lostSubmissionExpense ?? 'expense',
      refresh: refresh,
      isSaved: () async {
        if (isEdit || amount == null || title == null) {
          // Nothing reliable to match on: report it as unconfirmed.
          throw StateError('expense cannot be matched');
        }
        final response = await getExpensesListUseCase(
          page: 1,
          limit: 20,
          forceRefresh: true,
        );
        final items = response.items.isNotEmpty
            ? response.items
            : response.groups.expand((g) => g.expenses).toList();
        return items.any(
          (e) =>
              (e.amount - amount).abs() < 0.005 &&
              e.date.startsWith(date) &&
              e.title.trim() == title.trim(),
        );
      },
    );
  }

  Future<bool> deleteExpense(int id) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await deleteExpenseUseCase(id);
      if (success) {
        _allExpenses.removeWhere((e) => e.id == id);
        _expenseGroups = _expenseGroups
            .map((group) {
              return ExpenseGroupModel(
                timeline: group.timeline,
                totalAmount: group.totalAmount,
                totalAmountDisplay: group.totalAmountDisplay,
                currency: group.currency,
                expenses: group.expenses.where((e) => e.id != id).toList(),
              );
            })
            .where((group) => group.expenses.isNotEmpty)
            .toList();
        _expenseDetails.remove(id);
      }
      return success;
    } on AppException catch (e) {
      _errorMessage = e.message ?? e.toString();
      return false;
    } catch (e) {
      _errorMessage =
          ApiErrorHandler.handle(e).message ??
          ApiErrorHandler.handle(e).toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  final Map<int, RecentExpenseModel> _expenseDetails = {};
  final Map<int, List<LogNoteModel>> _expenseLogs = {};
  final Map<int, String?> _expenseLogErrors = {};

  String? getLogErrorForExpense(int expenseId) => _expenseLogErrors[expenseId];

  Future<void> fetchExpenseLogs(int expenseId) async {
    _isLoadingLogs = true;
    _expenseLogErrors[expenseId] = null;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await getLogNotesUseCase('expense', expenseId);
      if (response.record != null) {
        _expenseDetails[expenseId] = response.record!;
      }
      _expenseLogs[expenseId] = response.messages;
      _expenseLogErrors[expenseId] = null;
    } on AppException catch (e) {
      _expenseLogErrors[expenseId] = e.message ?? e.toString();
      _errorMessage = e.message ?? e.toString();
    } catch (e) {
      final msg =
          ApiErrorHandler.handle(e).message ??
          ApiErrorHandler.handle(e).toString();
      _expenseLogErrors[expenseId] = msg;
      _errorMessage = msg;
    } finally {
      _isLoadingLogs = false;
      notifyListeners();
    }
  }

  RecentExpenseModel? getExpenseDetail(int expenseId) {
    if (_expenseDetails.containsKey(expenseId)) {
      return _expenseDetails[expenseId];
    }
    try {
      return _allExpenses.firstWhere((e) => e.id == expenseId);
    } catch (_) {
      try {
        return _summary?.recentExpenses.firstWhere((e) => e.id == expenseId);
      } catch (_) {
        return null;
      }
    }
  }

  List<LogNoteModel> getLogsForExpense(int expenseId) {
    if (!_expenseLogs.containsKey(expenseId)) {
      return [];
    }
    return List.unmodifiable(_expenseLogs[expenseId]!);
  }

  Future<bool> addLogNote(
    int expenseId,
    String message, {
    List<XFile> files = const [],
    List<String> mentionNames = const [],
    String? bodyPartsJson,
  }) async {
    if (message.trim().isEmpty && files.isEmpty) return false;
    _isAddingLogNote = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final createdLog = await createLogNoteUseCase(
        source: 'expense',
        id: expenseId,
        text: message,
        files: files,
        mentionNames: mentionNames,
        bodyPartsJson: bodyPartsJson,
      );
      if (!_expenseLogs.containsKey(expenseId)) {
        _expenseLogs[expenseId] = [];
      }
      _expenseLogs[expenseId]!.insert(0, createdLog);
      await fetchExpenseLogs(expenseId);
      return true;
    } on SubmissionOutcomeUnknownException catch (e) {
      _errorMessage = e.message;
      LostSubmissionChecker.startLogNote(
        before: getLogsForExpense(expenseId),
        text: message,
        fetch: () async =>
            (await getLogNotesUseCase('expense', expenseId)).messages,
        refresh: () => fetchExpenseLogs(expenseId),
      );
      return false;
    } on AppException catch (e) {
      _errorMessage = e.message ?? e.toString();
      return false;
    } catch (e) {
      _errorMessage =
          ApiErrorHandler.handle(e).message ??
          ApiErrorHandler.handle(e).toString();
      return false;
    } finally {
      _isAddingLogNote = false;
      notifyListeners();
    }
  }

  Future<bool> editLogNote(
    int messageId,
    String text,
    int expenseId, {
    List<XFile> files = const [],
    List<int> existingAttachments = const [],
    List<String> mentionNames = const [],
    String? bodyPartsJson,
  }) async {
    _isSubmittingLogNote = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedLog = await updateLogNoteUseCase(
        messageId: messageId,
        text: text,
        files: files,
        existingAttachments: existingAttachments,
        mentionNames: mentionNames,
        bodyPartsJson: bodyPartsJson,
      );

      final currentLogs = _expenseLogs[expenseId] ?? [];
      final index = currentLogs.indexWhere(
        (log) => log.id == messageId.toString(),
      );
      if (index != -1) {
        currentLogs[index] = updatedLog;
        _expenseLogs[expenseId] = List.from(currentLogs);
      }
      return true;
    } on AppException catch (e) {
      _errorMessage = e.message ?? e.toString();
      return false;
    } catch (e) {
      _errorMessage =
          ApiErrorHandler.handle(e).message ??
          ApiErrorHandler.handle(e).toString();
      return false;
    } finally {
      _isSubmittingLogNote = false;
      notifyListeners();
    }
  }

  Future<bool> deleteLogNote(int expenseId, int messageId) async {
    final logs = _expenseLogs[expenseId];
    if (logs != null) {
      final index = logs.indexWhere((l) => l.id == messageId.toString());
      if (index != -1) {
        try {
          await deleteLogNoteUseCase(messageId);
          logs.removeAt(index);
          notifyListeners();
          return true;
        } catch (e) {
          _errorMessage =
              ApiErrorHandler.handle(e).message ??
              ApiErrorHandler.handle(e).toString();
          notifyListeners();
          return false;
        }
      }
    }
    return false;
  }

  void deleteMultipleLogNotes(int expenseId, Set<String> logIds) {
    final logs = _expenseLogs[expenseId];
    if (logs != null && logIds.isNotEmpty) {
      logs.removeWhere((l) => logIds.contains(l.id));
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
