import 'package:flutter_test/flutter_test.dart';
import 'package:office_app/core/network/api_client.dart';

void main() {
  group('mobileSessionValue', () {
    test('passes through the opaque token the backend issues', () {
      // Shape actually returned by /auth/login and /auth/company.
      expect(mobileSessionValue('qF9nhyZr2qC_'), 'qF9nhyZr2qC_');
      expect(mobileSessionValue('q0D5n6RXlXd0'), 'q0D5n6RXlXd0');
    });

    test('recovers the token from a pre-fix cookie string', () {
      // Older builds stored a cookie string; the bare token must be extracted or the default company is used.
      expect(
        mobileSessionValue('frontend_lang=en_US; session_id=qF9nhyZr2qC_'),
        'qF9nhyZr2qC_',
        reason: 'upgrading users must keep their company selection',
      );
      expect(mobileSessionValue('session_id=abc123'), 'abc123');
    });

    test('returns empty for absent or unusable values', () {
      // Empty means "omit the header", which makes the backend fall back to
      // the default company -- correct, and never a malformed header.
      expect(mobileSessionValue(null), '');
      expect(mobileSessionValue(''), '');
      expect(mobileSessionValue('   '), '');
      expect(mobileSessionValue('frontend_lang=en_US'), '',
          reason: 'a cookie carrying no session_id yields no selector');
    });

    test('never emits a value containing cookie syntax', () {
      // A header value with "=" or ";" in it would be silently rejected or
      // truncated server-side, which is how the original bug stayed hidden.
      for (final input in <String?>[
        null,
        '',
        'qF9nhyZr2qC_',
        'session_id=abc123',
        'frontend_lang=en_US; session_id=abc123',
        'frontend_lang=en_US',
      ]) {
        final result = mobileSessionValue(input);
        expect(result.contains('='), isFalse, reason: 'input: $input');
        expect(result.contains(';'), isFalse, reason: 'input: $input');
      }
    });
  });
}
