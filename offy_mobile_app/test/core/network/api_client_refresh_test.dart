import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:office_app/core/errors/app_exception.dart';
import 'package:office_app/core/network/api_client.dart';
import 'package:office_app/core/services/token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenStorage tokenStorage;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'saved_login_url': 'http://test.local',
      'refresh_token': 'test_refresh_token',
      'bearer_token': 'test_bearer_token',
    });
    final prefs = await SharedPreferences.getInstance();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<SharedPreferences>()) {
      getIt.unregister<SharedPreferences>();
    }
    getIt.registerSingleton<SharedPreferences>(prefs);
    tokenStorage = TokenStorage();
  });

  tearDown(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<SharedPreferences>()) {
      getIt.unregister<SharedPreferences>();
    }
  });

  group('ApiClient token refresh behavior', () {
    test('A thrown refresh error does NOT call onUnauthenticated', () async {
      bool unauthenticatedCalled = false;

      final client = ApiClient(
        tokenStorage: tokenStorage,
        onRefreshToken: () async {
          // Throws server/network error
          throw const ServerException('Server temporarily unavailable');
        },
        onUnauthenticated: () async {
          unauthenticatedCalled = true;
        },
      );

      final mockHttp = MockClient((request) async {
        // Return 401 on initial request to trigger _withTokenRefresh
        return http.Response('{"message":"Unauthorized"}', 401, headers: {
          'content-type': 'application/json',
        });
      });

      await http.runWithClient(() async {
        try {
          await client.get(
            '/test-endpoint',
            retryOnNetworkError: false,
            parser: (json) => json,
          );
          fail('Expected exception was not thrown');
        } catch (e) {
          expect(e, isA<ServerException>());
        }
      }, () => mockHttp);

      // Crucial assertion: onUnauthenticated must NOT be called on thrown errors
      expect(unauthenticatedCalled, isFalse);
    });

    test('Refresh returning false DOES call onUnauthenticated', () async {
      final unauthenticated = Completer<void>();

      final client = ApiClient(
        tokenStorage: tokenStorage,
        onRefreshToken: () async {
          // Explicit rejection
          return false;
        },
        onUnauthenticated: () async {
          unauthenticated.complete();
        },
      );

      final mockHttp = MockClient((request) async {
        return http.Response('{"message":"Unauthorized"}', 401, headers: {
          'content-type': 'application/json',
        });
      });

      // A dead session calls onUnauthenticated and parks the caller's future
      // (no throw), so the calling screen shows no error of its own.
      var settled = false;
      http
          .runWithClient(
            () => client.get(
              '/test-endpoint',
              retryOnNetworkError: false,
              parser: (json) => json,
            ),
            () => mockHttp,
          )
          .then((_) => settled = true, onError: (_) => settled = true);

      await unauthenticated.future.timeout(const Duration(seconds: 5));
      await pumpEventQueue();

      expect(settled, isFalse);
    });
  });
}
