import 'package:flutter/material.dart';
import '../../data/models/timeoff_response_model.dart';
import '../../data/models/calendar_day_schedule_model.dart';
import '../../data/models/attendance_log_response_model.dart';

import '../../presentation/screens/auth/login_page.dart';
import '../../presentation/screens/home/home_page.dart';
import '../../presentation/screens/splash/splash_page.dart';
import '../../presentation/screens/onboarding/onboarding_connect_page.dart';
import '../../presentation/screens/onboarding/onboarding_page.dart';
import '../../presentation/screens/expenses/submit_expense_page.dart';
import '../../presentation/screens/expenses/custom_date_range_screen.dart';
import '../../presentation/screens/attendance/attendance_day_detail_screen.dart';
import '../../presentation/screens/notification/notification_page.dart';
import '../../presentation/screens/calendar/calendar_page.dart';
import '../../presentation/screens/calendar/schedule_log_page.dart';
import '../../presentation/screens/time_off_log/time_off_log_page.dart';
import '../../presentation/screens/privacy_policy/privacy_policy_page.dart';
import '../../presentation/screens/terms_conditions/terms_conditions_page.dart';
import '../../presentation/screens/faq/faq_page.dart';
import '../../presentation/screens/language/language_page.dart';
import '../../presentation/viewmodels/notification/notification_provider.dart';
import '../../presentation/viewmodels/privacy_policy/privacy_policy_provider.dart';
import '../../presentation/viewmodels/terms_conditions/terms_conditions_provider.dart';
import '../../presentation/viewmodels/faq/faq_provider.dart';
import '../../presentation/widgets/common/custom_snackbar.dart';
import '../../presentation/widgets/realtime/realtime_sync_binder.dart';
import '../services/realtime_sync_service.dart';

import 'package:provider/provider.dart';
import '../../injection_container.dart' as di;
import '../../presentation/viewmodels/auth/login_provider.dart';
import '../../presentation/viewmodels/home/home_navigation_provider.dart';
import '../../presentation/viewmodels/home/home_provider.dart';
import '../../presentation/viewmodels/splash/splash_provider.dart';
import '../../presentation/viewmodels/onboarding/onboarding_provider.dart';
import '../../presentation/viewmodels/attendance/attendance_provider.dart';

import '../../presentation/viewmodels/pay_slip/payslip_provider.dart';
import '../../presentation/viewmodels/profile/profile_provider.dart';
import '../../presentation/viewmodels/calendar/calendar_provider.dart';
import '../../presentation/viewmodels/time_off/time_off_provider.dart';

class AppRouter {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String onboardingConnect = '/onboarding/connect';
  static const String login = '/login';
  static const String home = '/home';
  static const String submitExpense = '/submit-expense';
  static const String customDateRange = '/expense/custom-date-range';
  static const String myExpensesList = '/expense/list';
  static const String expenseLog = '/expense/log';
  static const String notification = '/notification';
  static const String calendar = '/calendar';
  static const String scheduleLog = '/schedule-log';
  static const String timeOff = '/time-off';
  static const String leaveHistory = '/time-off/history';
  static const String timeOffLog = '/time-off-log';
  static const String paySlip = '/payslip';
  static const String payslipHistory = '/payslip/history';
  static const String userPolicy = '/user-policy';
  static const String termsConditions = '/terms-conditions';
  static const String faq = '/faq';
  static const String language = '/language';
  static const String attendanceDayDetail = '/attendance/day-detail';

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final AppNavigationObserver navigationObserver =
      AppNavigationObserver();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ChangeNotifierProvider(
            create: (_) => di.sl<SplashProvider>()..startSplash(),
            child: const SplashPage(),
          ),
        );
      case onboarding:
        return _fadeRoute(
          ChangeNotifierProvider(
            create: (_) => di.sl<OnboardingProvider>(),
            child: const OnboardingPage(),
          ),
          settings,
        );
      case onboardingConnect:
        // Platform route so iOS back swipe returns to the last slide.
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ChangeNotifierProvider(
            create: (_) => di.sl<OnboardingProvider>(),
            child: const OnboardingConnectPage(),
          ),
        );
      case login:
        return _fadeRoute(
          ChangeNotifierProvider(
            create: (_) => di.sl<LoginProvider>(),
            child: const LoginPage(),
          ),
          settings,
        );
      case home:
        return _fadeRoute(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => di.sl<HomeNavigationProvider>(),
              ),
              ChangeNotifierProvider(
                create: (_) => di.sl<AttendanceProvider>(),
              ),
              ChangeNotifierProvider(create: (_) => di.sl<HomeProvider>()),
              ChangeNotifierProvider.value(value: di.sl<PayslipProvider>()),
              ChangeNotifierProvider.value(value: di.sl<ProfileProvider>()),
              ChangeNotifierProvider.value(
                value: di.sl<PrivacyPolicyProvider>(),
              ),
              ChangeNotifierProvider.value(
                value: di.sl<TermsConditionsProvider>(),
              ),
            ],
            child: RealtimeSyncBinder(
              service: di.sl<RealtimeSyncService>(),
              child: const HomePage(),
            ),
          ),
          settings,
        );
      case submitExpense:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const SubmitExpensePage(),
        );
      case customDateRange:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => CustomDateRangeScreen(
            initialStartDate: args?['startDate'] as DateTime?,
            initialEndDate: args?['endDate'] as DateTime?,
          ),
        );
      case notification:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ChangeNotifierProvider(
            create: (_) => di.sl<NotificationProvider>()..fetchNotifications(),
            child: const NotificationPage(),
          ),
        );
      case calendar:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ChangeNotifierProvider(
            create: (_) => di.sl<CalendarProvider>(),
            child: const CalendarPage(),
          ),
        );
      case timeOffLog:
        final leave = settings.arguments as TimeOffLeaveItemModel;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ChangeNotifierProvider.value(
            value: di.sl<TimeOffProvider>(),
            child: TimeOffLogPage(leave: leave),
          ),
        );
      case scheduleLog:
        final item = settings.arguments as CalendarScheduleItemModel;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ChangeNotifierProvider.value(
            value: di.sl<CalendarProvider>(),
            child: ScheduleLogPage(item: item),
          ),
        );
      case userPolicy:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ChangeNotifierProvider(
            create: (_) => di.sl<PrivacyPolicyProvider>(),
            child: const PrivacyPolicyPage(),
          ),
        );
      case termsConditions:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ChangeNotifierProvider(
            create: (_) => di.sl<TermsConditionsProvider>(),
            child: const TermsConditionsPage(),
          ),
        );
      case faq:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => di.sl<FaqProvider>()),
              ChangeNotifierProvider.value(value: di.sl<ProfileProvider>()),
            ],
            child: const FaqPage(),
          ),
        );
      case language:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const LanguagePage(),
        );
      case attendanceDayDetail:
        final log = settings.arguments as AttendanceLogEntryModel;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => AttendanceDayDetailScreen(log: log),
        );
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }

  static Route<dynamic> _fadeRoute(Widget child, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  static String? getFeatureForRouteName(String? name) {
    if (name == null) return null;
    if (name == timeOff ||
        name == leaveHistory ||
        name == timeOffLog ||
        name.startsWith('/time-off')) {
      return 'time_off';
    }
    if (name == submitExpense ||
        name == myExpensesList ||
        name == expenseLog ||
        name.startsWith('/expense')) {
      return 'expense';
    }
    if (name == paySlip ||
        name == payslipHistory ||
        name.startsWith('/payslip')) {
      return 'payslip';
    }
    if (name == calendar ||
        name == scheduleLog ||
        name.startsWith('/calendar')) {
      return 'calendar';
    }
    if (name == '/attendance') {
      return 'attendance';
    }
    return null;
  }

  static String getFeatureDisplayName(String feature) {
    switch (feature) {
      case 'time_off':
        return 'Time Off';
      case 'expense':
        return 'Expense';
      case 'payslip':
        return 'Payslip';
      case 'calendar':
        return 'Calendar';
      case 'attendance':
        return 'Attendance';
      default:
        return 'Feature';
    }
  }

  static void handleFeatureRevoked(String feature) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    bool didPopAny = false;
    while (AppNavigationObserver.currentRoute != null) {
      final route = AppNavigationObserver.currentRoute!;
      if (AppNavigationObserver.isRouteForFeature(route, feature)) {
        if (navigator.canPop()) {
          navigator.pop();
          didPopAny = true;
        } else {
          break;
        }
      } else {
        break;
      }
    }

    if (didPopAny) {
      final rootContext = navigatorKey.currentContext;
      if (rootContext != null && rootContext.mounted) {
        final displayName = getFeatureDisplayName(feature);
        CustomSnackbar.show(
          rootContext,
          message: '$displayName access has been revoked',
        );
      }
    }
  }
}

class AppNavigationObserver extends NavigatorObserver {
  static DateTime? lastPushTime;
  // Tracks push-only route transitions; NOT reset on didPop so that pop-reveal
  // scenarios don't incorrectly mark a resumed screen's API call as page-init.
  static DateTime? lastPushOnlyTime;
  static Route? lastPushedRoute;
  static final List<Route> _routeStack = [];
  static final Map<Route, String> _routeFeatures = {};

  static Route? get currentRoute =>
      _routeStack.isNotEmpty ? _routeStack.last : null;

  static bool isRouteForFeature(Route<dynamic> route, String feature) {
    final tracked = _routeFeatures[route];
    if (tracked != null) {
      return tracked == feature;
    }
    final nameFeature = AppRouter.getFeatureForRouteName(route.settings.name);
    return nameFeature == feature;
  }

  void _clearSnackbars() {
    final ctx = navigator?.context;
    if (ctx != null && ctx.mounted) {
      ScaffoldMessenger.of(ctx).clearSnackBars();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _clearSnackbars();
    lastPushTime = DateTime.now();
    lastPushOnlyTime = DateTime.now();
    lastPushedRoute = route;
    _routeStack.add(route);

    final feature = AppRouter.getFeatureForRouteName(route.settings.name);
    if (feature != null) {
      _routeFeatures[route] = feature;
    } else if (previousRoute != null &&
        _routeFeatures.containsKey(previousRoute)) {
      _routeFeatures[route] = _routeFeatures[previousRoute]!;
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _clearSnackbars();
    _routeStack.remove(route);
    _routeFeatures.remove(route);
    if (_routeStack.isNotEmpty) {
      lastPushedRoute = _routeStack.last;
      lastPushTime = DateTime.now();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _clearSnackbars();
    _routeStack.remove(route);
    _routeFeatures.remove(route);
    if (_routeStack.isNotEmpty) {
      lastPushedRoute = _routeStack.last;
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _clearSnackbars();
    if (oldRoute != null) {
      _routeStack.remove(oldRoute);
      _routeFeatures.remove(oldRoute);
    }
    if (newRoute != null) {
      _routeStack.add(newRoute);
      lastPushedRoute = newRoute;
      lastPushTime = DateTime.now();

      final feature = AppRouter.getFeatureForRouteName(newRoute.settings.name);
      if (feature != null) {
        _routeFeatures[newRoute] = feature;
      }
    }
  }
}
