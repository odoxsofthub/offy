import 'dart:developer' as developer;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_globals.dart';

/// Bearer, refresh and session tokens live in the Keychain / Android Keystore;
/// the selected company stays in SharedPreferences because it is not a secret.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _secure;
  Future<void>? _ready;

  static const List<String> _secretKeys = [
    'bearer_token',
    'refresh_token',
    'session_id',
  ];

  // Set once tokens have been moved out of SharedPreferences. It is wiped on
  // reinstall, which also clears Keychain items that iOS keeps after uninstall.
  static const String _migratedKey = 'tokens_in_secure_storage';

  String _getKey(String baseKey) {
    return AppGlobals.isDesignMode ? '${baseKey}_design' : baseKey;
  }

  Future<void> _ensureReady() => _ready ??= _migrateFromPreferences();

  Future<void> _migrateFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedKey) == true) return;
    for (final base in _secretKeys) {
      for (final key in [base, '${base}_design']) {
        final legacy = prefs.getString(key);
        if (legacy != null) {
          await _secure.write(key: key, value: legacy);
          await prefs.remove(key);
        } else {
          await _secure.delete(key: key);
        }
      }
    }
    await prefs.setBool(_migratedKey, true);
  }

  Future<String?> _readSecret(String baseKey) async {
    try {
      await _ensureReady();
      return await _secure.read(key: _getKey(baseKey));
    } catch (e) {
      _ready = null;
      developer.log('Secure storage read failed: $e', name: 'TokenStorage');
      return null;
    }
  }

  Future<void> _writeSecret(String baseKey, String value) async {
    await _ensureReady();
    await _secure.write(key: _getKey(baseKey), value: value);
  }

  Future<String?> _readToken(String baseKey) async {
    final token = await _readSecret(baseKey);
    if (!AppGlobals.isDesignMode &&
        token != null &&
        token.startsWith('dummy_design_mode_')) {
      await _secure.delete(key: _getKey(baseKey));
      return null;
    }
    return token;
  }

  Future<String?> readBearerToken() => _readToken('bearer_token');

  Future<String?> readSessionId() => _readSecret('session_id');

  Future<String?> readRefreshToken() => _readToken('refresh_token');

  Future<int?> readSelectedCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_getKey('selected_company_id'));
  }

  Future<void> saveBearerToken(String token) =>
      _writeSecret('bearer_token', token);

  Future<void> saveSessionId(String sessionId) =>
      _writeSecret('session_id', sessionId);

  Future<void> saveRefreshToken(String token) =>
      _writeSecret('refresh_token', token);

  Future<void> saveSelectedCompanyId(int companyId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_getKey('selected_company_id'), companyId);
  }

  Future<void> clear() async {
    try {
      await _ensureReady();
      for (final base in _secretKeys) {
        await _secure.delete(key: _getKey(base));
      }
    } catch (e) {
      developer.log('Secure storage clear failed: $e', name: 'TokenStorage');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getKey('selected_company_id'));
    await prefs.remove(_getKey('cached_access_details'));
  }
}
