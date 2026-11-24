import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:office_app/core/errors/app_exception.dart';
import 'package:office_app/core/network/api_client.dart';
import 'package:office_app/core/services/token_storage.dart';
import 'package:office_app/data/datasources/auth_remote_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenStorage tokenStorage;
  late ApiClient apiClient;
  late AuthRemoteDataSourceImpl dataSource;

  setUp(() async {
    PackageInfo.setMockInitialValues(
      appName: 'Office App',
      packageName: 'com.odox.office',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'saved_login_url': 'http://test.local',
      'refresh_token': 'existing_refresh_token_123',
      'bearer_token': 'old_bearer_token',
    });

    final prefs = await SharedPreferences.getInstance();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<SharedPreferences>()) {
      getIt.unregister<SharedPreferences>();
    }
    getIt.registerSingleton<SharedPreferences>(prefs);

    tokenStorage = TokenStorage();
    apiClient = ApiClient(tokenStorage: tokenStorage);
    dataSource = AuthRemoteDataSourceImpl(apiClient: apiClient);
  });

  tearDown(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<SharedPreferences>()) {
      getIt.unregister<SharedPreferences>();
    }
  });

  group('AuthRemoteDataSource.refreshToken', () {
    test('Refresh response without refreshToken: stored refresh token is unchanged', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'success': true,
            'message': 'Token refreshed',
            'data': {
              'token': 'brand_new_bearer_token',
              // No refreshToken returned in data
              'expiresAt': '2026-09-22T00:00:00Z',
              'refreshExpiresAt': '2026-10-22T00:00:00Z',
              'selectedCompanyIds': [1],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await http.runWithClient(() async {
        final result = await dataSource.refreshToken();
        expect(result, isTrue);

        // Bearer token must be updated
        final bearer = await tokenStorage.readBearerToken();
        expect(bearer, 'brand_new_bearer_token');

        // Existing refresh token must NOT be overwritten with empty string
        final refresh = await tokenStorage.readRefreshToken();
        expect(refresh, 'existing_refresh_token_123');
      }, () => mockClient);
    });

    test('401 and 403: returns false', () async {
      // Test 401
      var mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'success': false,
            'code': 'invalid_refresh_token',
            'message': 'Invalid or expired refresh token',
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      await http.runWithClient(() async {
        final result = await dataSource.refreshToken();
        expect(result, isFalse);
      }, () => mockClient);

      // Test 403
      mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'success': false,
            'code': 'mobile_access_denied',
            'message': 'Mobile access denied',
          }),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      await http.runWithClient(() async {
        final result = await dataSource.refreshToken();
        expect(result, isFalse);
      }, () => mockClient);
    });

    test('429, 500 and 200 with an HTML body: throws, does not return false', () async {
      // 429 Too Many Requests
      var mockClient = MockClient((request) async {
        return http.Response('Too many requests', 429);
      });

      await http.runWithClient(() async {
        expect(() => dataSource.refreshToken(), throwsA(isA<ServerException>()));
      }, () => mockClient);

      // 500 Internal Server Error
      mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      await http.runWithClient(() async {
        expect(() => dataSource.refreshToken(), throwsA(isA<ServerException>()));
      }, () => mockClient);

      // 200 with an HTML body
      mockClient = MockClient((request) async {
        return http.Response('<html><body>502 Bad Gateway</body></html>', 200);
      });

      await http.runWithClient(() async {
        expect(() => dataSource.refreshToken(), throwsA(isA<ServerException>()));
      }, () => mockClient);
    });

    test('Malformed JSON: throws, does not return false', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{ "success": true, data: invalid_json }', 200);
      });

      await http.runWithClient(() async {
        expect(() => dataSource.refreshToken(), throwsA(isA<ServerException>()));
      }, () => mockClient);
    });
  });
}
