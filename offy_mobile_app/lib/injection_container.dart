import 'package:get_it/get_it.dart';
import 'package:office_app/domain/usecases/update_log_note_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';


import 'presentation/viewmodels/auth/login_provider.dart';
import 'presentation/viewmodels/home/home_navigation_provider.dart';
import 'presentation/viewmodels/splash/splash_provider.dart';
import 'presentation/viewmodels/onboarding/onboarding_provider.dart';
import 'data/datasources/onboarding_local_data_source.dart';
import 'data/repositories/onboarding_repository_impl.dart';
import 'domain/repositories/onboarding_repository.dart';
import 'presentation/viewmodels/expenses/expenses_provider.dart';
import 'presentation/viewmodels/notification/notification_provider.dart';
import 'data/datasources/notification_remote_data_source.dart';
import 'data/repositories/notification_repository_impl.dart';
import 'domain/repositories/notification_repository.dart';
import 'domain/usecases/get_notifications_usecase.dart';
import 'domain/usecases/dismiss_notification_usecase.dart';
import 'data/datasources/theme_local_data_source.dart';
import 'data/repositories/theme_repository_impl.dart';
import 'domain/repositories/theme_repository.dart';
import 'domain/usecases/change_theme.dart';
import 'domain/usecases/get_saved_theme.dart';
import 'presentation/viewmodels/theme/theme_provider.dart';
import 'presentation/viewmodels/language/language_provider.dart';

import 'data/datasources/auth_remote_data_source.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/usecases/login_usecase.dart';
import 'domain/usecases/logout_usecase.dart';
import 'domain/usecases/register_device_token_usecase.dart';
import 'domain/usecases/switch_company_usecase.dart';

import 'data/datasources/attendance_remote_data_source.dart';
import 'data/repositories/attendance_repository_impl.dart';
import 'domain/repositories/attendance_repository.dart';
import 'domain/usecases/perform_attendance_action_usecase.dart';
import 'domain/usecases/get_attendance_logs_usecase.dart';
import 'presentation/viewmodels/attendance/attendance_provider.dart';
import 'presentation/viewmodels/attendance/attendance_log_provider.dart';

import 'data/datasources/home_remote_data_source.dart';
import 'data/repositories/home_repository_impl.dart';
import 'domain/repositories/home_repository.dart';
import 'domain/usecases/get_home_data_usecase.dart';
import 'presentation/viewmodels/home/home_provider.dart';

import 'data/datasources/user_local_data_source.dart';
import 'data/datasources/user_remote_data_source.dart';
import 'data/repositories/user_repository_impl.dart';
import 'domain/repositories/user_repository.dart';
import 'domain/usecases/get_access_details_usecase.dart';
import 'presentation/viewmodels/user/access_provider.dart';

import 'data/datasources/payslip_remote_data_source.dart';
import 'data/repositories/payslip_repository_impl.dart';
import 'domain/repositories/payslip_repository.dart';
import 'domain/repositories/timeoff_repository.dart';
import 'domain/repositories/profile_repository.dart';
import 'domain/usecases/get_payslip_usecase.dart';
import 'domain/usecases/download_payslip_usecase.dart';
import 'domain/usecases/get_payslip_history_usecase.dart';
import 'domain/usecases/get_timeoff_data_usecase.dart';
import 'domain/usecases/get_profile_usecase.dart';
import 'presentation/viewmodels/pay_slip/payslip_provider.dart';
import 'presentation/viewmodels/time_off/time_off_provider.dart';
import 'presentation/viewmodels/profile/profile_provider.dart';
import 'data/datasources/timeoff_remote_data_source.dart';
import 'data/datasources/profile_remote_data_source.dart';
import 'data/datasources/expense_remote_data_source.dart';
import 'data/repositories/timeoff_repository_impl.dart';
import 'data/repositories/profile_repository_impl.dart';
import 'data/repositories/expense_repository_impl.dart';
import 'domain/repositories/expense_repository.dart';
import 'domain/usecases/get_expense_summary_usecase.dart';
import 'domain/usecases/get_expenses_list_usecase.dart';
import 'domain/usecases/get_expense_categories_usecase.dart';
import 'domain/usecases/submit_expense_usecase.dart';
import 'domain/usecases/delete_expense_usecase.dart';
import 'domain/usecases/get_expense_filter_options_usecase.dart';
import 'domain/usecases/get_expense_filter_content_usecase.dart';
import 'domain/usecases/apply_expense_filter_usecase.dart';

import 'domain/usecases/get_log_notes_usecase.dart';
import 'domain/usecases/create_log_note_usecase.dart';
import 'domain/usecases/delete_log_note_usecase.dart';
import 'domain/repositories/log_note_repository.dart';
import 'data/repositories/log_note_repository_impl.dart';
import 'data/datasources/log_note_remote_data_source.dart';

import 'domain/usecases/get_timeoff_history_usecase.dart';
import 'domain/usecases/get_upcoming_leaves_usecase.dart';
import 'domain/usecases/get_timeoff_types_usecase.dart';
import 'domain/usecases/calculate_timeoff_duration_usecase.dart';
import 'domain/usecases/submit_timeoff_request_usecase.dart';
import 'domain/usecases/get_timeoff_calendar_month_usecase.dart';
import 'domain/usecases/get_timeoff_calendar_day_usecase.dart';

import 'data/datasources/calendar_remote_data_source.dart';
import 'data/repositories/calendar_repository_impl.dart';
import 'domain/repositories/calendar_repository.dart';
import 'domain/usecases/get_calendar_month_usecase.dart';
import 'domain/usecases/get_calendar_day_usecase.dart';
import 'domain/usecases/create_calendar_event_usecase.dart';
import 'domain/usecases/delete_calendar_event_usecase.dart';
import 'domain/usecases/update_calendar_event_usecase.dart';
import 'presentation/viewmodels/calendar/calendar_provider.dart';
import 'data/datasources/privacy_policy_remote_data_source.dart';
import 'presentation/viewmodels/privacy_policy/privacy_policy_provider.dart';
import 'data/datasources/terms_conditions_remote_data_source.dart';
import 'presentation/viewmodels/terms_conditions/terms_conditions_provider.dart';
import 'data/datasources/faq_remote_data_source.dart';
import 'presentation/viewmodels/faq/faq_provider.dart';

import 'core/network/api_client.dart';
import 'core/services/token_storage.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/realtime_sync_service.dart';
import 'data/datasources/realtime_remote_data_source.dart';

import 'core/services/session_reset_service.dart';
import 'core/services/session_manager.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Services
  sl.registerLazySingleton(() => SessionResetService());
  sl.registerLazySingleton(
    () => SessionManager(sessionResetService: sl(), tokenStorage: sl()),
  );
  sl.registerLazySingleton(
    () => PushNotificationService(tokenStorage: sl()),
  );
  sl.registerLazySingleton<RealtimeRemoteDataSource>(
    () => RealtimeRemoteDataSourceImpl(apiClient: sl()),
  );
  sl.registerLazySingleton(() => RealtimeSyncService(dataSource: sl()));

  // Cubits
  sl.registerFactory(
    () => ThemeProvider(changeTheme: sl(), getSavedTheme: sl()),
  );
  sl.registerFactory(() => LanguageProvider(sl()));
  sl.registerFactory(
    () => SplashProvider(authRepository: sl(), onboardingRepository: sl()),
  );
  sl.registerFactory(() => OnboardingProvider(onboardingRepository: sl()));
  sl.registerFactory(
    () => LoginProvider(loginUseCase: sl(), sharedPreferences: sl()),
  );
  sl.registerFactory(() => HomeNavigationProvider());
  sl.registerFactory(
    () => AttendanceProvider(performAttendanceActionUseCase: sl()),
  );
  sl.registerLazySingleton(
    () => AttendanceLogProvider(
      getAttendanceLogsUseCase: sl(),
      sessionResetService: sl(),
    ),
  );
  sl.registerFactory(
    () => HomeProvider(
      getHomeDataUseCase: sl(),
      sessionResetService: sl(),
    ),
  );
  sl.registerFactory(
    () => AccessProvider(
      getAccessDetailsUseCase: sl(),
      userRepository: sl(),
      sessionResetService: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => PayslipProvider(
      getPayslipUseCase: sl(),
      downloadPayslipUseCase: sl(),
      getPayslipHistoryUseCase: sl(),
      getLogNotesUseCase: sl(),
      createLogNoteUseCase: sl(),
      updateLogNoteUseCase: sl(),
      deleteLogNoteUseCase: sl(),
      getExpenseFilterOptionsUseCase: sl(),
      getExpenseFilterContentUseCase: sl(),
      applyExpenseFilterUseCase: sl(),
      sessionResetService: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => TimeOffProvider(
      getTimeOffDataUseCase: sl(),
      getTimeOffHistoryUseCase: sl(),
      getUpcomingLeavesUseCase: sl(),
      getTimeOffTypesUseCase: sl(),
      calculateTimeOffDurationUseCase: sl(),
      submitTimeOffRequestUseCase: sl(),
      getTimeOffCalendarMonthUseCase: sl(),
      getTimeOffCalendarDayUseCase: sl(),
      getLogNotesUseCase: sl(),
      createLogNoteUseCase: sl(),
      updateLogNoteUseCase: sl(),
      deleteLogNoteUseCase: sl(),
      getExpenseFilterOptionsUseCase: sl(),
      getExpenseFilterContentUseCase: sl(),
      applyExpenseFilterUseCase: sl(),
      sessionResetService: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => ProfileProvider(
      getProfileDataUseCase: sl(),
      sessionResetService: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => ExpensesProvider(
      getExpenseSummaryUseCase: sl(),
      getExpensesListUseCase: sl(),
      getExpenseCategoriesUseCase: sl(),
      submitExpenseUseCase: sl(),
      deleteExpenseUseCase: sl(),
      getLogNotesUseCase: sl(),
      createLogNoteUseCase: sl(),
      updateLogNoteUseCase: sl(),
      deleteLogNoteUseCase: sl(),
      getExpenseFilterOptionsUseCase: sl(),
      getExpenseFilterContentUseCase: sl(),
      applyExpenseFilterUseCase: sl(),
      sessionResetService: sl(),
    ),
  );

  sl.registerFactory(
    () => NotificationProvider(
      getNotificationsUseCase: sl(),
      dismissNotificationUseCase: sl(),
    ),
  );
  sl.registerFactory(
    () => CalendarProvider(
      getCalendarMonthUseCase: sl(),
      getCalendarDayUseCase: sl(),
      createCalendarEventUseCase: sl(),
      deleteCalendarEventUseCase: sl(),
      updateCalendarEventUseCase: sl(),
      getLogNotesUseCase: sl(),
      createLogNoteUseCase: sl(),
      updateLogNoteUseCase: sl(),
      deleteLogNoteUseCase: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => GetSavedTheme(sl()));
  sl.registerLazySingleton(() => ChangeTheme(sl()));
  sl.registerLazySingleton(() => LoginUseCase(repository: sl()));
  sl.registerLazySingleton(() => RegisterDeviceTokenUseCase(repository: sl()));
  sl.registerLazySingleton(() => LogoutUseCase(repository: sl()));
  sl.registerLazySingleton(
    () => SwitchCompanyUseCase(repository: sl(), tokenStorage: sl()),
  );

  sl.registerLazySingleton(
    () => PerformAttendanceActionUseCase(repository: sl()),
  );
  sl.registerLazySingleton(() => GetAttendanceLogsUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetHomeDataUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetAccessDetailsUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetPayslipUseCase(repository: sl()));
  sl.registerLazySingleton(() => DownloadPayslipUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetPayslipHistoryUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetTimeOffDataUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetTimeOffHistoryUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetUpcomingLeavesUseCase(sl()));
  sl.registerLazySingleton(() => GetTimeOffTypesUseCase(repository: sl()));
  sl.registerLazySingleton(() => CalculateTimeOffDurationUseCase(sl()));
  sl.registerLazySingleton(() => SubmitTimeOffRequestUseCase(sl()));
  sl.registerLazySingleton(() => GetTimeOffCalendarMonthUseCase(sl()));
  sl.registerLazySingleton(() => GetTimeOffCalendarDayUseCase(sl()));
  sl.registerLazySingleton(() => GetProfileDataUseCase(repository: sl()));

  // Expenses
  sl.registerLazySingleton(() => GetExpenseSummaryUseCase(sl()));
  sl.registerLazySingleton(() => GetExpensesListUseCase(sl()));
  sl.registerLazySingleton(() => GetExpenseCategoriesUseCase(sl()));
  sl.registerLazySingleton(() => SubmitExpenseUseCase(sl()));
  sl.registerLazySingleton(() => DeleteExpenseUseCase(sl()));
  sl.registerLazySingleton(() => GetExpenseFilterOptionsUseCase(sl()));
  sl.registerLazySingleton(() => GetExpenseFilterContentUseCase(sl()));
  sl.registerLazySingleton(() => ApplyExpenseFilterUseCase(sl()));

  sl.registerLazySingleton(() => GetLogNotesUseCase(repository: sl()));
  sl.registerLazySingleton(() => CreateLogNoteUseCase(repository: sl()));
  sl.registerLazySingleton(() => UpdateLogNoteUseCase(repository: sl()));
  sl.registerLazySingleton(() => DeleteLogNoteUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetCalendarMonthUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetCalendarDayUseCase(repository: sl()));
  sl.registerLazySingleton(() => CreateCalendarEventUseCase(repository: sl()));
  sl.registerLazySingleton(() => DeleteCalendarEventUseCase(repository: sl()));
  sl.registerLazySingleton(() => UpdateCalendarEventUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetNotificationsUseCase(sl()));
  sl.registerLazySingleton(() => DismissNotificationUseCase(sl()));

  // Repository
  sl.registerLazySingleton<ThemeRepository>(
    () => ThemeRepositoryImpl(localDataSource: sl()),
  );
  sl.registerLazySingleton<OnboardingRepository>(
    () => OnboardingRepositoryImpl(localDataSource: sl()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<AttendanceRepository>(
    () => AttendanceRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<HomeRepository>(
    () => HomeRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
    ),
  );
  sl.registerLazySingleton<PayslipRepository>(
    () => PayslipRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<TimeOffRepository>(
    () => TimeOffRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<ExpenseRepository>(
    () => ExpenseRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<CalendarRepository>(
    () => CalendarRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<LogNoteRepository>(
    () => LogNoteRepositoryImpl(remoteDataSource: sl()),
  );

  // Data sources
  sl.registerLazySingleton<ThemeLocalDataSource>(
    () => ThemeLocalDataSourceImpl(sharedPreferences: sl()),
  );
  sl.registerLazySingleton<OnboardingLocalDataSource>(
    () => OnboardingLocalDataSourceImpl(sharedPreferences: sl()),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(
      apiClient: sl(),
      pushNotificationService: sl(),
    ),
  );
  sl.registerLazySingleton<AttendanceRemoteDataSource>(
    () => AttendanceRemoteDataSourceImpl(apiClient: sl()),
  );
  sl.registerLazySingleton<HomeRemoteDataSource>(
    () => HomeRemoteDataSourceImpl(apiClient: sl()),
  );
  sl.registerLazySingleton<UserLocalDataSource>(
    () => UserLocalDataSourceImpl(sharedPreferences: sl()),
  );
  sl.registerLazySingleton<UserRemoteDataSource>(
    () => UserRemoteDataSourceImpl(apiClient: sl()),
  );
  sl.registerLazySingleton<PayslipRemoteDataSource>(
    () => PayslipRemoteDataSourceImpl(apiClient: sl()),
  );
  sl.registerLazySingleton<TimeOffRemoteDataSource>(
    () => TimeOffRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<ExpenseRemoteDataSource>(
    () => ExpenseRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<CalendarRemoteDataSource>(
    () => CalendarRemoteDataSourceImpl(apiClient: sl()),
  );
  sl.registerLazySingleton<NotificationRemoteDataSource>(
    () => NotificationRemoteDataSourceImpl(apiClient: sl()),
  );
  sl.registerLazySingleton<LogNoteRemoteDataSource>(
    () => LogNoteRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<PrivacyPolicyRemoteDataSource>(
    () => PrivacyPolicyRemoteDataSourceImpl(client: sl()),
  );
  sl.registerFactory(() => PrivacyPolicyProvider(dataSource: sl()));
  sl.registerLazySingleton<TermsConditionsRemoteDataSource>(
    () => TermsConditionsRemoteDataSourceImpl(client: sl()),
  );
  sl.registerFactory(() => TermsConditionsProvider(dataSource: sl()));
  sl.registerLazySingleton<FaqRemoteDataSource>(
    () => FaqRemoteDataSourceImpl(client: sl()),
  );
  sl.registerFactory(() => FaqProvider(dataSource: sl()));

  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  // Core Services & Network
  sl.registerLazySingleton(() => TokenStorage());
  sl.registerLazySingleton(
    () => ApiClient(
      tokenStorage: sl(),
      onRefreshToken: () async {
        return await sl<AuthRepository>().refreshToken();
      },
      onUnauthenticated: () async {
        await sl<SessionManager>().terminateSession(isExpired: true);
      },
    ),
  );
}
