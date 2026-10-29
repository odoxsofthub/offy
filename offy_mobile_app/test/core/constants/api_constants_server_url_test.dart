import 'package:flutter_test/flutter_test.dart';
import 'package:office_app/core/constants/api_constants.dart';

void main() {
  const base = 'https://hr.example.com';

  group('ApiConstants.isServerUrl', () {
    test('accepts relative paths and the same origin', () {
      expect(ApiConstants.isServerUrl('/api/mobile/v1/x', base: base), isTrue);
      expect(ApiConstants.isServerUrl('$base/web/image/1', base: base), isTrue);
      expect(ApiConstants.isServerUrl('HTTPS://HR.example.com/a', base: base), isTrue);
      expect(ApiConstants.isServerUrl('https://hr.example.com:443/a', base: base), isTrue);
    });

    test('rejects other hosts, schemes and ports', () {
      for (final url in [
        'https://hr.example.com.evil.net/a.png',
        'https://evil.net/api/mobile/v1/avatar',
        'https://evil.net/?u=https://hr.example.com',
        'http://hr.example.com/a',
        'https://hr.example.com:8443/a',
        '//evil.net/a',
        'not a url',
      ]) {
        expect(ApiConstants.isServerUrl(url, base: base), isFalse, reason: url);
      }
    });

    test('rejects absolute URLs when no server is configured', () {
      expect(ApiConstants.isServerUrl('https://evil.net/a', base: ''), isFalse);
    });
  });
}
