import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConstants {
  const ApiConstants._();

  static String get baseUrl {
    if (GetIt.instance.isRegistered<SharedPreferences>()) {
      final prefs = GetIt.instance<SharedPreferences>();
      final url = prefs.getString('saved_login_url');
      if (url != null && url.isNotEmpty) {
        return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      }
    }
    return const String.fromEnvironment('API_BASE_URL', defaultValue: '');
  }

  /// True when [url] is a relative path or has the same scheme, host and port as
  /// [baseUrl]; only such URLs may carry the bearer token.
  static bool isServerUrl(String url, {String? base}) {
    final trimmed = url.trim();
    if (trimmed.startsWith('/')) return !trimmed.startsWith('//');
    final target = Uri.tryParse(trimmed);
    final server = Uri.tryParse(base ?? baseUrl);
    if (target == null || server == null) return false;
    if (!target.hasAuthority || !server.hasAuthority) return false;
    return target.scheme.toLowerCase() == server.scheme.toLowerCase() &&
        target.host.toLowerCase() == server.host.toLowerCase() &&
        target.port == server.port;
  }

  static String get wsUrl => '${baseUrl.replaceFirst('http', 'ws')}/websocket';

  static String get wsOrigin => baseUrl;

  static const String defaultBearerToken = String.fromEnvironment(
    'API_BEARER_TOKEN',
    defaultValue: '',
  );

  static const String login = '/api/mobile/v1/auth/login';
  static const String logout = '/api/mobile/v1/auth/logout';
  static const String refresh = '/api/mobile/v1/auth/refresh';
  static const String switchCompany = '/api/mobile/v1/auth/company';
  static const String deviceToken = '/api/mobile/v1/device-token';
  static const String home = '/api/mobile/v1/home';
  static const String attendanceAction = '/api/mobile/v1/attendance/action';
  static const String attendanceLogs = '/api/mobile/v1/attendance/logs';
  static const String accessDetails = '/api/mobile/v1/user/access-details';
  static const String realtimeTicket = '/api/mobile/v1/realtime/ticket';
  static const String logNoteMessages = '/api/mobile/v1/log-note/messages';
  static const String payslip = '/api/mobile/v1/payslip';
  static const String payslipList = '/api/mobile/v1/payslip/list';
  static const String timeOff = '/api/mobile/v1/timeoff';
  static const String timeOffHistory = '/api/mobile/v1/timeoff/history';
  static const String timeOffUpcoming = '/api/mobile/v1/timeoff/upcoming';
  static const String timeOffTypes = '/api/mobile/v1/timeoff/types';
  static const String timeOffDuration = '/api/mobile/v1/timeoff/duration';
  static const String timeOffRequest = '/api/mobile/v1/timeoff/request';
  static const String timeOffCalendarMonth =
      '/api/mobile/v1/timeoff/calendar/month';
  static const String timeOffCalendarDay =
      '/api/mobile/v1/timeoff/calendar/day';
  static const String profile = '/api/mobile/v1/profile';
  static const String expenseSummary = '/api/mobile/v1/expense/summary';
  static const String expensesList = '/api/mobile/v1/expense';
  static const String expenseCategories = '/api/mobile/v1/expense/categories';
  static const String submitExpense = '/api/mobile/v1/expense';
  static const String filterOptions = '/api/mobile/v1/filters/options';
  static const String filters = '/api/mobile/v1/filters';
  static const String applyFilters = '/api/mobile/v1/filters/apply';
  static const String calendarMonth = '/api/mobile/v1/calendar/month';
  static const String calendarDay = '/api/mobile/v1/calendar/day';
  static const String calendarEvents = '/api/mobile/v1/calendar/events';
  static const String notifications = '/api/mobile/v1/notifications';
  static const String privacyPolicy = '/api/mobile/v1/privacy-policy';
  static const String termsConditions = '/api/mobile/v1/terms-conditions';
  static const String faqs = '/api/mobile/v1/faqs';
  static const String mentionSuggestions =
      '/api/mobile/v1/log-note/mention-suggestions';
  static const String createLogNoteMessage = '/api/mobile/v1/log-note/messages';
  static const String updateLogNoteMessage = '/api/mobile/v1/log-note/messages';
  static const String deleteLogNoteMessage = '/api/mobile/v1/log-note/messages';

  static String payslipDownload(int id) =>
      '/api/mobile/v1/payslip/$id/download';

  static String expenseLogs(int id) => '/api/mobile/v1/expense/$id/logs';

  static String deleteCalendarEvent(int id) =>
      '/api/mobile/v1/calendar/events/$id';
  static String updateCalendarEvent(int id) =>
      '/api/mobile/v1/calendar/events/$id';
}
