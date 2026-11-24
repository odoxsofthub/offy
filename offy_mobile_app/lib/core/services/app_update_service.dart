import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart' as semver;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrader/upgrader.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart' as os_version;

import '../../presentation/widgets/app_update/update_available_sheet.dart';
import '../constants/app_links.dart';
import '../navigation/app_router.dart';

/// A newer release found in the appcast ([AppLinks.appcast]).
@immutable
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersion,
    required this.installedVersion,
    required this.storeUrl,
    required this.releaseNotes,
  });

  /// "1.0.2 (7)" style, from the appcast's `1.0.2+7`.
  final String latestVersion;
  final String installedVersion;
  final String? storeUrl;
  final List<String> releaseNotes;
}

/// What the appcast means for the installed build.
@immutable
class AppUpdateDecision {
  const AppUpdateDecision({this.info, this.force = false});

  /// Newest release when it is newer than the installed build, else null.
  final AppUpdateInfo? info;

  /// True when the installed build is below the highest criticalUpdate item.
  final bool force;
}

/// Reads the Sparkle appcast via `upgrader` at launch and on every resume.
/// Versions compare WITH the build number (pub_semver); upgrader's own check ignores it.
class AppUpdateService with WidgetsBindingObserver {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  /// A shown normal update (dismissed with "Later") comes back after this long.
  static const Duration remindAfter = Duration(days: 1);
  static const String _cacheKey = 'app_update_appcast_xml';
  static const String _promptedKey = 'app_update_last_prompt';

  /// Non-null while a force update blocks the app.
  final ValueNotifier<AppUpdateInfo?> forceUpdate = ValueNotifier(null);

  AppUpdateInfo? _optionalUpdate;
  bool _started = false;
  bool _checking = false;
  bool _sheetOpen = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    final prefs = await SharedPreferences.getInstance();
    if (AppLinks.appcast == null) {
      // No APPCAST_URL in this build: drop any cached feed so it cannot force an update.
      await prefs.remove(_cacheKey);
      debugPrint(
        '[AppUpdateService] APPCAST_URL not set; update check disabled.',
      );
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    // Cached feed first, so a force update still blocks when the app opens offline.
    final cached = prefs.getString(_cacheKey);
    if (cached != null) await _decideFrom(cached);
    await check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(check());
  }

  /// Downloads the appcast; keeps the current state when it cannot be reached.
  Future<void> check() async {
    final feed = AppLinks.appcast;
    if (feed == null || _checking) return;
    _checking = true;
    try {
      final response = await http
          .get(feed)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, response.body);
      await _decideFrom(response.body);
    } catch (e) {
      debugPrint('[AppUpdateService] appcast not reachable: $e');
    } finally {
      _checking = false;
    }
  }

  Future<void> _decideFrom(String xml) async {
    final package = await PackageInfo.fromPlatform();
    final installed = semver.Version.parse(
      '${package.version}+${package.buildNumber}',
    );
    final decision = decide(
      installed: installed,
      items: itemsFor(xml, UpgraderOS()),
    );
    forceUpdate.value = decision.force ? decision.info : null;
    _optionalUpdate = decision.force ? null : decision.info;
    await showOptionalIfDue();
  }

  /// Shows the normal-update sheet on Home, at most once per [remindAfter] per version.
  Future<void> showOptionalIfDue() async {
    final info = _optionalUpdate;
    final onHome =
        AppNavigationObserver.currentRoute?.settings.name == AppRouter.home;
    if (info == null || _sheetOpen || !onHome) return;
    final prefs = await SharedPreferences.getInstance();
    final last = (prefs.getString(_promptedKey) ?? '').split('|');
    final lastAt = DateTime.fromMillisecondsSinceEpoch(
      last.length == 2 ? int.tryParse(last[1]) ?? 0 : 0,
    );
    final remindedRecently =
        last.first == info.latestVersion &&
        DateTime.now().difference(lastAt) < remindAfter;
    final context = AppRouter.navigatorKey.currentContext;
    if (remindedRecently || _sheetOpen || context == null || !context.mounted) {
      return;
    }
    _sheetOpen = true;
    await prefs.setString(
      _promptedKey,
      '${info.latestVersion}|${DateTime.now().millisecondsSinceEpoch}',
    );
    if (!context.mounted) {
      _sheetOpen = false;
      return;
    }
    await UpdateAvailableSheet.show(
      context,
      info: info,
      onUpdate: () => openStore(info.storeUrl),
    );
    _sheetOpen = false;
  }

  /// Opens the store (or TestFlight) link from the appcast item.
  Future<bool> openStore(String? url) async {
    final uri = Uri.tryParse(url ?? '');
    if (uri == null || !uri.hasScheme) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[AppUpdateService] could not open store: $e');
      return false;
    }
  }

  /// Appcast items for this platform and OS version, parsed by upgrader.
  @visibleForTesting
  static List<AppcastItem> itemsFor(String xml, UpgraderOS os) {
    final osVersion = _osVersion(os.operatingSystemVersion);
    final appcast = Appcast(upgraderOS: os, osVersion: osVersion);
    return (appcast.parseItemsFromXMLString(xml) ?? [])
        .where(
          (item) => item.hostSupportsItem(
            osVersion: osVersion,
            currentPlatform: os.current,
          ),
        )
        .toList();
  }

  /// Newest item vs [installed]; force when below the highest criticalUpdate item.
  @visibleForTesting
  static AppUpdateDecision decide({
    required semver.Version installed,
    required List<AppcastItem> items,
  }) {
    AppcastItem? latest;
    semver.Version? latestVersion;
    semver.Version? minimum;
    for (final item in items) {
      final semver.Version version;
      try {
        version = semver.Version.parse(item.versionString ?? '');
      } on FormatException {
        continue;
      }
      if (latestVersion == null || version > latestVersion) {
        latest = item;
        latestVersion = version;
      }
      if (item.isCriticalUpdate && (minimum == null || version > minimum)) {
        minimum = version;
      }
    }
    if (latest == null || latestVersion == null || installed >= latestVersion) {
      return const AppUpdateDecision();
    }
    return AppUpdateDecision(
      force: minimum != null && installed < minimum,
      info: AppUpdateInfo(
        latestVersion: displayVersion(latestVersion.toString()),
        installedVersion: displayVersion(installed.toString()),
        storeUrl: latest.fileURL,
        releaseNotes: parseReleaseNotes(latest.itemDescription),
      ),
    );
  }

  /// "18.6.1", "Version 18.6 (Build 22G86)" -> 18.6.x; unknown -> 0.0.0.
  static os_version.Version _osVersion(String raw) {
    final match = RegExp(r'(\d+)(?:\.(\d+))?(?:\.(\d+))?').firstMatch(raw);
    int part(int i) => int.tryParse(match?.group(i) ?? '') ?? 0;
    return os_version.Version(part(1), part(2), part(3));
  }

  /// "1.0.2+7" -> "1.0.2 (7)".
  @visibleForTesting
  static String displayVersion(String version) {
    final parts = version.split('+');
    return parts.length == 2 && parts[1].isNotEmpty
        ? '${parts[0]} (${parts[1]})'
        : version;
  }

  /// The appcast `<description>`, one note per line, list markers removed.
  @visibleForTesting
  static List<String> parseReleaseNotes(String? text) => (text ?? '')
      .split('\n')
      .map((line) => line.trim().replaceFirst(RegExp(r'^[-•*]\s*'), ''))
      .where((line) => line.isNotEmpty)
      .toList();
}
