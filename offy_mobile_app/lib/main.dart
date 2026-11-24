import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:office_app/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/navigation/app_router.dart';
import 'core/network/network_aware_wrapper.dart';
import 'core/network/offline_back_handler.dart';
import 'core/services/app_update_service.dart';
import 'presentation/viewmodels/theme/theme_provider.dart';
import 'presentation/widgets/app_update/force_update_screen.dart';
import 'presentation/viewmodels/language/language_provider.dart';
import 'presentation/viewmodels/expenses/expenses_provider.dart';
import 'l10n/app_localizations.dart';
import 'presentation/viewmodels/user/access_provider.dart';
import 'injection_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await di.init();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Pass all uncaught errors from the framework to Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    final errorStr = error.toString().toLowerCase();
    final isMediaHttpError = error is HttpException ||
        errorStr.contains('httpexception') ||
        errorStr.contains('invalid statuscode');

    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      fatal: !isMediaHttpError,
    );
    return true;
  };

  // Before runApp: Android back must reach the offline screen first.
  OfflineBackHandler.instance.install();
  runApp(const MyApp());
  unawaited(AppUpdateService.instance.start());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => di.sl<ThemeProvider>()..loadTheme(),
        ),
        ChangeNotifierProvider(create: (context) => di.sl<LanguageProvider>()),
        ChangeNotifierProvider(create: (context) => di.sl<ExpensesProvider>()),
        ChangeNotifierProvider(create: (context) => di.sl<AccessProvider>()),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, languageProvider, _) {
          return ScreenUtilInit(
            designSize: const Size(375, 812),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, child) {
              final isDark = themeProvider.isDarkMode;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                  statusBarBrightness: isDark
                      ? Brightness.dark
                      : Brightness.light,
                  systemNavigationBarColor: Colors.transparent,
                  systemNavigationBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                  systemNavigationBarContrastEnforced: false,
                ),
                child: MaterialApp(
                  title: 'OFFY',
                  debugShowCheckedModeBanner: false,
                  theme: themeProvider.themeData,
                  locale: languageProvider.currentLocale,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  localeResolutionCallback: (locale, supportedLocales) {
                    if (locale != null) {
                      for (var supportedLocale in supportedLocales) {
                        if (supportedLocale.languageCode ==
                            locale.languageCode) {
                          return supportedLocale;
                        }
                      }
                    }
                    // Fallback always to English
                    return const Locale('en', 'US');
                  },
                  navigatorKey: AppRouter.navigatorKey,
                  navigatorObservers: [AppRouter.navigationObserver],
                  initialRoute: AppRouter.splash,
                  onGenerateRoute: AppRouter.onGenerateRoute,
                  builder: (context, child) {
                    // Force update sits above everything, offline screen included.
                    return Stack(
                      textDirection: TextDirection.ltr,
                      children: [
                        NetworkAwareWrapper(child: child!),
                        ValueListenableBuilder<AppUpdateInfo?>(
                          valueListenable:
                              AppUpdateService.instance.forceUpdate,
                          builder: (context, info, _) => info == null
                              ? const SizedBox.shrink()
                              : Positioned.fill(
                                  child: ForceUpdateScreen(info: info),
                                ),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
