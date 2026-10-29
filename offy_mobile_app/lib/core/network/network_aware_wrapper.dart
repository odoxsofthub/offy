import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../presentation/screens/network/no_network_screen.dart';
import '../navigation/app_router.dart';
import '../services/session_manager.dart';
import '../../injection_container.dart' as di;
import 'network_interceptor.dart';

class NetworkAwareWrapper extends StatefulWidget {
  const NetworkAwareWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<NetworkAwareWrapper> createState() => _NetworkAwareWrapperState();
}

class _NetworkAwareWrapperState extends State<NetworkAwareWrapper> {
  @override
  void initState() {
    super.initState();
    NetworkInterceptor.instance.addListener(_onNetworkStateChange);
  }

  void _onNetworkStateChange() {
    if (!mounted) return;
    if (NetworkInterceptor.instance.isOfflineBlocking) {
      FocusManager.instance.primaryFocus?.unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    }
    setState(() {}); // Trigger rebuild to show/hide overlay
  }

  @override
  void dispose() {
    NetworkInterceptor.instance.removeListener(_onNetworkStateChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = NetworkInterceptor.instance.isOfflineBlocking;

    final currentRouteName = AppNavigationObserver.lastPushedRoute?.settings.name;
    final isHome = currentRouteName == AppRouter.home;
    final isLogin = currentRouteName == AppRouter.login;
    final isSplashOrLogin = currentRouteName == AppRouter.splash || isLogin;

    final bool showBackButton;
    if (isSplashOrLogin) {
      showBackButton = false;
    } else if (isHome) {
      // Show back button only if home data was successfully fetched before (shouldPopOnCancel is false)
      showBackButton = !NetworkInterceptor.instance.shouldPopOnCancel;
    } else {
      showBackButton = true;
    }

    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (isOffline && !isLogin)
          Positioned.fill(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: NoNetworkScreen(
                isServerUnreachable: NetworkInterceptor.instance.isServerUnreachable,
                showBackButton: showBackButton,
                onRetry: () =>
                    NetworkInterceptor.instance.checkConnectionManually(),
                onCancel: () {
                  NetworkInterceptor.instance.cancelManually();
                },
                isChecking: NetworkInterceptor.instance.isChecking,
                onLogout: () {
                  NetworkInterceptor.instance.resetOfflineState();
                  unawaited(di.sl<SessionManager>().logout());
                },
              ),
            ),
          ),
      ],
    );
  }
}
