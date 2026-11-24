import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:office_app/core/services/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const secure = FlutterSecureStorage();

  test('moves existing tokens out of SharedPreferences', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'bearer_token': 'bearer-1',
      'refresh_token': 'refresh-1',
      'session_id': 'session-1',
      'selected_company_id': 3,
    });
    final storage = TokenStorage();

    expect(await storage.readBearerToken(), 'bearer-1');
    expect(await storage.readRefreshToken(), 'refresh-1');
    expect(await storage.readSessionId(), 'session-1');
    expect(await storage.readSelectedCompanyId(), 3);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('bearer_token'), isNull);
    expect(prefs.getString('refresh_token'), isNull);
    expect(prefs.getString('session_id'), isNull);
    expect(await secure.read(key: 'bearer_token'), 'bearer-1');
  });

  test('drops Keychain tokens left over from a previous install', () async {
    FlutterSecureStorage.setMockInitialValues({'bearer_token': 'stale'});
    SharedPreferences.setMockInitialValues({});

    expect(await TokenStorage().readBearerToken(), isNull);
    expect(await secure.read(key: 'bearer_token'), isNull);
  });

  test('keeps tokens saved after the move on the next launch', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage().saveBearerToken('bearer-2');

    expect(await TokenStorage().readBearerToken(), 'bearer-2');
  });

  test('clear removes tokens but not the server address', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({'saved_login_url': 'https://hr.example.com'});
    final storage = TokenStorage();
    await storage.saveBearerToken('b');
    await storage.saveRefreshToken('r');
    await storage.saveSelectedCompanyId(2);

    await storage.clear();

    expect(await storage.readBearerToken(), isNull);
    expect(await storage.readRefreshToken(), isNull);
    expect(await storage.readSelectedCompanyId(), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('saved_login_url'), 'https://hr.example.com');
  });
}
