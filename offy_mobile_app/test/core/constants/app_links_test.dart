import 'package:flutter_test/flutter_test.dart';
import 'package:office_app/core/constants/app_links.dart';

void main() {
  group('AppLinks.parseAppcastUrl', () {
    test('accepts http and https URLs', () {
      expect(
        AppLinks.parseAppcastUrl('https://example.com/appcast.xml'),
        Uri.parse('https://example.com/appcast.xml'),
      );
      expect(AppLinks.parseAppcastUrl(' http://10.0.2.2/a.xml '), isNotNull);
    });

    test('returns null for empty, relative or non-http values', () {
      for (final raw in [
        '',
        '   ',
        'appcast.xml',
        'ftp://host/a.xml',
        'not a url',
      ]) {
        expect(AppLinks.parseAppcastUrl(raw), isNull, reason: raw);
      }
    });

    test('reads APPCAST_URL from the build environment', () {
      const raw = String.fromEnvironment('APPCAST_URL');
      expect(AppLinks.appcast, AppLinks.parseAppcastUrl(raw));
      if (raw.isEmpty) expect(AppLinks.appcast, isNull);
    });
  });
}
