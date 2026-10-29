import 'package:flutter/material.dart';
import '../../../data/models/calendar_month_response_model.dart';
import '../../../data/models/calendar_day_schedule_model.dart';
import '../../../domain/usecases/get_calendar_month_usecase.dart';
import '../../../domain/usecases/get_calendar_day_usecase.dart';
import '../../../domain/usecases/create_calendar_event_usecase.dart';
import '../../../domain/usecases/delete_calendar_event_usecase.dart';
import '../../../domain/usecases/update_calendar_event_usecase.dart';
import '../../../domain/usecases/get_log_notes_usecase.dart';
import '../../../domain/usecases/create_log_note_usecase.dart';
import '../../../domain/usecases/update_log_note_usecase.dart';
import '../../../domain/usecases/delete_log_note_usecase.dart';
import '../../../data/models/log_note_model.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/errors/api_error_handler.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/lost_submission_checker.dart';

class CalendarProvider extends ChangeNotifier {
  final GetCalendarMonthUseCase getCalendarMonthUseCase;
  final GetCalendarDayUseCase getCalendarDayUseCase;
  final CreateCalendarEventUseCase createCalendarEventUseCase;
  final DeleteCalendarEventUseCase deleteCalendarEventUseCase;
  final UpdateCalendarEventUseCase updateCalendarEventUseCase;
  final GetLogNotesUseCase getLogNotesUseCase;
  final CreateLogNoteUseCase createLogNoteUseCase;
  final UpdateLogNoteUseCase updateLogNoteUseCase;
  final DeleteLogNoteUseCase deleteLogNoteUseCase;

  CalendarProvider({
    required this.getCalendarMonthUseCase,
    required this.getCalendarDayUseCase,
    required this.createCalendarEventUseCase,
    required this.deleteCalendarEventUseCase,
    required this.updateCalendarEventUseCase,
    required this.getLogNotesUseCase,
    required this.createLogNoteUseCase,
    required this.updateLogNoteUseCase,
    required this.deleteLogNoteUseCase,
  });

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isCreatingEvent = false;
  bool get isCreatingEvent => _isCreatingEvent;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  CalendarMonthDataModel? _calendarMonthData;
  CalendarMonthDataModel? get calendarMonthData => _calendarMonthData;

  Map<int, List<Color>> _eventDotsByDay = {};
  Map<int, List<Color>> get eventDotsByDay => _eventDotsByDay;

  bool _isScheduleLoading = false;
  bool get isScheduleLoading => _isScheduleLoading;

  String? _scheduleErrorMessage;
  String? get scheduleErrorMessage => _scheduleErrorMessage;

  CalendarDayScheduleModel? _selectedDaySchedule;
  CalendarDayScheduleModel? get selectedDaySchedule => _selectedDaySchedule;

  int _monthRequestId = 0;
  int _dayRequestId = 0;
  String _activeSelectedDate = '';

  Future<void> fetchCalendarMonth({
    required int year,
    required int month,
  }) async {
    final currentRequestId = ++_monthRequestId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await getCalendarMonthUseCase(year: year, month: month);
      // Ignore stale response if a newer month request was triggered
      if (currentRequestId != _monthRequestId) return;

      _calendarMonthData = data;
      _processEventDots(data);
    } catch (e) {
      if (currentRequestId != _monthRequestId) return;
      _errorMessage = e.toString();
    } finally {
      if (currentRequestId == _monthRequestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchCalendarDay({required String date}) async {
    final currentRequestId = ++_dayRequestId;
    _activeSelectedDate = date;
    _isScheduleLoading = true;
    _scheduleErrorMessage = null;
    notifyListeners();

    try {
      final schedule = await getCalendarDayUseCase(date: date);
      // Ignore stale response if a newer day request was triggered or date changed
      if (currentRequestId != _dayRequestId || _activeSelectedDate != date) {
        return;
      }

      _selectedDaySchedule = schedule;
    } catch (e) {
      if (currentRequestId != _dayRequestId || _activeSelectedDate != date) {
        return;
      }
      _scheduleErrorMessage = e.toString();
      _selectedDaySchedule = null;
    } finally {
      if (currentRequestId == _dayRequestId && _activeSelectedDate == date) {
        _isScheduleLoading = false;
        notifyListeners();
      }
    }
  }

  void _processEventDots(CalendarMonthDataModel data) {
    final Map<int, List<Color>> dotsMap = {};
    for (final dayModel in data.days) {
      final List<Color> colors = [];
      if (dayModel.types.isNotEmpty) {
        for (final type in dayModel.types) {
          final typeLower = type.toLowerCase();
          if (typeLower.contains('leave') || typeLower.contains('timeoff')) {
            colors.add(const Color(0xFF076330));
          } else {
            colors.add(const Color(0xFFFF5722));
          }
        }
        if (dayModel.itemCount > colors.length) {
          final remaining = dayModel.itemCount - colors.length;
          for (int i = 0; i < remaining; i++) {
            colors.add(const Color(0xFFFF5722));
          }
        }
      } else if (dayModel.itemCount > 0) {
        for (int i = 0; i < dayModel.itemCount; i++) {
          colors.add(const Color(0xFFFF5722));
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

  // --- Log Notes State & Methods ---
  final Map<int, List<LogNoteModel>> _calendarLogs = {};
  final Map<int, String?> _calendarLogErrors = {};

  bool _isLoadingLogs = false;
  bool get isLoadingLogs => _isLoadingLogs;

  bool _isAddingLogNote = false;
  bool get isAddingLogNote => _isAddingLogNote;

  String? getLogErrorForCalendarItem(int calendarItemId) =>
      _calendarLogErrors[calendarItemId];

  Future<void> fetchCalendarLogs(int calendarItemId) async {
    _isLoadingLogs = true;
    _calendarLogErrors[calendarItemId] = null;
    _scheduleErrorMessage = null;
    notifyListeners();

    try {
      final response = await getLogNotesUseCase('calendar', calendarItemId);
      _calendarLogs[calendarItemId] = response.messages;
      _calendarLogErrors[calendarItemId] = null;
    } catch (e) {
      String message = e.toString();
      if (message.startsWith('Exception: ')) {
        message = message.substring(11);
      }
      _calendarLogErrors[calendarItemId] = message;
      _scheduleErrorMessage = message;
    } finally {
      _isLoadingLogs = false;
      notifyListeners();
    }
  }

  Future<bool> createEvent({
    required String title,
    required bool allDay,
    required String startDate,
    required String endDate,
    String? startTime,
    String? endTime,
    String? notes,
  }) async {
    _isCreatingEvent = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await createCalendarEventUseCase(
        title: title,
        allDay: allDay,
        startDate: startDate,
        endDate: endDate,
        startTime: startTime,
        endTime: endTime,
        notes: notes,
      );

      if (success) {
        // Give the backend a moment to commit the transaction before refreshing
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (_activeSelectedDate.isNotEmpty) {
            final refreshFutures = <Future<void>>[
              fetchCalendarDay(date: _activeSelectedDate),
            ];
            final parts = _activeSelectedDate.split('-');
            if (parts.length >= 2) {
              final year = int.tryParse(parts[0]);
              final month = int.tryParse(parts[1]);
              if (year != null && month != null) {
                refreshFutures.add(
                  fetchCalendarMonth(year: year, month: month),
                );
              }
            }
            Future.wait(refreshFutures).catchError((refreshErr) {
              debugPrint(
                '[CalendarProvider] Background refresh failed: $refreshErr',
              );
              return <void>[];
            });
          }
        });
      }
      return success;
    } on SubmissionOutcomeUnknownException catch (e) {
      // The connection dropped after the request went out: the event may or
      // may not exist. Do not resubmit -- check, tell the user, refresh.
      _errorMessage = e.message;
      _checkLostEventSubmission(title.trim(), startDate);
      return false;
    } on AppException catch (e) {
      _errorMessage = e.message ?? e.toString();
      return false;
    } catch (e) {
      final handled = ApiErrorHandler.handle(e);
      _errorMessage = handled.message ?? handled.toString();
      return false;
    } finally {
      _isCreatingEvent = false;
      notifyListeners();
    }
  }

  /// After a lost reply: does the start day list a meeting with this title?
  void _checkLostEventSubmission(String title, String startDate) {
    Future<void> refresh() async {
      final date = _activeSelectedDate.isNotEmpty
          ? _activeSelectedDate
          : startDate;
      final futures = <Future<void>>[fetchCalendarDay(date: date)];
      final parts = date.split('-');
      final year = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
      final month = parts.length > 1 ? int.tryParse(parts[1]) : null;
      if (year != null && month != null) {
        futures.add(fetchCalendarMonth(year: year, month: month));
      }
      await Future.wait(futures);
    }

    LostSubmissionChecker.start(
      label: (l10n) => l10n?.lostSubmissionEvent ?? 'event',
      refresh: refresh,
      isSaved: () async {
        final schedule = await getCalendarDayUseCase(date: startDate);
        return schedule.items.any(
          (item) =>
              item.sourceModel == 'calendar.event' &&
              item.title.trim() == title,
        );
      },
    );
  }

  Future<bool> deleteEvent(int id) async {
    _isCreatingEvent = true; // reusing loading state for UI block
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await deleteCalendarEventUseCase(id: id);
      if (success) {}
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isCreatingEvent = false;
      notifyListeners();
    }
  }

  Future<bool> updateEvent({
    required int id,
    required String title,
    required bool allDay,
    required String startDate,
    required String endDate,
    String? startTime,
    String? endTime,
    String? notes,
  }) async {
    _isCreatingEvent = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await updateCalendarEventUseCase(
        id: id,
        title: title,
        allDay: allDay,
        startDate: startDate,
        endDate: endDate,
        startTime: startTime,
        endTime: endTime,
        notes: notes,
      );

      if (success) {
        if (_activeSelectedDate.isNotEmpty) {
          fetchCalendarDay(date: _activeSelectedDate);
          final parts = _activeSelectedDate.split('-');
          if (parts.length >= 2) {
            final year = int.tryParse(parts[0]);
            final month = int.tryParse(parts[1]);
            if (year != null && month != null) {
              fetchCalendarMonth(year: year, month: month);
            }
          }
        }
      }
      return success;
    } on AppException catch (e) {
      _errorMessage = e.message ?? e.toString();
      return false;
    } catch (e) {
      final handled = ApiErrorHandler.handle(e);
      _errorMessage = handled.message ?? handled.toString();
      return false;
    } finally {
      _isCreatingEvent = false;
      notifyListeners();
    }
  }

  bool _isSubmittingLogNote = false;
  bool get isSubmittingLogNote => _isSubmittingLogNote;

  List<LogNoteModel> getLogsForCalendarItem(int calendarItemId) {
    if (!_calendarLogs.containsKey(calendarItemId)) {
      return [];
    }
    return List.unmodifiable(_calendarLogs[calendarItemId]!);
  }

  Future<bool> addLogNote(
    int calendarItemId,
    String message, {
    List<XFile> files = const [],
    List<String> mentionNames = const [],
    String? bodyPartsJson,
  }) async {
    if (message.trim().isEmpty && files.isEmpty) return false;
    _isAddingLogNote = true;
    _scheduleErrorMessage = null;
    notifyListeners();

    try {
      final createdLog = await createLogNoteUseCase(
        source: 'calendar',
        id: calendarItemId,
        text: message,
        files: files,
        mentionNames: mentionNames,
        bodyPartsJson: bodyPartsJson,
      );
      if (!_calendarLogs.containsKey(calendarItemId)) {
        _calendarLogs[calendarItemId] = [];
      }
      _calendarLogs[calendarItemId]!.insert(0, createdLog);
      await fetchCalendarLogs(calendarItemId);
      return true;
    } on SubmissionOutcomeUnknownException catch (e) {
      _scheduleErrorMessage = e.message;
      LostSubmissionChecker.startLogNote(
        before: List.of(_calendarLogs[calendarItemId] ?? const []),
        text: message,
        fetch: () async =>
            (await getLogNotesUseCase('calendar', calendarItemId)).messages,
        refresh: () => fetchCalendarLogs(calendarItemId),
      );
      return false;
    } catch (e) {
      _scheduleErrorMessage = e.toString();
      return false;
    } finally {
      _isAddingLogNote = false;
      notifyListeners();
    }
  }

  Future<bool> editLogNote(
    int messageId,
    String text,
    int calendarItemId, {
    List<XFile> files = const [],
    List<int> existingAttachments = const [],
    List<String> mentionNames = const [],
    String? bodyPartsJson,
  }) async {
    _isSubmittingLogNote = true;
    _scheduleErrorMessage = null;
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

      final currentLogs = _calendarLogs[calendarItemId] ?? [];
      final index = currentLogs.indexWhere(
        (log) => log.id == messageId.toString(),
      );
      if (index != -1) {
        currentLogs[index] = updatedLog;
        _calendarLogs[calendarItemId] = List.from(currentLogs);
      }
      return true;
    } catch (e) {
      _scheduleErrorMessage = e.toString();
      return false;
    } finally {
      _isSubmittingLogNote = false;
      notifyListeners();
    }
  }

  Future<bool> deleteLogNote(int calendarItemId, int messageId) async {
    final logs = _calendarLogs[calendarItemId];
    if (logs != null) {
      final index = logs.indexWhere((l) => l.id == messageId.toString());
      if (index != -1) {
        try {
          await deleteLogNoteUseCase(messageId);
          logs.removeAt(index);
          notifyListeners();
          return true;
        } catch (e) {
          _scheduleErrorMessage = e.toString();
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
