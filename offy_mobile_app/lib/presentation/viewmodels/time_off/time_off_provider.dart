import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/usecases/get_timeoff_data_usecase.dart';
import '../../../domain/usecases/get_timeoff_history_usecase.dart';
import '../../../domain/usecases/get_upcoming_leaves_usecase.dart';
import '../../../domain/usecases/get_timeoff_types_usecase.dart';
import '../../../domain/usecases/calculate_timeoff_duration_usecase.dart';
import '../../../domain/usecases/submit_timeoff_request_usecase.dart';
import '../../../domain/usecases/get_timeoff_calendar_month_usecase.dart';
import '../../../domain/usecases/get_timeoff_calendar_day_usecase.dart';
import '../../../data/models/timeoff_response_model.dart';
import '../../../data/models/calendar_month_response_model.dart';
import '../../../data/models/calendar_day_schedule_model.dart';
import '../../../domain/usecases/get_log_notes_usecase.dart';
import '../../../domain/usecases/create_log_note_usecase.dart';
import '../../../domain/usecases/update_log_note_usecase.dart';
import '../../../domain/usecases/delete_log_note_usecase.dart';
import '../../../data/models/log_note_model.dart';
import '../../../domain/usecases/get_expense_filter_options_usecase.dart';
import '../../../domain/usecases/get_expense_filter_content_usecase.dart';
import '../../../domain/usecases/apply_expense_filter_usecase.dart';
import '../../../data/models/filter_model.dart';
import '../../../core/errors/api_error_handler.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/lost_submission_checker.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/base/session_provider.dart';

enum TimeOffListType { upcoming, history }

class TimeOffFilterState {
  String searchQuery = '';
  FilterOption selectedFilterOption = FilterOption.month;
  String selectedMonthBucket = 'recent';
  String appliedMonthBucket = 'recent';
  final Set<String> selectedMonthIds = {};
  final Set<int> selectedTypeIds = {};
  final Set<String> selectedStatusIds = {};
  DateTimeRange? selectedDateRange;
  bool isCustomRangeActive = false;
  bool isMonthActive = false;
  final Map<String, dynamic> activeFilters = {};
  bool isInitialized = false;

  final Map<FilterOption, FilterContentResponseModel> cachedFilterContent = {};
  final Map<String, List<FilterItemModel>> cachedMonthBucketItems = {};
  List<FilterItemModel> currentMonthItems = [];
  List<FilterItemModel> currentTypeItems = [];
  List<FilterItemModel> currentStatusItems = [];

  bool get hasActiveFilters =>
      activeFilters.isNotEmpty ||
      (isMonthActive && selectedMonthIds.isNotEmpty) ||
      selectedTypeIds.isNotEmpty ||
      selectedStatusIds.isNotEmpty ||
      (isCustomRangeActive && selectedDateRange != null);

  bool isOptionActive(FilterOption option) {
    switch (option) {
      case FilterOption.month:
      case FilterOption.dateRange:
        return isCustomRangeActive
            ? (selectedDateRange != null)
            : (isMonthActive && selectedMonthIds.isNotEmpty);
      case FilterOption.category:
      case FilterOption.leaveType:
        return selectedTypeIds.isNotEmpty;
      case FilterOption.status:
        return selectedStatusIds.isNotEmpty;
    }
  }

  Set<String> get currentBucketSelectedMonthIds =>
      Set.unmodifiable(selectedMonthIds);

  Set<String> getBucketsWithSelection(List<FilterBucketModel> monthBuckets) {
    final result = <String>{};
    if (selectedMonthIds.isEmpty) return result;

    for (final bucket in monthBuckets) {
      final bKey = bucket.key.toLowerCase();
      final items = cachedMonthBucketItems[bKey];
      if (items != null) {
        if (items.any((item) => selectedMonthIds.contains(item.idAsString))) {
          result.add(bKey);
        }
      } else {
        if (bKey != 'recent' &&
            selectedMonthIds.any((id) => id.toLowerCase().contains(bKey))) {
          result.add(bKey);
        }
      }
    }
    return result;
  }

  String? findFirstBucketWithSelection(List<FilterBucketModel> monthBuckets) {
    if (selectedMonthIds.isEmpty || monthBuckets.isEmpty) return null;

    // 1. Cross-reference only against the Recent item list
    final recentItems = cachedMonthBucketItems['recent'];
    if (recentItems == null) {
      // While recent items are loading, remain on 'recent' to prevent jitter
      return 'recent';
    }
    final hasRecentSelection = recentItems.any(
      (item) => selectedMonthIds.contains(item.idAsString),
    );
    if (hasRecentSelection) {
      return 'recent';
    }

    // 2. Otherwise, check buckets in order (e.g. 2026, 2025, 2024...)
    for (final b in monthBuckets) {
      final bKey = b.key.toLowerCase();
      if (bKey == 'recent') continue;

      final items = cachedMonthBucketItems[bKey];
      if (items != null) {
        if (items.any((item) => selectedMonthIds.contains(item.idAsString))) {
          return bKey;
        }
      } else {
        if (selectedMonthIds.any((id) => id.toLowerCase().contains(bKey))) {
          return bKey;
        }
      }
    }
    return null;
  }

  // Applied Filter Snapshot (for deep dirty checking)
  Set<String> snapshotAppliedMonths = {};
  String snapshotAppliedMonthBucket = 'recent';
  Set<int> snapshotAppliedTypeIds = {};
  Set<String> snapshotAppliedStatusIds = {};
  DateTimeRange? snapshotAppliedDateRange;
  bool snapshotAppliedIsCustomRange = false;
  bool snapshotAppliedIsMonthActive = false;

  void snapshotAppliedFilters() {
    snapshotAppliedMonthBucket = selectedMonthBucket;
    snapshotAppliedMonths = Set<String>.from(selectedMonthIds);
    snapshotAppliedTypeIds = Set<int>.from(selectedTypeIds);
    snapshotAppliedStatusIds = Set<String>.from(selectedStatusIds);
    snapshotAppliedDateRange = selectedDateRange;
    snapshotAppliedIsCustomRange = isCustomRangeActive;
    snapshotAppliedIsMonthActive = isMonthActive;
  }

  bool get hasFilterChanges {
    if (isCustomRangeActive != snapshotAppliedIsCustomRange) return true;
    if (isMonthActive != snapshotAppliedIsMonthActive) return true;
    if (isCustomRangeActive) {
      if (selectedDateRange?.start != snapshotAppliedDateRange?.start ||
          selectedDateRange?.end != snapshotAppliedDateRange?.end) {
        return true;
      }
    } else if (isMonthActive) {
      if (!setEquals(selectedMonthIds, snapshotAppliedMonths)) return true;
    }
    if (!setEquals(selectedTypeIds, snapshotAppliedTypeIds)) return true;
    if (!setEquals(selectedStatusIds, snapshotAppliedStatusIds)) return true;
    return false;
  }

  /// Puts the selections back to the last applied filters.
  void restoreAppliedFilters() {
    selectedMonthIds
      ..clear()
      ..addAll(snapshotAppliedMonths);
    selectedTypeIds
      ..clear()
      ..addAll(snapshotAppliedTypeIds);
    selectedStatusIds
      ..clear()
      ..addAll(snapshotAppliedStatusIds);
    selectedDateRange = snapshotAppliedDateRange;
    isCustomRangeActive = snapshotAppliedIsCustomRange;
    isMonthActive = snapshotAppliedIsMonthActive;
  }

  /// Clears the selections (not yet applied).
  void clearSelections() {
    selectedMonthIds.clear();
    selectedTypeIds.clear();
    selectedStatusIds.clear();
    selectedDateRange = null;
    isCustomRangeActive = false;
    isMonthActive = false;
  }

  void reset() {
    selectedMonthIds.clear();
    appliedMonthBucket = 'recent';
    selectedMonthBucket = 'recent';
    selectedTypeIds.clear();
    selectedStatusIds.clear();
    selectedDateRange = null;
    isCustomRangeActive = false;
    isMonthActive = false;
    activeFilters.clear();
    cachedFilterContent.clear();
    cachedMonthBucketItems.clear();
    currentMonthItems = [];
    currentTypeItems = [];
    currentStatusItems = [];
    snapshotAppliedFilters();
  }
}

class TimeOffProvider extends SessionProvider {
  final GetTimeOffDataUseCase getTimeOffDataUseCase;
  final GetTimeOffHistoryUseCase getTimeOffHistoryUseCase;
  final GetUpcomingLeavesUseCase getUpcomingLeavesUseCase;
  final GetTimeOffTypesUseCase getTimeOffTypesUseCase;
  final CalculateTimeOffDurationUseCase calculateTimeOffDurationUseCase;
  final SubmitTimeOffRequestUseCase submitTimeOffRequestUseCase;
  final GetTimeOffCalendarMonthUseCase getTimeOffCalendarMonthUseCase;
  final GetTimeOffCalendarDayUseCase getTimeOffCalendarDayUseCase;
  final GetLogNotesUseCase getLogNotesUseCase;
  final CreateLogNoteUseCase createLogNoteUseCase;
  final UpdateLogNoteUseCase updateLogNoteUseCase;
  final DeleteLogNoteUseCase deleteLogNoteUseCase;
  final GetExpenseFilterOptionsUseCase getExpenseFilterOptionsUseCase;
  final GetExpenseFilterContentUseCase getExpenseFilterContentUseCase;
  final ApplyExpenseFilterUseCase applyExpenseFilterUseCase;

  TimeOffProvider({
    required this.getTimeOffDataUseCase,
    required this.getTimeOffHistoryUseCase,
    required this.getUpcomingLeavesUseCase,
    required this.getTimeOffTypesUseCase,
    required this.calculateTimeOffDurationUseCase,
    required this.submitTimeOffRequestUseCase,
    required this.getTimeOffCalendarMonthUseCase,
    required this.getTimeOffCalendarDayUseCase,
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
    _filterStates[TimeOffListType.upcoming]!.searchQuery = '';
    _filterStates[TimeOffListType.history]!.searchQuery = '';
    _filterStates[TimeOffListType.upcoming]!.reset();
    _filterStates[TimeOffListType.history]!.reset();
    _filterStates[TimeOffListType.upcoming]!.isInitialized = false;
    _filterStates[TimeOffListType.history]!.isInitialized = false;
    _upcomingRequestId = 0;
    _historyRequestId = 0;
    _searchFilterRequestId = 0;
    _activeSearchRequestId = 0;
    _isFetchingFilterOptions = false;
    _filterOptions = [];
    _isFetchingFilterContent = false;
    _monthBuckets = [];
    _isCustomRangeAvailable = true;
    _filterContentRequestId = 0;
    _monthBucketRequestId = 0;
    _timeOffData = null;
    _history = [];
    _currentHistoryPage = 1;
    _hasMoreHistory = true;
    _inFlightApplyFilters.clear();
    _inFlightResetFilters.clear();
    _filterOperationIds[TimeOffListType.upcoming] =
        (_filterOperationIds[TimeOffListType.upcoming] ?? 0) + 1;
    _filterOperationIds[TimeOffListType.history] =
        (_filterOperationIds[TimeOffListType.history] ?? 0) + 1;
    _upcomingLeaves = [];
    _currentUpcomingPage = 1;
    _hasMoreUpcomingLeaves = true;
    _availableTypes = [];
    _calculatedDuration = null;
    _calendarMonthData = null;
    _eventDotsByDay = {};
    _selectedDaySchedule = null;
    _timeOffLogs.clear();
    _isLoading = false;
    _isFetchingHistory = false;
    _isFetchingMoreHistory = false;
    _isFetchingUpcomingLeaves = false;
    _isFetchingMoreUpcoming = false;
    _isCalculatingDuration = false;
    _isSubmittingRequest = false;
    _isCalendarMonthLoading = false;
    _isCalendarDayLoading = false;
    _isLoadingLogs = false;
    _isAddingLogNote = false;
    _isSubmittingLogNote = false;
    _errorMessage = null;
    _calendarMonthError = null;
    _calendarDayError = null;
    notifyListeners();
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  TimeOffResponseModel? _timeOffData;
  TimeOffResponseModel? get timeOffData => _timeOffData;

  // History State
  List<TimeOffLeaveModel> _history = [];
  List<TimeOffLeaveModel> get history => _history;

  bool _isFetchingHistory = false;
  bool get isFetchingHistory => _isFetchingHistory;

  bool _isFetchingMoreHistory = false;
  bool get isFetchingMoreHistory => _isFetchingMoreHistory;

  bool _hasMoreHistory = true;
  bool get hasMoreHistory => _hasMoreHistory;

  int _currentHistoryPage = 1;

  // Upcoming Leaves State
  List<TimeOffLeaveModel> _upcomingLeaves = [];
  List<TimeOffLeaveModel> get upcomingLeaves => _upcomingLeaves;

  List<TimeOffLeaveItemModel> get upcomingOverviewLeaves =>
      _timeOffData?.upcoming ?? [];

  bool _isFetchingUpcomingLeaves = false;
  bool get isFetchingUpcomingLeaves => _isFetchingUpcomingLeaves;

  bool _isFetchingMoreUpcoming = false;
  bool get isFetchingMoreUpcoming => _isFetchingMoreUpcoming;

  bool _hasMoreUpcomingLeaves = true;
  bool get hasMoreUpcomingLeaves => _hasMoreUpcomingLeaves;

  int _currentUpcomingPage = 1;

  // Search & Filter state
  bool _isSearching = false;
  bool get isSearching => _isSearching;

  bool _isFiltering = false;
  bool get isFiltering => _isFiltering;

  Timer? _debounceTimer;
  bool get isDebouncing => _debounceTimer?.isActive ?? false;

  bool get isInteractionBlocked => _isSearching || _isFiltering || isDebouncing;

  void cancelDebounce() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer?.cancel();
      notifyListeners();
    }
  }

  int _searchFilterRequestId = 0;
  int _activeSearchRequestId = 0;

  final Map<TimeOffListType, TimeOffFilterState> _filterStates = {
    TimeOffListType.upcoming: TimeOffFilterState(),
    TimeOffListType.history: TimeOffFilterState(),
  };

  TimeOffListType _activeFilterTarget = TimeOffListType.upcoming;
  TimeOffListType get activeFilterTarget => _activeFilterTarget;

  TimeOffFilterState filterStateFor(TimeOffListType target) =>
      _filterStates[target]!;

  String get currentSearchQuery =>
      _filterStates[_activeFilterTarget]!.searchQuery;

  Map<String, dynamic> get activeFilters =>
      Map.unmodifiable(_filterStates[_activeFilterTarget]!.activeFilters);

  bool get hasActiveFilters =>
      _filterStates[_activeFilterTarget]!.hasActiveFilters;

  bool hasActiveFiltersFor(TimeOffListType target) =>
      _filterStates[target]!.hasActiveFilters;

  bool hasFilterChanges({TimeOffListType? target}) =>
      _filterStates[target ?? _activeFilterTarget]!.hasFilterChanges;

  final Map<String, Future<FilterOptionsResponseModel>> _filterOptionsFutures =
      {};

  Future<FilterOptionsResponseModel> _fetchFilterOptionsDeduped({
    required FilterSource source,
    required String view,
  }) {
    final key = '$source:$view';
    if (_filterOptionsFutures.containsKey(key)) {
      return _filterOptionsFutures[key]!;
    }
    final future = getExpenseFilterOptionsUseCase(source: source, view: view);
    _filterOptionsFutures[key] = future;
    return future.whenComplete(() {
      _filterOptionsFutures.remove(key);
    });
  }

  /// Silently synchronizes active filters from the server on startup so that
  /// [hasActiveFilters] reflects the true state and the indicator dot displays immediately.
  Future<void> syncActiveFilters({
    FilterSource source = FilterSource.timeoff,
    required TimeOffListType target,
  }) async {
    final state = _filterStates[target]!;
    final viewStr = target.name;
    try {
      final response = await _fetchFilterOptionsDeduped(
        source: source,
        view: viewStr,
      );
      if (state.isInitialized) return;
      final data = response.data;
      if (data != null) {
        final options = List<FilterOptionItemModel>.from(data.options);
        final monthIdx = options.indexWhere(
          (o) => o.filterOption == FilterOption.month,
        );
        if (monthIdx > 0) {
          final monthOption = options.removeAt(monthIdx);
          options.insert(0, monthOption);
        }
        if (_activeFilterTarget == target) {
          _filterOptions = options;
        }
        final active = data.active;
        if (active != null) {
          state.isInitialized = true;
          state.selectedTypeIds.clear();
          if (active.typeIds.isNotEmpty) {
            state.selectedTypeIds.addAll(active.typeIds);
          } else if (active.categoryIds.isNotEmpty) {
            state.selectedTypeIds.addAll(active.categoryIds);
          }
          state.selectedStatusIds.clear();
          if (active.statusIds.isNotEmpty) {
            state.selectedStatusIds.addAll(active.statusIds);
          }
          if (active.parsedDateRange != null) {
            state.selectedDateRange = active.parsedDateRange;
            state.isCustomRangeActive = true;
            state.isMonthActive = false;
          } else {
            state.selectedDateRange = null;
            state.isCustomRangeActive = false;
            state.isMonthActive = active.monthIds.isNotEmpty;
            state.selectedMonthIds.clear();
            if (active.monthIds.isNotEmpty) {
              state.selectedMonthIds.addAll(active.monthIds);
            }
          }
        }
        state.snapshotAppliedFilters();
        notifyListeners();
      }
    } catch (e) {
      // Non-blocking background sync failures should not disrupt UI display
      debugPrint('TimeOffProvider.syncActiveFilters failed: $e');
    }
  }

  String getSearchQuery(TimeOffListType target) =>
      _filterStates[target]!.searchQuery;

  int _upcomingRequestId = 0;
  int _historyRequestId = 0;

  // Advanced Server Filter State
  bool _isFetchingFilterOptions = false;
  bool get isFetchingFilterOptions => _isFetchingFilterOptions;

  List<FilterOptionItemModel> _filterOptions = [];
  List<FilterOptionItemModel> get filterOptions => _filterOptions;

  FilterOption get selectedFilterOption =>
      _filterStates[_activeFilterTarget]!.selectedFilterOption;

  FilterOption getSelectedFilterOption(TimeOffListType target) =>
      _filterStates[target]!.selectedFilterOption;

  bool _isFetchingFilterContent = false;
  bool get isFetchingFilterContent => _isFetchingFilterContent;

  List<FilterBucketModel> _monthBuckets = [];
  List<FilterBucketModel> get monthBuckets => _monthBuckets;

  String get firstBucketKey =>
      _monthBuckets.firstOrNull?.key.toLowerCase() ?? 'recent';

  String get selectedMonthBucket =>
      _filterStates[_activeFilterTarget]!.selectedMonthBucket;

  String getSelectedMonthBucket(TimeOffListType target) =>
      _filterStates[target]!.selectedMonthBucket;

  String get appliedMonthBucket =>
      _filterStates[_activeFilterTarget]!.appliedMonthBucket;

  String getAppliedMonthBucket(TimeOffListType target) =>
      _filterStates[target]!.appliedMonthBucket;

  Set<String> get currentBucketSelectedMonthIds =>
      _filterStates[_activeFilterTarget]!.currentBucketSelectedMonthIds;

  Set<String> getCurrentBucketSelectedMonthIds(TimeOffListType target) =>
      _filterStates[target]!.currentBucketSelectedMonthIds;

  Set<String> get selectedMonthIds =>
      _filterStates[_activeFilterTarget]!.selectedMonthIds;

  Set<String> getSelectedMonthIds(TimeOffListType target) =>
      _filterStates[target]!.selectedMonthIds;

  Set<String> get bucketsWithSelection => _filterStates[_activeFilterTarget]!
      .getBucketsWithSelection(_monthBuckets);

  Set<String> getBucketsWithSelection(TimeOffListType target) =>
      _filterStates[target]!.getBucketsWithSelection(_monthBuckets);

  String? findFirstBucketWithSelection({TimeOffListType? target}) =>
      _filterStates[target ?? _activeFilterTarget]!
          .findFirstBucketWithSelection(_monthBuckets);

  List<FilterItemModel> get currentMonthItems =>
      _filterStates[_activeFilterTarget]!.currentMonthItems;

  List<FilterItemModel> getCurrentMonthItems(TimeOffListType target) =>
      _filterStates[target]!.currentMonthItems;

  List<FilterItemModel> get currentTypeItems =>
      _filterStates[_activeFilterTarget]!.currentTypeItems;

  List<FilterItemModel> getCurrentTypeItems(TimeOffListType target) =>
      _filterStates[target]!.currentTypeItems;

  List<FilterItemModel> get currentStatusItems =>
      _filterStates[_activeFilterTarget]!.currentStatusItems;

  List<FilterItemModel> getCurrentStatusItems(TimeOffListType target) =>
      _filterStates[target]!.currentStatusItems;

  Set<int> get selectedTypeIds =>
      Set.unmodifiable(_filterStates[_activeFilterTarget]!.selectedTypeIds);

  Set<int> getSelectedTypeIds(TimeOffListType target) =>
      Set.unmodifiable(_filterStates[target]!.selectedTypeIds);

  Set<String> get selectedStatusIds =>
      Set.unmodifiable(_filterStates[_activeFilterTarget]!.selectedStatusIds);

  Set<String> getSelectedStatusIds(TimeOffListType target) =>
      Set.unmodifiable(_filterStates[target]!.selectedStatusIds);

  DateTimeRange? get selectedDateRange =>
      _filterStates[_activeFilterTarget]!.selectedDateRange;

  DateTimeRange? getSelectedDateRange(TimeOffListType target) =>
      _filterStates[target]!.selectedDateRange;

  bool get isCustomRangeActive =>
      _filterStates[_activeFilterTarget]!.isCustomRangeActive;

  bool isCustomRangeActiveFor(TimeOffListType target) =>
      _filterStates[target]!.isCustomRangeActive;

  bool get isMonthActive => _filterStates[_activeFilterTarget]!.isMonthActive;

  bool isMonthActiveFor(TimeOffListType target) =>
      _filterStates[target]!.isMonthActive;

  bool isOptionActive(FilterOption option, {TimeOffListType? target}) =>
      _filterStates[target ?? _activeFilterTarget]!.isOptionActive(option);

  bool _isCustomRangeAvailable = true;
  bool get isCustomRangeAvailable => _isCustomRangeAvailable;

  int _filterContentRequestId = 0;
  int _monthBucketRequestId = 0;

  void setCustomDateRange(DateTimeRange? range, {TimeOffListType? target}) {
    final state = _filterStates[target ?? _activeFilterTarget]!;
    state.selectedDateRange = range;
    state.isCustomRangeActive = range != null;
    if (state.isCustomRangeActive) {
      state.isMonthActive = false;
    } else {
      state.isMonthActive = state.selectedMonthIds.isNotEmpty;
    }
    notifyListeners();
  }

  void activateCustomDateRange({TimeOffListType? target}) {
    final state = _filterStates[target ?? _activeFilterTarget]!;
    if (state.selectedDateRange != null) {
      state.isCustomRangeActive = true;
      state.isMonthActive = false;
      notifyListeners();
    }
  }

  void clearCustomDateRange({TimeOffListType? target}) {
    final state = _filterStates[target ?? _activeFilterTarget]!;
    state.selectedDateRange = null;
    state.isCustomRangeActive = false;
    state.isMonthActive = state.selectedMonthIds.isNotEmpty;
    notifyListeners();
  }

  void deactivateMonthFilter({TimeOffListType? target}) {
    final state = _filterStates[target ?? _activeFilterTarget]!;
    state.isMonthActive = false;
    state.isCustomRangeActive = false;
    notifyListeners();
  }

  /// Back without Apply: restores the last applied selections (no API call).
  void discardFilterChanges({TimeOffListType? target}) {
    _filterStates[target ?? _activeFilterTarget]!.restoreAppliedFilters();
    notifyListeners();
  }

  /// Reset button: clears the selections only; nothing is sent until Apply.
  void clearFilterSelections({TimeOffListType? target}) {
    _filterStates[target ?? _activeFilterTarget]!.clearSelections();
    notifyListeners();
  }

  void clearNeutralStateSelections({TimeOffListType? target}) {
    final state = _filterStates[target ?? _activeFilterTarget]!;
    if (!state.isCustomRangeActive && state.selectedMonthIds.isEmpty) {
      state.isMonthActive = false;
    }
    if (!state.isCustomRangeActive && !state.isMonthActive) {
      state.selectedMonthIds.clear();
      state.selectedDateRange = null;
      notifyListeners();
    }
  }

  void clearMonthSelection({TimeOffListType? target}) {
    final state = _filterStates[target ?? _activeFilterTarget]!;
    state.selectedMonthIds.clear();
    state.isMonthActive = false;
    notifyListeners();
  }

  void selectMonthOption({TimeOffListType? target}) {
    final activeTarget = target ?? _activeFilterTarget;
    final state = _filterStates[activeTarget]!;
    state.isCustomRangeActive = false;
    state.isMonthActive = true;
    final firstBucket = findFirstBucketWithSelection(target: activeTarget);
    if (firstBucket != null && firstBucket != state.selectedMonthBucket) {
      selectMonthBucket(firstBucket, target: activeTarget);
    } else if (firstBucket == null && _monthBuckets.isNotEmpty) {
      final firstKey = firstBucketKey;
      if (firstKey != state.selectedMonthBucket) {
        selectMonthBucket(firstKey, target: activeTarget);
      }
    }
    notifyListeners();
  }

  // Types State
  List<TimeOffTypeModel> _availableTypes = [];
  List<TimeOffTypeModel> get availableTypes => _availableTypes;

  // Duration State
  TimeOffDurationModel? _calculatedDuration;
  TimeOffDurationModel? get calculatedDuration => _calculatedDuration;

  bool _isCalculatingDuration = false;
  bool get isCalculatingDuration => _isCalculatingDuration;

  bool _isSubmittingRequest = false;
  bool get isSubmittingRequest => _isSubmittingRequest;

  // Calendar State
  bool _isCalendarMonthLoading = false;
  bool get isCalendarMonthLoading => _isCalendarMonthLoading;

  String? _calendarMonthError;
  String? get calendarMonthError => _calendarMonthError;

  CalendarMonthDataModel? _calendarMonthData;
  CalendarMonthDataModel? get calendarMonthData => _calendarMonthData;

  Map<int, List<Color>> _eventDotsByDay = {};
  Map<int, List<Color>> get eventDotsByDay => _eventDotsByDay;

  bool _isCalendarDayLoading = false;
  bool get isCalendarDayLoading => _isCalendarDayLoading;

  String? _calendarDayError;
  String? get calendarDayError => _calendarDayError;

  CalendarDayScheduleModel? _selectedDaySchedule;
  CalendarDayScheduleModel? get selectedDaySchedule => _selectedDaySchedule;

  int _monthRequestId = 0;
  int _dayRequestId = 0;
  String _activeSelectedDate = '';
  Future<void>? _inFlightMonthFetch;

  Future<void> fetchTimeOffCalendarMonth({
    required int year,
    required int month,
  }) async {
    // Only load new month after the previous api loading completes
    if (_isCalendarMonthLoading && _inFlightMonthFetch != null) {
      try {
        await _inFlightMonthFetch;
      } catch (e) {
        // Prior in-flight fetch errors are superseded and must not block the new month request
        debugPrint(
          'TimeOffProvider: Previous month fetch settled with error: $e',
        );
      }
    }

    final fetchFuture = _performFetchTimeOffCalendarMonth(
      year: year,
      month: month,
    );
    _inFlightMonthFetch = fetchFuture;
    await fetchFuture;
  }

  Future<void> _performFetchTimeOffCalendarMonth({
    required int year,
    required int month,
  }) async {
    final currentRequestId = ++_monthRequestId;
    _isCalendarMonthLoading = true;
    _calendarMonthError = null;
    notifyListeners();

    try {
      final data = await getTimeOffCalendarMonthUseCase(
        year: year,
        month: month,
      );
      if (currentRequestId != _monthRequestId) return;

      _calendarMonthData = data;
      _processEventDots(data);
    } catch (e) {
      if (currentRequestId != _monthRequestId) return;
      _calendarMonthError = e.toString();
    } finally {
      if (currentRequestId == _monthRequestId) {
        _isCalendarMonthLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchTimeOffCalendarDay({required String date}) async {
    final currentRequestId = ++_dayRequestId;
    _activeSelectedDate = date;
    _isCalendarDayLoading = true;
    _calendarDayError = null;
    _selectedDaySchedule = null;
    notifyListeners();

    try {
      final schedule = await getTimeOffCalendarDayUseCase(date: date);
      if (currentRequestId != _dayRequestId || _activeSelectedDate != date) {
        return;
      }

      _selectedDaySchedule = schedule;

      if (schedule.items.isNotEmpty) {
        final parsedDate = DateTime.tryParse(date);
        if (parsedDate != null &&
            _calendarMonthData != null &&
            parsedDate.year == _calendarMonthData!.year &&
            parsedDate.month == _calendarMonthData!.month) {
          final scheduleColors = schedule.items
              .map((e) => e.accentColor)
              .toList();
          if (scheduleColors.isNotEmpty) {
            _eventDotsByDay[parsedDate.day] = scheduleColors;
          }
        }
      }
    } catch (e) {
      if (currentRequestId != _dayRequestId || _activeSelectedDate != date) {
        return;
      }
      _calendarDayError = e.toString();
      _selectedDaySchedule = null;
    } finally {
      if (currentRequestId == _dayRequestId && _activeSelectedDate == date) {
        _isCalendarDayLoading = false;
        notifyListeners();
      }
    }
  }

  static Color? _parseHexColor(String? hexString) {
    if (hexString == null || hexString.trim().isEmpty) return null;
    final cleanHex = hexString.replaceAll('#', '').trim();
    if (cleanHex.length == 6) {
      final value = int.tryParse('FF$cleanHex', radix: 16);
      if (value != null) return Color(value);
    } else if (cleanHex.length == 8) {
      final value = int.tryParse(cleanHex, radix: 16);
      if (value != null) return Color(value);
    }
    return null;
  }

  TimeOffTypeModel? _findMatchingLeaveType(String query) {
    if (query.trim().isEmpty) return null;
    final cleanQuery = query.trim();
    final normalizedQuery = cleanQuery.toLowerCase().replaceAll(
      RegExp(r'[\s\-_]+'),
      '',
    );

    // 1. Match by numeric ID
    final queryId = int.tryParse(cleanQuery);
    if (queryId != null) {
      for (final type in _availableTypes) {
        if (type.id == queryId) return type;
      }
    }

    // 2. Match by exact code or normalized code
    for (final type in _availableTypes) {
      if (type.code.toLowerCase() == cleanQuery.toLowerCase()) return type;
      final normalizedCode = type.code.toLowerCase().replaceAll(
        RegExp(r'[\s\-_]+'),
        '',
      );
      if (normalizedCode == normalizedQuery) return type;
    }

    // 3. Match by exact name or normalized name
    for (final type in _availableTypes) {
      if (type.name.toLowerCase() == cleanQuery.toLowerCase()) return type;
      final normalizedName = type.name.toLowerCase().replaceAll(
        RegExp(r'[\s\-_]+'),
        '',
      );
      if (normalizedName == normalizedQuery) return type;
    }

    // 4. Match by substring / contains
    for (final type in _availableTypes) {
      final normalizedCode = type.code.toLowerCase().replaceAll(
        RegExp(r'[\s\-_]+'),
        '',
      );
      final normalizedName = type.name.toLowerCase().replaceAll(
        RegExp(r'[\s\-_]+'),
        '',
      );
      if (normalizedCode.contains(normalizedQuery) ||
          normalizedQuery.contains(normalizedCode)) {
        return type;
      }
      if (normalizedName.contains(normalizedQuery) ||
          normalizedQuery.contains(normalizedName)) {
        return type;
      }
    }

    return null;
  }

  TimeOffTypeModel? _findLeaveTypeForDate(DateTime date) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final allLeaves = [
      ..._upcomingLeaves.expand((group) => group.leaves),
      ...(_timeOffData?.upcoming ?? []),
      ..._history.expand((group) => group.leaves),
      ...(_timeOffData?.history ?? []),
    ];

    for (final leave in allLeaves) {
      if (leave.dateFrom.isNotEmpty && leave.dateTo.isNotEmpty) {
        if (dateStr.compareTo(leave.dateFrom) >= 0 &&
            dateStr.compareTo(leave.dateTo) <= 0) {
          if (leave.leaveType != null) {
            final match =
                _findMatchingLeaveType(leave.leaveType!.id.toString()) ??
                _findMatchingLeaveType(leave.leaveType!.name);
            if (match != null) return match;
          }
        }
      }
    }

    return null;
  }

  Color _getColorForLeaveType(String typeIdentifier, {DateTime? date}) {
    // 1. Direct hex color string check
    final cleanHex = typeIdentifier.replaceAll('#', '').trim();
    if (typeIdentifier.startsWith('#') &&
        (cleanHex.length == 6 || cleanHex.length == 8)) {
      final value = int.tryParse(
        cleanHex.length == 6 ? 'FF$cleanHex' : cleanHex,
        radix: 16,
      );
      if (value != null) return Color(value);
    }

    // 2. Match against available leave types from API (_availableTypes)
    final matchedType = _findMatchingLeaveType(typeIdentifier);
    if (matchedType != null) {
      final parsedColor = _parseHexColor(matchedType.color);
      if (parsedColor != null) return parsedColor;
    }

    // 3. If typeIdentifier is generic (e.g. 'leave', 'timeoff') and date is available,
    // correlate with known leaves (upcoming, history) to find specific leave type
    if (date != null) {
      final dateSpecificType = _findLeaveTypeForDate(date);
      if (dateSpecificType != null) {
        final parsedColor = _parseHexColor(dateSpecificType.color);
        if (parsedColor != null) return parsedColor;
      }
    }

    // 4. Fallback: if the leave type is different from any item in this list,
    // show the leaves in AppColors.main
    return AppColors.main;
  }

  void _processEventDots(CalendarMonthDataModel data) {
    final Map<int, List<Color>> dotsMap = {};
    for (final dayModel in data.days) {
      final List<Color> colors = [];
      final dayDate = DateTime(data.year, data.month, dayModel.day);

      // 1. Direct colors from day model if available
      if (dayModel.colors.isNotEmpty) {
        for (final hex in dayModel.colors) {
          final parsed = _parseHexColor(hex);
          if (parsed != null) {
            colors.add(parsed);
          }
        }
      }

      // 2. Resolve types against leave types from API
      if (colors.isEmpty && dayModel.types.isNotEmpty) {
        for (final type in dayModel.types) {
          final color = _getColorForLeaveType(type, date: dayDate);
          colors.add(color);
        }
      }

      // 3. If item count exceeds types/colors, fill remaining with matched or fallback color
      if (dayModel.itemCount > colors.length) {
        final fallbackColor = colors.isNotEmpty
            ? colors.first
            : _getColorForLeaveType('leave', date: dayDate);
        final remaining = dayModel.itemCount - colors.length;
        for (int i = 0; i < remaining; i++) {
          colors.add(fallbackColor);
        }
      } else if (colors.isEmpty && dayModel.itemCount > 0) {
        final fallbackColor = _getColorForLeaveType('leave', date: dayDate);
        for (int i = 0; i < dayModel.itemCount; i++) {
          colors.add(fallbackColor);
        }
      }

      dotsMap[dayModel.day] = colors;
    }
    _eventDotsByDay = dotsMap;
  }

  List<Color>? getEventsForDate(DateTime date) {
    if (_calendarMonthData != null &&
        _calendarMonthData!.year == date.year &&
        _calendarMonthData!.month == date.month) {
      return _eventDotsByDay[date.day] ?? [];
    }
    return null;
  }

  Future<void> fetchTimeOffData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await getTimeOffDataUseCase();
      _timeOffData = response;
      if (_calendarMonthData != null) {
        _processEventDots(_calendarMonthData!);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchInitialHistory({bool isRefresh = false}) async {
    final requestId = ++_historyRequestId;
    _activeSearchRequestId++;
    _isSearching = false;
    _currentHistoryPage = 1;
    _hasMoreHistory = true;
    _isFetchingHistory = true;
    if (_history.isEmpty) {
      _history = [];
    }
    _errorMessage = null;
    notifyListeners();

    try {
      final state = _filterStates[TimeOffListType.history]!;
      final response = await getTimeOffHistoryUseCase(
        page: _currentHistoryPage,
        limit: 10,
        search: state.searchQuery.isNotEmpty ? state.searchQuery : null,
        filters: state.activeFilters.isNotEmpty ? state.activeFilters : null,
        forceRefresh: isRefresh,
      );
      if (requestId != _historyRequestId) return;
      _history = response.leaves;
      _hasMoreHistory = response.pagination.hasNext;
    } catch (e) {
      if (requestId != _historyRequestId) return;
      _errorMessage = e.toString();
    } finally {
      if (requestId == _historyRequestId) {
        _isFetchingHistory = false;
        notifyListeners();
      }
    }
  }

  void _mergeHistoryGroups(List<TimeOffLeaveModel> newGroups) {
    if (newGroups.isEmpty) return;
    for (final newGroup in newGroups) {
      final existingIndex = _history.indexWhere(
        (g) => g.timeline.isNotEmpty && g.timeline == newGroup.timeline,
      );
      if (existingIndex != -1) {
        final existingGroup = _history[existingIndex];
        final existingIds = existingGroup.leaves.map((e) => e.id).toSet();
        final mergedLeaves = List<TimeOffLeaveItemModel>.from(
          existingGroup.leaves,
        );
        for (final item in newGroup.leaves) {
          if (!existingIds.contains(item.id)) {
            mergedLeaves.add(item);
            existingIds.add(item.id);
          }
        }
        _history[existingIndex] = TimeOffLeaveModel(
          timeline: existingGroup.timeline,
          leaves: mergedLeaves,
        );
      } else {
        _history.add(newGroup);
      }
    }
  }

  void _mergeUpcomingGroups(List<TimeOffLeaveModel> newGroups) {
    if (newGroups.isEmpty) return;
    for (final newGroup in newGroups) {
      final existingIndex = _upcomingLeaves.indexWhere(
        (g) => g.timeline.isNotEmpty && g.timeline == newGroup.timeline,
      );
      if (existingIndex != -1) {
        final existingGroup = _upcomingLeaves[existingIndex];
        final existingIds = existingGroup.leaves.map((e) => e.id).toSet();
        final mergedLeaves = List<TimeOffLeaveItemModel>.from(
          existingGroup.leaves,
        );
        for (final item in newGroup.leaves) {
          if (!existingIds.contains(item.id)) {
            mergedLeaves.add(item);
            existingIds.add(item.id);
          }
        }
        _upcomingLeaves[existingIndex] = TimeOffLeaveModel(
          timeline: existingGroup.timeline,
          leaves: mergedLeaves,
        );
      } else {
        _upcomingLeaves.add(newGroup);
      }
    }
  }

  Future<void> fetchMoreHistory() async {
    if (_isFetchingHistory ||
        _isSearching ||
        _isFiltering ||
        !_hasMoreHistory) {
      return;
    }

    final requestId = _historyRequestId;
    _isFetchingHistory = true;
    _isFetchingMoreHistory = true;
    notifyListeners();

    try {
      final nextPage = _currentHistoryPage + 1;
      final state = _filterStates[TimeOffListType.history]!;
      final response = await getTimeOffHistoryUseCase(
        page: nextPage,
        limit: 10,
        search: state.searchQuery.isNotEmpty ? state.searchQuery : null,
        filters: state.activeFilters.isNotEmpty ? state.activeFilters : null,
      );
      if (requestId != _historyRequestId) return;
      _currentHistoryPage = nextPage;
      _mergeHistoryGroups(response.leaves);
      _hasMoreHistory = response.pagination.hasNext;
    } catch (e) {
      if (requestId != _historyRequestId) return;
      _errorMessage = e.toString();
    } finally {
      if (requestId == _historyRequestId) {
        _isFetchingHistory = false;
        _isFetchingMoreHistory = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchInitialUpcomingLeaves({bool isRefresh = false}) async {
    final requestId = ++_upcomingRequestId;
    _activeSearchRequestId++;
    _isSearching = false;
    _currentUpcomingPage = 1;
    _hasMoreUpcomingLeaves = true;
    _isFetchingUpcomingLeaves = true;
    if (_upcomingLeaves.isEmpty) {
      _upcomingLeaves = [];
    }
    _errorMessage = null;
    notifyListeners();

    try {
      final state = _filterStates[TimeOffListType.upcoming]!;
      final response = await getUpcomingLeavesUseCase(
        page: _currentUpcomingPage,
        limit: 10,
        search: state.searchQuery.isNotEmpty ? state.searchQuery : null,
        filters: state.activeFilters.isNotEmpty ? state.activeFilters : null,
        forceRefresh: isRefresh,
      );
      if (requestId != _upcomingRequestId) return;
      _upcomingLeaves = response.leaves;
      _hasMoreUpcomingLeaves = response.pagination.hasNext;
    } catch (e) {
      if (requestId != _upcomingRequestId) return;
      _errorMessage = e.toString();
    } finally {
      if (requestId == _upcomingRequestId) {
        _isFetchingUpcomingLeaves = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchMoreUpcomingLeaves() async {
    if (_isFetchingUpcomingLeaves ||
        _isSearching ||
        _isFiltering ||
        !_hasMoreUpcomingLeaves) {
      return;
    }

    final requestId = _upcomingRequestId;
    _isFetchingUpcomingLeaves = true;
    _isFetchingMoreUpcoming = true;
    notifyListeners();

    try {
      final nextPage = _currentUpcomingPage + 1;
      final state = _filterStates[TimeOffListType.upcoming]!;
      final response = await getUpcomingLeavesUseCase(
        page: nextPage,
        limit: 10,
        search: state.searchQuery.isNotEmpty ? state.searchQuery : null,
        filters: state.activeFilters.isNotEmpty ? state.activeFilters : null,
      );
      if (requestId != _upcomingRequestId) return;
      _currentUpcomingPage = nextPage;
      _mergeUpcomingGroups(response.leaves);
      _hasMoreUpcomingLeaves = response.pagination.hasNext;
    } catch (e) {
      if (requestId != _upcomingRequestId) return;
      _errorMessage = e.toString();
    } finally {
      if (requestId == _upcomingRequestId) {
        _isFetchingUpcomingLeaves = false;
        _isFetchingMoreUpcoming = false;
        notifyListeners();
      }
    }
  }

  void onSearchQueryChanged(
    String query, {
    Duration debounceDuration = const Duration(milliseconds: 300),
    TimeOffListType? target,
  }) {
    final activeTarget = target ?? _activeFilterTarget;
    final state = _filterStates[activeTarget]!;
    final trimmed = query.trim();
    if (trimmed == state.searchQuery) {
      if (_debounceTimer?.isActive ?? false) {
        _debounceTimer?.cancel();
        notifyListeners();
      }
      return;
    }

    _debounceTimer?.cancel();
    if (trimmed.isEmpty) {
      clearSearch(target: activeTarget);
      return;
    }

    _debounceTimer = Timer(debounceDuration, () {
      submitSearch(trimmed, target: activeTarget);
    });
    notifyListeners();
  }

  Future<void> submitSearch(String query, {TimeOffListType? target}) async {
    final activeTarget = target ?? _activeFilterTarget;
    final state = _filterStates[activeTarget]!;
    final wasDebouncing = _debounceTimer?.isActive ?? false;
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed == state.searchQuery && !_isSearching && !_isFiltering) {
      if (wasDebouncing) {
        notifyListeners();
      }
      return;
    }

    state.searchQuery = trimmed;
    await _executeSearchOrFilter(isSearchOperation: true, target: activeTarget);
  }

  Future<void> clearSearch({
    bool executeFetch = true,
    TimeOffListType? target,
  }) async {
    final activeTarget = target ?? _activeFilterTarget;
    final state = _filterStates[activeTarget]!;
    final wasDebouncing = _debounceTimer?.isActive ?? false;
    _debounceTimer?.cancel();
    if (state.searchQuery.isEmpty) {
      if (wasDebouncing) {
        notifyListeners();
      }
      return;
    }
    state.searchQuery = '';
    if (executeFetch) {
      await _executeSearchOrFilter(
        isSearchOperation: true,
        target: activeTarget,
      );
    } else {
      notifyListeners();
    }
  }

  Future<void> applyFilters(
    Map<String, dynamic> filters, {
    TimeOffListType? target,
  }) async {
    final activeTarget = target ?? _activeFilterTarget;
    final state = _filterStates[activeTarget]!;
    state.activeFilters.clear();
    state.activeFilters.addAll(filters);
    await _executeSearchOrFilter(
      isSearchOperation: false,
      target: activeTarget,
    );
  }

  Future<void> resetFilters({TimeOffListType? target}) async {
    final activeTarget = target ?? _activeFilterTarget;
    final state = _filterStates[activeTarget]!;
    if (state.activeFilters.isEmpty) return;
    state.activeFilters.clear();
    await _executeSearchOrFilter(
      isSearchOperation: false,
      target: activeTarget,
    );
  }

  Future<void> _executeSearchOrFilter({
    required bool isSearchOperation,
    TimeOffListType? target,
  }) async {
    final opRequestId = ++_searchFilterRequestId;
    int? searchId;
    if (isSearchOperation) {
      searchId = ++_activeSearchRequestId;
      _isSearching = true;
    } else {
      _isFiltering = true;
    }
    _errorMessage = null;
    notifyListeners();

    final fetchUpcoming = target == null || target == TimeOffListType.upcoming;
    final fetchHistory = target == null || target == TimeOffListType.history;

    int? upcomingReqId;
    int? historyReqId;

    if (fetchUpcoming) {
      upcomingReqId = ++_upcomingRequestId;
      _currentUpcomingPage = 1;
      _hasMoreUpcomingLeaves = true;
    }
    if (fetchHistory) {
      historyReqId = ++_historyRequestId;
      _currentHistoryPage = 1;
      _hasMoreHistory = true;
    }

    try {
      final futures = <Future<void>>[];

      if (fetchUpcoming) {
        futures.add(() async {
          final state = _filterStates[TimeOffListType.upcoming]!;
          final upcomingResponse = await getUpcomingLeavesUseCase(
            page: 1,
            limit: 10,
            search: state.searchQuery.isNotEmpty ? state.searchQuery : null,
            filters: state.activeFilters.isNotEmpty
                ? state.activeFilters
                : null,
          );
          if (upcomingReqId == _upcomingRequestId) {
            _upcomingLeaves = upcomingResponse.leaves;
            _hasMoreUpcomingLeaves = upcomingResponse.pagination.hasNext;
            _currentUpcomingPage = 1;
          }
        }());
      }

      if (fetchHistory) {
        futures.add(() async {
          final state = _filterStates[TimeOffListType.history]!;
          final historyResponse = await getTimeOffHistoryUseCase(
            page: 1,
            limit: 10,
            search: state.searchQuery.isNotEmpty ? state.searchQuery : null,
            filters: state.activeFilters.isNotEmpty
                ? state.activeFilters
                : null,
          );
          if (historyReqId == _historyRequestId) {
            _history = historyResponse.leaves;
            _hasMoreHistory = historyResponse.pagination.hasNext;
            _currentHistoryPage = 1;
          }
        }());
      }

      await Future.wait(futures);
    } on AppException catch (e) {
      if (opRequestId != _searchFilterRequestId) return;
      _errorMessage = e.message ?? e.toString();
    } catch (e) {
      if (opRequestId != _searchFilterRequestId) return;
      _errorMessage =
          ApiErrorHandler.handle(e).message ??
          ApiErrorHandler.handle(e).toString();
    } finally {
      if (isSearchOperation) {
        if (searchId == _activeSearchRequestId) {
          _isSearching = false;
        }
      } else {
        if (opRequestId == _searchFilterRequestId) {
          _isFiltering = false;
        }
      }
      if (opRequestId == _searchFilterRequestId) {
        notifyListeners();
      }
    }
  }

  Future<void> initFilters({
    FilterSource source = FilterSource.timeoff,
    TimeOffListType target = TimeOffListType.upcoming,
  }) async {
    _activeFilterTarget = target;
    final state = _filterStates[target]!;
    final viewStr = target.name;

    state.selectedFilterOption = FilterOption.month;
    state.currentMonthItems = [];
    state.currentTypeItems = [];
    state.currentStatusItems = [];
    state.cachedFilterContent.clear();
    state.cachedMonthBucketItems.clear();
    _monthBuckets = [];
    _isFetchingFilterOptions = true;
    _isFetchingFilterContent = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _fetchFilterOptionsDeduped(
        source: source,
        view: viewStr,
      );
      final data = response.data;
      if (data != null) {
        final options = List<FilterOptionItemModel>.from(data.options);
        final monthIdx = options.indexWhere(
          (o) => o.filterOption == FilterOption.month,
        );
        if (monthIdx > 0) {
          final monthOption = options.removeAt(monthIdx);
          options.insert(0, monthOption);
        }
        if (_activeFilterTarget == target) {
          _filterOptions = options;
        }
        final active = data.active;
        if (!state.isInitialized && active != null) {
          state.isInitialized = true;
          state.selectedTypeIds.clear();
          if (active.typeIds.isNotEmpty) {
            state.selectedTypeIds.addAll(active.typeIds);
          } else if (active.categoryIds.isNotEmpty) {
            state.selectedTypeIds.addAll(active.categoryIds);
          }
          state.selectedStatusIds.clear();
          if (active.statusIds.isNotEmpty) {
            state.selectedStatusIds.addAll(active.statusIds);
          }
          if (active.parsedDateRange != null) {
            state.selectedDateRange = active.parsedDateRange;
            state.isCustomRangeActive = true;
            state.isMonthActive = false;
          } else {
            state.selectedDateRange = null;
            state.isCustomRangeActive = false;
            state.selectedMonthIds.clear();
            state.isMonthActive = active.monthIds.isNotEmpty;
            if (active.monthIds.isNotEmpty) {
              state.selectedMonthIds.addAll(active.monthIds);
            } else {
              state.appliedMonthBucket = firstBucketKey;
              state.selectedMonthBucket = firstBucketKey;
            }
          }
          state.snapshotAppliedFilters();
        }

        final firstActiveOption = options
            .map((o) => o.filterOption)
            .cast<FilterOption?>()
            .firstWhere(
              (opt) => opt != null && state.isOptionActive(opt),
              orElse: () => null,
            );

        if (firstActiveOption != null) {
          state.selectedFilterOption = firstActiveOption;
        } else if (options.any((o) => o.filterOption == FilterOption.month)) {
          state.selectedFilterOption = FilterOption.month;
        } else if (options.isNotEmpty) {
          state.selectedFilterOption = options.first.filterOption;
        }
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
        (state.selectedFilterOption == FilterOption.month ||
            state.selectedFilterOption == FilterOption.dateRange)
        ? findFirstBucketWithSelection(target: target)
        : null;

    await fetchFilterContent(
      source: source,
      option: state.selectedFilterOption,
      bucket: firstBucket,
      target: target,
    );
  }

  void _prefetchRemainingMonthBuckets({
    FilterSource source = FilterSource.timeoff,
    required TimeOffListType target,
  }) {
    final state = _filterStates[target]!;
    final viewStr = target.name;
    for (final b in _monthBuckets) {
      final k = b.key.toLowerCase();
      if (!state.cachedMonthBucketItems.containsKey(k)) {
        getExpenseFilterContentUseCase(
              source: source,
              view: viewStr,
              option: FilterOption.month,
              bucket: k,
            )
            .then((res) {
              final items = res.data?.items ?? [];
              state.cachedMonthBucketItems[k] = items;
              if (state.selectedMonthBucket == k &&
                  state.currentMonthItems.isEmpty) {
                state.currentMonthItems = items;
              }
              notifyListeners();
            })
            .catchError((_) {});
      }
    }
  }

  Future<void> fetchFilterContent({
    FilterSource source = FilterSource.timeoff,
    required FilterOption option,
    String? bucket,
    TimeOffListType? target,
  }) async {
    final activeTarget = target ?? _activeFilterTarget;
    final state = _filterStates[activeTarget]!;
    final viewStr = activeTarget.name;

    if (option == FilterOption.month) {
      final requestId = ++_filterContentRequestId;
      if (!state.cachedFilterContent.containsKey(FilterOption.month)) {
        _isFetchingFilterContent = true;
        notifyListeners();

        try {
          final res = await getExpenseFilterContentUseCase(
            source: source,
            view: viewStr,
            option: FilterOption.month,
          );
          if (requestId != _filterContentRequestId) return;
          state.cachedFilterContent[FilterOption.month] = res;
          if (_activeFilterTarget == activeTarget) {
            _monthBuckets = res.data?.buckets ?? [];
            final recentIdx = _monthBuckets.indexWhere(
              (b) => b.key.toLowerCase() == 'recent',
            );
            if (recentIdx > 0) {
              final recentBucket = _monthBuckets.removeAt(recentIdx);
              _monthBuckets.insert(0, recentBucket);
            }
          }
          _isCustomRangeAvailable = res.data?.customRangeAvailable ?? true;
          final initialBucket =
              (res.data?.bucket != null && res.data!.bucket!.isNotEmpty)
              ? res.data!.bucket!.toLowerCase()
              : 'recent';
          final initialItems = res.data?.items ?? [];
          if (initialItems.isNotEmpty) {
            state.cachedMonthBucketItems[initialBucket] = initialItems;
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
        final res = state.cachedFilterContent[FilterOption.month]!;
        if (_activeFilterTarget == activeTarget) {
          _monthBuckets = res.data?.buckets ?? [];
          final recentIdx = _monthBuckets.indexWhere(
            (b) => b.key.toLowerCase() == 'recent',
          );
          if (recentIdx > 0) {
            final recentBucket = _monthBuckets.removeAt(recentIdx);
            _monthBuckets.insert(0, recentBucket);
          }
        }
        _isCustomRangeAvailable = res.data?.customRangeAvailable ?? true;
      }

      if (requestId != _filterContentRequestId) return;

      final firstWithSel = findFirstBucketWithSelection(target: activeTarget);
      final targetBucket = (bucket != null && bucket.isNotEmpty)
          ? bucket.toLowerCase()
          : (firstWithSel ??
                (state.selectedMonthIds.isNotEmpty &&
                        state.appliedMonthBucket.isNotEmpty &&
                        _monthBuckets.any(
                          (b) =>
                              b.key.toLowerCase() ==
                              state.appliedMonthBucket.toLowerCase(),
                        )
                    ? state.appliedMonthBucket.toLowerCase()
                    : firstBucketKey));
      await fetchMonthBucketItems(
        source: source,
        bucket: targetBucket,
        target: activeTarget,
      );
      if (requestId != _filterContentRequestId) return;
      _prefetchRemainingMonthBuckets(source: source, target: activeTarget);
      return;
    }

    if (option == FilterOption.status) {
      if (state.cachedFilterContent.containsKey(FilterOption.status)) {
        state.currentStatusItems =
            state.cachedFilterContent[FilterOption.status]!.data?.items ?? [];
        notifyListeners();
        return;
      }

      final requestId = ++_filterContentRequestId;
      _isFetchingFilterContent = true;
      notifyListeners();

      try {
        final res = await getExpenseFilterContentUseCase(
          source: source,
          view: viewStr,
          option: FilterOption.status,
        );
        state.cachedFilterContent[FilterOption.status] = res;
        if (requestId != _filterContentRequestId) return;
        state.currentStatusItems = res.data?.items ?? [];
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

    // Handles leaveType or other options
    if (state.cachedFilterContent.containsKey(option)) {
      state.currentTypeItems =
          state.cachedFilterContent[option]!.data?.items ?? [];
      notifyListeners();
      return;
    }

    final requestId = ++_filterContentRequestId;
    _isFetchingFilterContent = true;
    notifyListeners();

    try {
      final res = await getExpenseFilterContentUseCase(
        source: source,
        view: viewStr,
        option: option,
      );
      state.cachedFilterContent[option] = res;
      if (requestId != _filterContentRequestId) return;
      state.currentTypeItems = res.data?.items ?? [];
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
  }

  Future<void> fetchMonthBucketItems({
    FilterSource source = FilterSource.timeoff,
    required String bucket,
    TimeOffListType? target,
  }) async {
    final activeTarget = target ?? _activeFilterTarget;
    final state = _filterStates[activeTarget]!;
    final viewStr = activeTarget.name;
    final normalizedBucket = bucket.toLowerCase();
    state.selectedMonthBucket = normalizedBucket;
    final requestId = ++_monthBucketRequestId;

    if (state.cachedMonthBucketItems.containsKey(normalizedBucket)) {
      state.currentMonthItems = state.cachedMonthBucketItems[normalizedBucket]!;
      notifyListeners();
      return;
    }

    _isFetchingFilterContent = true;
    notifyListeners();

    try {
      final res = await getExpenseFilterContentUseCase(
        source: source,
        view: viewStr,
        option: FilterOption.month,
        bucket: normalizedBucket,
      );
      final items = res.data?.items ?? [];
      state.cachedMonthBucketItems[normalizedBucket] = items;
      if (requestId != _monthBucketRequestId ||
          normalizedBucket != state.selectedMonthBucket) {
        return;
      }
      state.currentMonthItems = items;
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
        _isFetchingFilterContent = false;
        notifyListeners();
      }
    }
  }

  Future<void> selectFilterOption(
    FilterOption option, {
    TimeOffListType? target,
  }) async {
    final activeTarget = target ?? _activeFilterTarget;
    final state = _filterStates[activeTarget]!;
    if (state.selectedFilterOption == option) return;
    state.selectedFilterOption = option;
    if (!state.cachedFilterContent.containsKey(option)) {
      if (option == FilterOption.status) {
        state.currentStatusItems = [];
      } else if (option == FilterOption.month ||
          option == FilterOption.dateRange) {
        state.currentMonthItems = [];
      } else {
        state.currentTypeItems = [];
      }
      _isFetchingFilterContent = true;
    }
    notifyListeners();
    final firstBucket =
        (option == FilterOption.month || option == FilterOption.dateRange)
        ? findFirstBucketWithSelection(target: activeTarget)
        : null;
    await fetchFilterContent(
      option: option,
      bucket: firstBucket,
      target: activeTarget,
    );
  }

  Future<void> selectMonthBucket(
    String bucketKey, {
    TimeOffListType? target,
  }) async {
    final activeTarget = target ?? _activeFilterTarget;
    final state = _filterStates[activeTarget]!;
    final normalized = bucketKey.toLowerCase();
    if (state.selectedMonthBucket == normalized &&
        state.currentMonthItems.isNotEmpty) {
      return;
    }
    await fetchMonthBucketItems(bucket: normalized, target: activeTarget);
  }

  void toggleMonth(String monthId, {TimeOffListType? target}) {
    final state = _filterStates[target ?? _activeFilterTarget]!;
    state.isCustomRangeActive = false;
    if (state.selectedMonthIds.contains(monthId)) {
      state.selectedMonthIds.remove(monthId);
    } else {
      state.selectedMonthIds.add(monthId);
    }
    state.isMonthActive = state.selectedMonthIds.isNotEmpty;
    notifyListeners();
  }

  void toggleType(int typeId, {TimeOffListType? target}) {
    final state = _filterStates[target ?? _activeFilterTarget]!;
    if (state.selectedTypeIds.contains(typeId)) {
      state.selectedTypeIds.remove(typeId);
    } else {
      state.selectedTypeIds.add(typeId);
    }
    notifyListeners();
  }

  void toggleStatus(String statusId, {TimeOffListType? target}) {
    final state = _filterStates[target ?? _activeFilterTarget]!;
    if (state.selectedStatusIds.contains(statusId)) {
      state.selectedStatusIds.remove(statusId);
    } else {
      state.selectedStatusIds.add(statusId);
    }
    notifyListeners();
  }

  final Map<TimeOffListType, Future<void>?> _inFlightApplyFilters = {};
  final Map<TimeOffListType, int> _filterOperationIds = {
    TimeOffListType.upcoming: 0,
    TimeOffListType.history: 0,
  };

  Future<void> applyServerFilters({
    FilterSource source = FilterSource.timeoff,
    TimeOffListType? target,
  }) async {
    if (_isFiltering) return;
    final activeTarget = target ?? _activeFilterTarget;
    final state = _filterStates[activeTarget]!;
    if (!state.hasFilterChanges) return;
    final viewStr = activeTarget.name;

    final currentOpId = (_filterOperationIds[activeTarget] =
        (_filterOperationIds[activeTarget] ?? 0) + 1);

    cancelDebounce();
    _isFiltering = true;
    _errorMessage = null;
    notifyListeners();

    final completer = Completer<void>();
    _inFlightApplyFilters[activeTarget] = completer.future;

    try {
      AppException? lastAppException;
      Object? lastError;

      // 1. Date Filter: Apply Date Range or Month sequentially
      try {
        if (state.isCustomRangeActive && state.selectedDateRange != null) {
          state.selectedMonthIds.clear();
          final fromStr = DateFormat(
            'yyyy-MM-dd',
          ).format(state.selectedDateRange!.start);
          final toStr = DateFormat(
            'yyyy-MM-dd',
          ).format(state.selectedDateRange!.end);
          await applyExpenseFilterUseCase(
            source: source,
            view: viewStr,
            option: FilterOption.dateRange,
            data: {
              'from_date': fromStr,
              'to_date': toStr,
              'start_date': fromStr,
              'end_date': toStr,
            },
          );
        } else if (state.isMonthActive && state.selectedMonthIds.isNotEmpty) {
          state.appliedMonthBucket = state.selectedMonthBucket;
          state.selectedDateRange = null;
          final allMonthIds = state.selectedMonthIds.toList();
          await applyExpenseFilterUseCase(
            source: source,
            view: viewStr,
            option: FilterOption.month,
            data: {'month_ids': allMonthIds},
          );
        } else {
          state.selectedMonthIds.clear();
          state.selectedDateRange = null;
          state.isCustomRangeActive = false;
          state.isMonthActive = false;
          state.appliedMonthBucket = firstBucketKey;
          state.selectedMonthBucket = firstBucketKey;
          await applyExpenseFilterUseCase(
            source: source,
            view: viewStr,
            option: FilterOption.dateRange,
            data: {},
          );
          await applyExpenseFilterUseCase(
            source: source,
            view: viewStr,
            option: FilterOption.month,
            data: {'month_ids': []},
          );
        }
      } on AppException catch (e) {
        lastAppException = e;
      } catch (e) {
        lastError = e;
      }

      if (currentOpId != _filterOperationIds[activeTarget]) return;

      // 2. Leave Type Filter (not blocked by Date/Month)
      try {
        await applyExpenseFilterUseCase(
          source: source,
          view: viewStr,
          option: FilterOption.leaveType,
          data: {
            'type_ids': state.selectedTypeIds.toList(),
            'leave_type_ids': state.selectedTypeIds.toList(),
            'category_ids': state.selectedTypeIds.toList(),
          },
        );
      } on AppException catch (e) {
        lastAppException = e;
      } catch (e) {
        lastError = e;
      }

      if (currentOpId != _filterOperationIds[activeTarget]) return;

      // 3. Status Filter (not blocked by Date/Month or Leave Type)
      try {
        await applyExpenseFilterUseCase(
          source: source,
          view: viewStr,
          option: FilterOption.status,
          data: {'status_ids': state.selectedStatusIds.toList()},
        );
      } on AppException catch (e) {
        lastAppException = e;
      } catch (e) {
        lastError = e;
      }

      if (currentOpId != _filterOperationIds[activeTarget]) return;

      if (lastAppException == null && lastError == null) {
        state.snapshotAppliedFilters();
      }

      if (activeTarget == TimeOffListType.upcoming) {
        await fetchInitialUpcomingLeaves(isRefresh: true);
      } else if (activeTarget == TimeOffListType.history) {
        await fetchInitialHistory(isRefresh: true);
      } else {
        await Future.wait([
          fetchInitialUpcomingLeaves(isRefresh: true),
          fetchInitialHistory(isRefresh: true),
        ]);
      }

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
      _inFlightApplyFilters[activeTarget] = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
      notifyListeners();
    }
  }

  final Map<TimeOffListType, Future<void>?> _inFlightResetFilters = {};

  Future<void> resetServerFilters({
    FilterSource source = FilterSource.timeoff,
    TimeOffListType? target,
    bool executeFetch = true,
  }) async {
    final activeTarget = target ?? _activeFilterTarget;
    if (_inFlightResetFilters[activeTarget] != null) {
      try {
        await _inFlightResetFilters[activeTarget];
      } catch (e) {
        debugPrint(
          'TimeOffProvider: In-flight reset filters completed with error ($activeTarget): $e',
        );
      }
      if (executeFetch) {
        if (activeTarget == TimeOffListType.upcoming) {
          await fetchInitialUpcomingLeaves(isRefresh: true);
        } else if (activeTarget == TimeOffListType.history) {
          await fetchInitialHistory(isRefresh: true);
        } else {
          await Future.wait([
            fetchInitialUpcomingLeaves(isRefresh: true),
            fetchInitialHistory(isRefresh: true),
          ]);
        }
      }
      return;
    }

    final currentResetOpId = (_filterOperationIds[activeTarget] =
        (_filterOperationIds[activeTarget] ?? 0) + 1);

    if (_inFlightApplyFilters[activeTarget] != null) {
      try {
        await _inFlightApplyFilters[activeTarget];
      } catch (e) {
        debugPrint(
          'TimeOffProvider: In-flight apply filters completed with error ($activeTarget): $e',
        );
      }
    }

    cancelDebounce();
    final state = _filterStates[activeTarget]!;
    final viewStr = activeTarget.name;

    state.reset();
    _isFiltering = true;
    _errorMessage = null;
    notifyListeners();

    final completer = Completer<void>();
    _inFlightResetFilters[activeTarget] = completer.future;

    try {
      await Future.wait([
        applyExpenseFilterUseCase(
          source: source,
          view: viewStr,
          option: FilterOption.dateRange,
          data: {},
        ),
        applyExpenseFilterUseCase(
          source: source,
          view: viewStr,
          option: FilterOption.month,
          data: {'month_ids': []},
        ),
        applyExpenseFilterUseCase(
          source: source,
          view: viewStr,
          option: FilterOption.leaveType,
          data: {'type_ids': [], 'leave_type_ids': [], 'category_ids': []},
        ),
        applyExpenseFilterUseCase(
          source: source,
          view: viewStr,
          option: FilterOption.status,
          data: {'status_ids': []},
        ),
      ]);
      if (currentResetOpId == _filterOperationIds[activeTarget] &&
          executeFetch) {
        if (activeTarget == TimeOffListType.upcoming) {
          await fetchInitialUpcomingLeaves(isRefresh: true);
        } else if (activeTarget == TimeOffListType.history) {
          await fetchInitialHistory(isRefresh: true);
        } else {
          await Future.wait([
            fetchInitialUpcomingLeaves(isRefresh: true),
            fetchInitialHistory(isRefresh: true),
          ]);
        }
      }
    } on AppException catch (e) {
      _errorMessage = e.message ?? e.toString();
    } catch (e) {
      _errorMessage =
          ApiErrorHandler.handle(e).message ??
          ApiErrorHandler.handle(e).toString();
    } finally {
      _isFiltering = false;
      _inFlightResetFilters[activeTarget] = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
      notifyListeners();
    }
  }

  Future<void> fetchAvailableTypes() async {
    try {
      final response = await getTimeOffTypesUseCase();
      _availableTypes = response;
      if (_calendarMonthData != null) {
        _processEventDots(_calendarMonthData!);
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> calculateDuration({
    required int typeId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    _isCalculatingDuration = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await calculateTimeOffDurationUseCase(
        typeId: typeId,
        startDate: AppDateFormatter.ymdSlash(startDate),
        endDate: AppDateFormatter.ymdSlash(endDate),
      );
      _calculatedDuration = response;
    } catch (e) {
      _calculatedDuration = null;
      _errorMessage = e.toString();
    } finally {
      _isCalculatingDuration = false;
      notifyListeners();
    }
  }

  void clearCalculatedDuration() {
    _calculatedDuration = null;
    notifyListeners();
  }

  Future<bool> submitLeaveRequest({
    required int typeId,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async {
    _isSubmittingRequest = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await submitTimeOffRequestUseCase(
        typeId: typeId,
        startDate: AppDateFormatter.ymdSlash(startDate),
        endDate: AppDateFormatter.ymdSlash(endDate),
        reason: reason,
      );

      // Refresh data on success in background without failing the submission if refresh fails
      try {
        final refreshFutures = <Future>[
          fetchTimeOffData(),
          fetchAvailableTypes(),
          fetchInitialHistory(),
        ];

        final targetYear = _calendarMonthData?.year ?? startDate.year;
        final targetMonth = _calendarMonthData?.month ?? startDate.month;
        refreshFutures.add(
          fetchTimeOffCalendarMonth(year: targetYear, month: targetMonth),
        );

        final selectedFormatted = AppDateFormatter.ymdSlash(startDate);
        final dateToFetch = _activeSelectedDate.isNotEmpty
            ? _activeSelectedDate
            : selectedFormatted;
        refreshFutures.add(fetchTimeOffCalendarDay(date: dateToFetch));

        await Future.wait(refreshFutures);
      } catch (refreshError) {
        debugPrint(
          '[TimeOffProvider] Background refresh after submit failed: $refreshError',
        );
      }

      return true;
    } on SubmissionOutcomeUnknownException catch (e) {
      // The connection dropped after the request went out: the leave may or
      // may not exist. Do not resubmit -- check, tell the user, refresh.
      _errorMessage = e.message;
      _checkLostLeaveSubmission(startDate, endDate);
      return false;
    } on AppException catch (e) {
      _errorMessage = e.message ?? e.toString();
      return false;
    } catch (e) {
      final handled = ApiErrorHandler.handle(e);
      _errorMessage = handled.message ?? handled.toString();
      return false;
    } finally {
      _isSubmittingRequest = false;
      notifyListeners();
    }
  }

  /// After a lost reply: is there a leave with exactly these dates?
  /// Odoo refuses overlaps, so a match is this request.
  void _checkLostLeaveSubmission(DateTime startDate, DateTime endDate) {
    final start = AppDateFormatter.ymdSlash(startDate).replaceAll('/', '-');
    final end = AppDateFormatter.ymdSlash(endDate).replaceAll('/', '-');

    Future<void> refresh() async {
      final futures = <Future>[
        fetchTimeOffData(),
        fetchAvailableTypes(),
        fetchInitialHistory(),
        fetchTimeOffCalendarMonth(
          year: _calendarMonthData?.year ?? startDate.year,
          month: _calendarMonthData?.month ?? startDate.month,
        ),
      ];
      if (_activeSelectedDate.isNotEmpty) {
        futures.add(fetchTimeOffCalendarDay(date: _activeSelectedDate));
      }
      await Future.wait(futures);
    }

    LostSubmissionChecker.start(
      label: (l10n) => l10n?.lostSubmissionTimeOff ?? 'time off request',
      refresh: refresh,
      isSaved: () async {
        final schedule = await getTimeOffCalendarDayUseCase(
          date: AppDateFormatter.ymdSlash(startDate),
        );
        return schedule.items.any(
          (item) =>
              item.startDate.startsWith(start) && item.endDate.startsWith(end),
        );
      },
    );
  }

  bool _isDisposed = false;

  // --- Log Notes State & Methods ---
  final Map<int, List<LogNoteModel>> _timeOffLogs = {};
  final Map<int, String?> _timeOffLogErrors = {};

  bool _isLoadingLogs = false;
  bool get isLoadingLogs => _isLoadingLogs;

  bool _isAddingLogNote = false;
  bool get isAddingLogNote => _isAddingLogNote;

  bool _isSubmittingLogNote = false;
  bool get isSubmittingLogNote => _isSubmittingLogNote;

  String? getLogErrorForTimeOff(int timeOffId) => _timeOffLogErrors[timeOffId];

  Future<void> fetchTimeOffLogs(int timeOffId) async {
    _isLoadingLogs = true;
    _timeOffLogErrors[timeOffId] = null;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await getLogNotesUseCase('timeoff', timeOffId);
      _timeOffLogs[timeOffId] = response.messages;
      _timeOffLogErrors[timeOffId] = null;
    } catch (e) {
      String message = e.toString();
      if (message.startsWith('Exception: ')) {
        message = message.substring(11);
      }
      _timeOffLogErrors[timeOffId] = message;
      _errorMessage = message;
    } finally {
      _isLoadingLogs = false;
      notifyListeners();
    }
  }

  List<LogNoteModel> getLogsForTimeOff(int timeOffId) {
    if (!_timeOffLogs.containsKey(timeOffId)) {
      return [];
    }
    return List.unmodifiable(_timeOffLogs[timeOffId]!);
  }

  Future<bool> addLogNote(
    int timeOffId,
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
        source: 'timeoff',
        id: timeOffId,
        text: message,
        files: files,
        mentionNames: mentionNames,
        bodyPartsJson: bodyPartsJson,
      );
      if (!_timeOffLogs.containsKey(timeOffId)) {
        _timeOffLogs[timeOffId] = [];
      }
      _timeOffLogs[timeOffId]!.insert(0, createdLog);
      await fetchTimeOffLogs(timeOffId);
      return true;
    } on SubmissionOutcomeUnknownException catch (e) {
      _errorMessage = e.message;
      LostSubmissionChecker.startLogNote(
        before: getLogsForTimeOff(timeOffId),
        text: message,
        fetch: () async =>
            (await getLogNotesUseCase('timeoff', timeOffId)).messages,
        refresh: () => fetchTimeOffLogs(timeOffId),
      );
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isAddingLogNote = false;
      notifyListeners();
    }
  }

  Future<bool> editLogNote(
    int messageId,
    String text,
    int timeOffId, {
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

      final currentLogs = _timeOffLogs[timeOffId] ?? [];
      final index = currentLogs.indexWhere(
        (log) => log.id == messageId.toString(),
      );
      if (index != -1) {
        currentLogs[index] = updatedLog;
        _timeOffLogs[timeOffId] = List.from(currentLogs);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmittingLogNote = false;
      notifyListeners();
    }
  }

  Future<bool> deleteLogNote(int timeOffId, int messageId) async {
    final logs = _timeOffLogs[timeOffId];
    if (logs != null) {
      final index = logs.indexWhere((l) => l.id == messageId.toString());
      if (index != -1) {
        try {
          await deleteLogNoteUseCase(messageId);
          logs.removeAt(index);
          notifyListeners();
          return true;
        } catch (e) {
          _errorMessage = e.toString();
          notifyListeners();
          return false;
        }
      }
    }
    return false;
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }
}
