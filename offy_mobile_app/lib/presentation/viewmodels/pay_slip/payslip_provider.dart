import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/errors/api_error_handler.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/lost_submission_checker.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/file_download_worker.dart';

import '../../../data/models/filter_model.dart';
import '../../../data/models/payslip_response_model.dart';
import '../../../domain/usecases/apply_expense_filter_usecase.dart';
import '../../../domain/usecases/get_expense_filter_content_usecase.dart';
import '../../../domain/usecases/get_expense_filter_options_usecase.dart';
import '../../../domain/usecases/get_payslip_usecase.dart';
import '../../../domain/usecases/download_payslip_usecase.dart';
import '../../../domain/usecases/get_payslip_history_usecase.dart';
import '../../../domain/usecases/get_log_notes_usecase.dart';
import '../../../domain/usecases/create_log_note_usecase.dart';
import '../../../domain/usecases/update_log_note_usecase.dart';
import '../../../domain/usecases/delete_log_note_usecase.dart';
import '../../../data/models/log_note_model.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/base/session_provider.dart';

class PayslipProvider extends SessionProvider {
  final GetPayslipUseCase getPayslipUseCase;
  final DownloadPayslipUseCase downloadPayslipUseCase;
  final GetPayslipHistoryUseCase getPayslipHistoryUseCase;
  final GetLogNotesUseCase getLogNotesUseCase;
  final CreateLogNoteUseCase createLogNoteUseCase;
  final UpdateLogNoteUseCase updateLogNoteUseCase;
  final DeleteLogNoteUseCase deleteLogNoteUseCase;
  final GetExpenseFilterOptionsUseCase getExpenseFilterOptionsUseCase;
  final GetExpenseFilterContentUseCase getExpenseFilterContentUseCase;
  final ApplyExpenseFilterUseCase applyExpenseFilterUseCase;

  PayslipProvider({
    required this.getPayslipUseCase,
    required this.downloadPayslipUseCase,
    required this.getPayslipHistoryUseCase,
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
    _payslip = null;
    _historyPayslips = [];
    _currentHistoryPage = 1;
    _hasMoreHistory = true;
    _payslipLogs.clear();
    _inFlightPdfFetches.clear();
    _isLoading = false;
    _isFetchingHistory = false;
    _isFetchingMoreHistory = false;
    _isLoadingLogs = false;
    _isSubmittingLogNote = false;
    _errorMessage = null;
    _currentSearchQuery = '';
    _currentMonthItems = [];
    _selectedMonthIds.clear();
    _isInitialized = false;
    _isSearching = false;
    _isFiltering = false;
    _isMonthActive = false;
    _appliedMonthBucket = 'recent';
    _selectedMonthBucket = 'recent';
    _filterOptionsFuture = null;
    _filterOptions = [];
    _cachedFilterContent.clear();
    _cachedMonthBucketItems.clear();
    _searchFilterRequestId = 0;
    _activeSearchRequestId = 0;
    _filterContentRequestId = 0;
    _monthBucketRequestId = 0;
    _debounceTimer?.cancel();
    _inFlightApplyFilters = null;
    _inFlightResetFilters = null;
    ++_filterOperationId;
    notifyListeners();
  }

  PayslipModel? _payslip;
  PayslipModel? get payslip => _payslip;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<PayslipModel> _historyPayslips = [];
  List<PayslipModel> get historyPayslips => _historyPayslips;

  bool _isFetchingHistory = false;
  bool get isFetchingHistory => _isFetchingHistory;

  bool _isFetchingMoreHistory = false;
  bool get isFetchingMoreHistory => _isFetchingMoreHistory;

  int _currentHistoryPage = 1;
  bool _hasMoreHistory = true;
  bool get hasMoreHistory => _hasMoreHistory;

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

  String _currentSearchQuery = '';
  String get currentSearchQuery => _currentSearchQuery;

  final Map<String, dynamic> _activeFilters = {};
  Map<String, dynamic> get activeFilters => Map.unmodifiable(_activeFilters);

  bool _isMonthActive = false;
  bool get isMonthActive => _isMonthActive;

  bool get hasActiveFilters =>
      _activeFilters.isNotEmpty ||
      (_isMonthActive && selectedMonthIds.isNotEmpty);

  bool isOptionActive(FilterOption option) {
    switch (option) {
      case FilterOption.month:
      case FilterOption.dateRange:
        return _isMonthActive && selectedMonthIds.isNotEmpty;
      case FilterOption.category:
      case FilterOption.leaveType:
      case FilterOption.status:
        return false;
    }
  }

  int _searchFilterRequestId = 0;
  int _activeSearchRequestId = 0;
  int _filterContentRequestId = 0;
  int _monthBucketRequestId = 0;

  // Advanced Server Filter State
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
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

  final Set<String> _selectedMonthIds = {};

  Set<String> get currentBucketSelectedMonthIds =>
      Set.unmodifiable(_selectedMonthIds);

  Set<String> get selectedMonthIds => Set.unmodifiable(_selectedMonthIds);

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

  List<FilterItemModel> _currentMonthItems = [];
  List<FilterItemModel> get currentMonthItems => _currentMonthItems;

  bool _isCustomRangeAvailable = false;
  bool get customRangeAvailable => _isCustomRangeAvailable;

  // Applied Filter Snapshot (for deep dirty checking)
  Set<String> _snapshotAppliedMonths = {};
  bool _snapshotAppliedIsMonthActive = false;

  void _snapshotAppliedFilters() {
    _snapshotAppliedMonths = Set<String>.from(_selectedMonthIds);
    _snapshotAppliedIsMonthActive = _isMonthActive;
  }

  bool get hasFilterChanges {
    if (_isMonthActive != _snapshotAppliedIsMonthActive) return true;
    if (_isMonthActive) {
      return !setEquals(_selectedMonthIds, _snapshotAppliedMonths);
    }
    return false;
  }

  /// Back without Apply: restores the last applied selections (no API call).
  void discardFilterChanges() {
    _selectedMonthIds
      ..clear()
      ..addAll(_snapshotAppliedMonths);
    _isMonthActive = _snapshotAppliedIsMonthActive;
    notifyListeners();
  }

  /// Reset button: clears the selections only; nothing is sent until Apply.
  void clearFilterSelections() {
    _selectedMonthIds.clear();
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
    FilterSource source = FilterSource.payslip,
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
          _isMonthActive = active.monthIds.isNotEmpty;
          _selectedMonthIds.clear();
          if (active.monthIds.isNotEmpty) {
            _selectedMonthIds.addAll(active.monthIds);
          }
        }
        _snapshotAppliedFilters();
        notifyListeners();
      }
    } catch (e) {
      // Non-blocking background sync failures should not disrupt UI display
      debugPrint('PayslipProvider.syncActiveFilters failed: $e');
    }
  }

  Future<void> fetchPayslip() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await getPayslipUseCase();
      _payslip = response;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  final Map<String, Future<Uint8List?>> _inFlightPdfFetches = {};

  Future<bool> downloadPayslipPdf(
    PayslipModel payslip, {
    Uint8List? existingBytes,
  }) async {
    try {
      final fileName = FileDownloadWorker.safeFileName(
        payslip.filename,
        'payslip_${payslip.id}.pdf',
      );

      final dir = await getApplicationDocumentsDirectory();
      final targetPath = '${dir.path}/$fileName';

      // 1. If existing bytes are already available, prepare directly in background isolate
      if (existingBytes != null && existingBytes.isNotEmpty) {
        final readyFile = await FileDownloadWorker.prepareFileInIsolate(
          targetPath: targetPath,
          bytes: existingBytes,
        );
        final result = await OpenFilex.open(readyFile.path);
        return result.type == ResultType.done;
      }

      // 2. If downloadUrl is present, resolve auth headers on main thread and stream directly in isolate
      if (payslip.downloadUrl.isNotEmpty) {
        Map<String, String>? headers;
        if (payslip.downloadRequiresAuth) {
          headers = await ApiClient.getMediaHeaders(payslip.downloadUrl);
        }
        final readyFile = await FileDownloadWorker.prepareFileInIsolate(
          targetPath: targetPath,
          url: payslip.downloadUrl,
          headers: headers,
        );
        final result = await OpenFilex.open(readyFile.path);
        return result.type == ResultType.done;
      }

      // 3. Otherwise fetch via payslip.id (which returns base64 model) and decode in isolate
      final downloadModel = await downloadPayslipUseCase(payslip.id);
      final readyFile = await FileDownloadWorker.prepareFileInIsolate(
        targetPath: targetPath,
        base64Payload: downloadModel.base64,
      );

      final result = await OpenFilex.open(readyFile.path);
      return result.type == ResultType.done;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Uint8List?> fetchPayslipPdfBytes(PayslipModel payslip) {
    final key = payslip.downloadUrl.isNotEmpty
        ? payslip.downloadUrl
        : 'id_${payslip.id}';

    if (_inFlightPdfFetches.containsKey(key)) {
      return _inFlightPdfFetches[key]!;
    }

    final future = _executeFetchPdfBytes(payslip).whenComplete(() {
      _inFlightPdfFetches.remove(key);
    });

    _inFlightPdfFetches[key] = future;
    return future;
  }

  Future<Uint8List?> _executeFetchPdfBytes(PayslipModel payslip) async {
    try {
      if (payslip.downloadUrl.isNotEmpty) {
        return await downloadPayslipUseCase.fromUrl(
          payslip.downloadUrl,
          requiresAuth: payslip.downloadRequiresAuth,
        );
      }
      final downloadModel = await downloadPayslipUseCase(payslip.id);
      return base64Decode(downloadModel.base64);
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    }
  }

  Future<void> fetchInitialHistoryPayslips({bool isRefresh = false}) async {
    final requestId = ++_searchFilterRequestId;
    _activeSearchRequestId++;
    _isSearching = false;
    _currentHistoryPage = 1;
    _hasMoreHistory = true;
    _isFetchingHistory = true;
    if (_historyPayslips.isEmpty) {
      _historyPayslips = [];
    }
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await getPayslipHistoryUseCase(
        page: _currentHistoryPage,
        limit: 10,
        search: _currentSearchQuery.isNotEmpty ? _currentSearchQuery : null,
        filters: _activeFilters.isNotEmpty ? _activeFilters : null,
        forceRefresh: isRefresh,
      );
      if (requestId != _searchFilterRequestId) return;
      _historyPayslips = response.payslips;
      _hasMoreHistory = response.pagination.hasNext;
    } catch (e) {
      if (requestId != _searchFilterRequestId) return;
      _errorMessage = e.toString();
    } finally {
      if (requestId == _searchFilterRequestId) {
        _isFetchingHistory = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchMoreHistoryPayslips() async {
    if (_isFetchingHistory ||
        _isSearching ||
        _isFiltering ||
        !_hasMoreHistory) {
      return;
    }

    final requestId = _searchFilterRequestId;
    _isFetchingHistory = true;
    _isFetchingMoreHistory = true;
    notifyListeners();

    try {
      final nextPage = _currentHistoryPage + 1;
      final response = await getPayslipHistoryUseCase(
        page: nextPage,
        limit: 10,
        search: _currentSearchQuery.isNotEmpty ? _currentSearchQuery : null,
        filters: _activeFilters.isNotEmpty ? _activeFilters : null,
      );
      if (requestId != _searchFilterRequestId) return;
      _currentHistoryPage = nextPage;
      _historyPayslips.addAll(response.payslips);
      _hasMoreHistory = response.pagination.hasNext;
    } catch (e) {
      if (requestId != _searchFilterRequestId) return;
      _errorMessage = e.toString();
    } finally {
      if (requestId == _searchFilterRequestId) {
        _isFetchingHistory = false;
        _isFetchingMoreHistory = false;
        notifyListeners();
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

  Future<void> _executeSearchOrFilter({required bool isSearchOperation}) async {
    final requestId = ++_searchFilterRequestId;
    int? searchId;
    if (isSearchOperation) {
      searchId = ++_activeSearchRequestId;
      _isSearching = true;
    } else {
      _isFiltering = true;
    }
    _currentHistoryPage = 1;
    _hasMoreHistory = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await getPayslipHistoryUseCase(
        page: _currentHistoryPage,
        limit: 10,
        search: _currentSearchQuery.isNotEmpty ? _currentSearchQuery : null,
        filters: _activeFilters.isNotEmpty ? _activeFilters : null,
      );
      if (requestId != _searchFilterRequestId) return;
      _historyPayslips = response.payslips;
      _hasMoreHistory = response.pagination.hasNext;
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

  Future<void> initFilters({FilterSource source = FilterSource.payslip}) async {
    _selectedFilterOption = FilterOption.month;
    _currentMonthItems = [];
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
          _selectedMonthIds.clear();
          _isMonthActive = active.monthIds.isNotEmpty;
          if (active.monthIds.isNotEmpty) {
            _selectedMonthIds.addAll(active.monthIds);
          } else {
            _appliedMonthBucket = firstBucketKey;
            _selectedMonthBucket = firstBucketKey;
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
      } else if (_filterOptions.any((o) => o.filterOption == FilterOption.month)) {
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

    final firstBucket = (_selectedFilterOption == FilterOption.month ||
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
    FilterSource source = FilterSource.payslip,
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
    FilterSource source = FilterSource.payslip,
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
          _isCustomRangeAvailable = res.data?.customRangeAvailable ?? false;
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
        _isCustomRangeAvailable = res.data?.customRangeAvailable ?? false;
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

    final requestId = ++_filterContentRequestId;
    if (_cachedFilterContent.containsKey(option)) {
      notifyListeners();
      return;
    }

    _isFetchingFilterContent = true;
    notifyListeners();

    try {
      final res = await getExpenseFilterContentUseCase(
        source: source,
        option: option,
      );
      _cachedFilterContent[option] = res;
      if (requestId != _filterContentRequestId) return;
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
    FilterSource source = FilterSource.payslip,
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
        _isFetchingFilterContent = false;
        notifyListeners();
      }
    }
  }

  Future<void> selectFilterOption(FilterOption option) async {
    if (_selectedFilterOption == option) return;
    _selectedFilterOption = option;
    if (!_cachedFilterContent.containsKey(option)) {
      _currentMonthItems = [];
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
    if (_selectedMonthIds.contains(monthId)) {
      _selectedMonthIds.remove(monthId);
    } else {
      _selectedMonthIds.add(monthId);
    }
    _isMonthActive = _selectedMonthIds.isNotEmpty;
    notifyListeners();
  }

  void deactivateMonthFilter() {
    _isMonthActive = false;
    notifyListeners();
  }

  void clearNeutralStateSelections() {
    if (_selectedMonthIds.isEmpty) {
      _isMonthActive = false;
    }
    if (!_isMonthActive) {
      _selectedMonthIds.clear();
      notifyListeners();
    }
  }

  void clearMonthSelection() {
    _selectedMonthIds.clear();
    _isMonthActive = false;
    notifyListeners();
  }

  void selectMonthOption() {
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

  Future<void>? _inFlightApplyFilters;
  int _filterOperationId = 0;

  Future<void> applyServerFilters({
    FilterSource source = FilterSource.payslip,
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

    try {
      if (_isMonthActive && _selectedMonthIds.isNotEmpty) {
        _appliedMonthBucket = _selectedMonthBucket;
        final allMonthIds = _selectedMonthIds.toList();
        await applyExpenseFilterUseCase(
          source: source,
          option: FilterOption.month,
          data: {'month_ids': allMonthIds},
        );
      } else {
        _selectedMonthIds.clear();
        _isMonthActive = false;
        _appliedMonthBucket = firstBucketKey;
        _selectedMonthBucket = firstBucketKey;
        await applyExpenseFilterUseCase(
          source: source,
          option: FilterOption.month,
          data: {'month_ids': []},
        );
      }

      if (currentOpId != _filterOperationId) return;

      _snapshotAppliedFilters();
      await fetchInitialHistoryPayslips(isRefresh: true);
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
    FilterSource source = FilterSource.payslip,
    bool executeFetch = true,
  }) async {
    if (_inFlightResetFilters != null) {
      try {
        await _inFlightResetFilters;
      } catch (e) {
        debugPrint('PayslipProvider: In-flight reset filters completed with error: $e');
      }
      if (executeFetch) {
        await fetchInitialHistoryPayslips(isRefresh: true);
      }
      return;
    }

    final currentResetOpId = ++_filterOperationId;

    if (_inFlightApplyFilters != null) {
      try {
        await _inFlightApplyFilters;
      } catch (e) {
        debugPrint('PayslipProvider: In-flight apply filters completed with error: $e');
      }
    }

    cancelDebounce();
    _selectedMonthIds.clear();
    _appliedMonthBucket = 'recent';
    _selectedMonthBucket = 'recent';
    _isInitialized = false;
    _isMonthActive = false;
    _snapshotAppliedFilters();
    _isFiltering = true;
    _errorMessage = null;
    notifyListeners();

    final completer = Completer<void>();
    _inFlightResetFilters = completer.future;

    try {
      await applyExpenseFilterUseCase(
        source: source,
        option: FilterOption.month,
        data: {'month_ids': []},
      );
      if (currentResetOpId == _filterOperationId && executeFetch) {
        await fetchInitialHistoryPayslips(isRefresh: true);
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

  // --- Log Note Integration ---
  final Map<int, List<LogNoteModel>> _payslipLogs = {};
  final Map<int, String?> _payslipLogErrors = {};
  bool _isLoadingLogs = false;
  bool get isLoadingLogs => _isLoadingLogs;

  bool _isSubmittingLogNote = false;
  bool get isSubmittingLogNote => _isSubmittingLogNote;

  List<LogNoteModel> getLogsForPayslip(int payslipId) {
    return List.unmodifiable(_payslipLogs[payslipId] ?? []);
  }

  String? getLogErrorForPayslip(int payslipId) => _payslipLogErrors[payslipId];

  Future<void> fetchPayslipLogs(int payslipId) async {
    _isLoadingLogs = true;
    _payslipLogErrors[payslipId] = null;
    notifyListeners();

    try {
      final response = await getLogNotesUseCase('payslip', payslipId);
      _payslipLogs[payslipId] = response.messages;
      _payslipLogErrors[payslipId] = null;
    } catch (e) {
      debugPrint('Failed to fetch payslip logs: $e');
      String message = e.toString();
      if (message.startsWith('Exception: ')) {
        message = message.substring(11);
      }
      _payslipLogErrors[payslipId] = message;
      if (!_payslipLogs.containsKey(payslipId)) {
        _payslipLogs[payslipId] = [];
      }
    } finally {
      _isLoadingLogs = false;
      notifyListeners();
    }
  }

  Future<bool> addLogNote(
    int payslipId,
    String text, {
    List<XFile> files = const [],
    List<String>? mentionNames,
    String? bodyPartsJson,
  }) async {
    try {
      final createdLog = await createLogNoteUseCase(
        source: 'payslip',
        id: payslipId,
        text: text,
        files: files,
        mentionNames: mentionNames ?? [],
        bodyPartsJson: bodyPartsJson,
      );
      if (!_payslipLogs.containsKey(payslipId)) {
        _payslipLogs[payslipId] = [];
      }
      _payslipLogs[payslipId]!.insert(0, createdLog);
      await fetchPayslipLogs(payslipId);
      notifyListeners();
      return true;
    } on SubmissionOutcomeUnknownException {
      LostSubmissionChecker.startLogNote(
        before: List.of(_payslipLogs[payslipId] ?? const []),
        text: text,
        fetch: () async =>
            (await getLogNotesUseCase('payslip', payslipId)).messages,
        refresh: () => fetchPayslipLogs(payslipId),
      );
      return false;
    } catch (e) {
      debugPrint('Failed to add payslip log note: $e');
      return false;
    }
  }

  Future<bool> editLogNote(
    int messageId,
    String text,
    int payslipId, {
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

      final currentLogs = _payslipLogs[payslipId] ?? [];
      final index = currentLogs.indexWhere(
        (log) => log.id == messageId.toString(),
      );
      if (index != -1) {
        currentLogs[index] = updatedLog;
        _payslipLogs[payslipId] = List.from(currentLogs);
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

  Future<bool> deleteLogNote(int payslipId, int messageId) async {
    final logs = _payslipLogs[payslipId];
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

  bool _isDisposed = false;

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
