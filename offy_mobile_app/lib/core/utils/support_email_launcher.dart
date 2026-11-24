import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/profile_response_model.dart';
import '../../injection_container.dart' as di;
import '../../presentation/viewmodels/profile/profile_provider.dart';
import '../../presentation/widgets/common/custom_snackbar.dart';

abstract class SupportEmailLauncher {
  static bool _isLaunching = false;

  /// Utility method to construct and open a pre-filled support email intent.
  /// Collects app name, app version, OS platform, and user contact details dynamically.
  static Future<void> openSupportEmail(BuildContext context) async {
    if (_isLaunching) return;
    _isLaunching = true;

    try {
      ProfileModel? profile;
      try {
        profile = context.read<ProfileProvider>().profileData;
      } catch (_) {
        if (di.sl.isRegistered<ProfileProvider>()) {
          profile = di.sl<ProfileProvider>().profileData;
        }
      }

      final userEmail = profile?.email ?? '';
      final userPhone = profile?.phone ?? profile?.mobile ?? '';

      final packageInfo = await PackageInfo.fromPlatform();
      final appName = packageInfo.appName.isNotEmpty
          ? packageInfo.appName
          : 'OFFY';
      final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      final platform = kIsWeb ? 'Web' : Platform.operatingSystem;

      final subject = 'Support Request - $appName';
      final body =
          '''
Hi,

I'd like to contact support regarding:




My Contact Details
------------------
Email: $userEmail
Phone: $userPhone

App Version: $appVersion
Platform: $platform

Thanks.
''';

      final String urlString =
          'mailto:sales@odoxsofthub.com?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
      final Uri emailLaunchUri = Uri.parse(urlString);

      try {
        final bool canLaunch = await canLaunchUrl(emailLaunchUri);
        if (canLaunch) {
          await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
        } else {
          // Attempt direct launch as fallback
          final bool launched = await launchUrl(
            emailLaunchUri,
            mode: LaunchMode.externalApplication,
          );
          if (!launched && context.mounted) {
            CustomSnackbar.show(
              context,
              message: 'Could not find an email application on device.',
              isError: true,
            );
          }
        }
      } catch (_) {
        try {
          await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
        } catch (_) {
          if (context.mounted) {
            CustomSnackbar.show(
              context,
              message: 'Failed to launch email client.',
              isError: true,
            );
          }
        }
      }
    } finally {
      _isLaunching = false;
    }
  }
}
