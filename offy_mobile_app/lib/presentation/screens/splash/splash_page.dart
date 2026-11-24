import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../viewmodels/splash/splash_provider.dart';
import '../../widgets/common/frame_metrics.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SplashProvider>().startSplash();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SplashProvider>(
      builder: (context, provider, child) {
        if (provider.isFinished) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              final String nextRoute;
              if (provider.isAuthenticated) {
                nextRoute = AppRouter.home;
              } else if (provider.shouldShowOnboarding) {
                nextRoute = AppRouter.onboarding;
              } else {
                nextRoute = AppRouter.login;
              }
              Navigator.pushNamedAndRemoveUntil(
                context,
                nextRoute,
                (_) => false,
              );
            }
          });
        }
        // Figma `2840:6140`: the OFFY wordmark centred on white, matching the
        // native launch screens. Always light, like the rest of the flow.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: AppColors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: AppColors.white,
            body: Center(
              child: SvgPicture.asset(
                AppAssets.offyLogo,
                width: FrameMetrics.of(context)(195),
                semanticsLabel: 'OFFY',
              ),
            ),
          ),
        );
      },
    );
  }
}
