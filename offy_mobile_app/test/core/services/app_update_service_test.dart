import 'package:flutter_test/flutter_test.dart';
import 'package:office_app/core/services/app_update_service.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:upgrader/upgrader.dart';

/// The rules documented in the GitHub appcast.xml: parsed by upgrader, decided with build numbers.
void main() {
  final ios = MockUpgraderOS(ios: true, os: 'ios', osv: '18.6');

  String item(
    String os,
    String version, {
    bool critical = false,
    String? minOs,
  }) =>
      '''
    <item>
      <title>Version $version</title>
      <description>
        - First change
        - Second change
      </description>
      <sparkle:version>$version</sparkle:version>
      ${minOs == null ? '' : '<sparkle:minimumSystemVersion>$minOs</sparkle:minimumSystemVersion>'}
      <enclosure url="https://store.example/$os" sparkle:os="$os" />
      ${critical ? '<sparkle:tags><sparkle:criticalUpdate/></sparkle:tags>' : ''}
    </item>''';

  AppUpdateDecision decide(String installed, List<String> items) {
    final xml =
        '<?xml version="1.0" encoding="utf-8"?>'
        '<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">'
        '<channel><title>OFFY</title>${items.join()}</channel></rss>';
    return AppUpdateService.decide(
      installed: Version.parse(installed),
      items: AppUpdateService.itemsFor(xml, ios),
    );
  }

  test('same version and build: no prompt', () {
    final d = decide('1.0.1+6', [item('ios', '1.0.1+6')]);
    expect(d.info, isNull);
    expect(d.force, isFalse);
  });

  test('newer build of the same version is a normal update', () {
    final d = decide('1.0.1+5', [item('ios', '1.0.1+6')]);
    expect(d.force, isFalse);
    expect(d.info!.latestVersion, '1.0.1 (6)');
    expect(d.info!.installedVersion, '1.0.1 (5)');
    expect(d.info!.storeUrl, 'https://store.example/ios');
    expect(d.info!.releaseNotes, ['First change', 'Second change']);
  });

  test('criticalUpdate tag forces everyone below it', () {
    final d = decide('1.0.1+5', [item('ios', '1.0.1+6', critical: true)]);
    expect(d.force, isTrue);
  });

  test('critical item is the minimum build; newer normal item only suggests', () {
    final items = [item('ios', '1.0.2+7'), item('ios', '1.0.1+6', critical: true)];
    final atMinimum = decide('1.0.1+6', items);
    expect(atMinimum.force, isFalse);
    expect(atMinimum.info!.latestVersion, '1.0.2 (7)');

    final belowMinimum = decide('1.0.1+5', items);
    expect(belowMinimum.force, isTrue);
    expect(belowMinimum.info!.latestVersion, '1.0.2 (7)');
  });

  test('items for the other platform are ignored', () {
    final d = decide('1.0.1+6', [
      item('android', '9.9.9+99', critical: true),
      item('ios', '1.0.1+6'),
    ]);
    expect(d.info, isNull);
    expect(d.force, isFalse);
  });

  test('minimumSystemVersion hides an item from older OS versions', () {
    final d = decide('1.0.1+6', [item('ios', '1.0.2+7', minOs: '19.0')]);
    expect(d.info, isNull);
  });

  test('newer installed build than the feed: no prompt', () {
    final d = decide('1.0.2+8', [item('ios', '1.0.2+7', critical: true)]);
    expect(d.info, isNull);
    expect(d.force, isFalse);
  });

  test('version label and release notes for the UI', () {
    expect(AppUpdateService.displayVersion('1.0.2+7'), '1.0.2 (7)');
    expect(AppUpdateService.displayVersion('1.0.2'), '1.0.2');
    expect(
      AppUpdateService.parseReleaseNotes('\n  - First change\n  • Second\n\n'),
      ['First change', 'Second'],
    );
  });
}
