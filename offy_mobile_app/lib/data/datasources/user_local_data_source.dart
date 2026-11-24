import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_globals.dart';
import '../models/access_details_response_model.dart';

abstract class UserLocalDataSource {
  Future<void> cacheAccessDetails(AccessDetailsResponseModel details);
  AccessDetailsResponseModel? getCachedAccessDetails();
  Future<void> clearCache();
}

class UserLocalDataSourceImpl implements UserLocalDataSource {
  final SharedPreferences sharedPreferences;

  UserLocalDataSourceImpl({required this.sharedPreferences});

  static const String _cachedAccessDetailsKey = 'cached_access_details';

  String _getKey(String baseKey) {
    return AppGlobals.isDesignMode ? '${baseKey}_design' : baseKey;
  }

  @override
  Future<void> cacheAccessDetails(AccessDetailsResponseModel details) async {
    try {
      final jsonStr = json.encode(details.toJson());
      await sharedPreferences.setString(
        _getKey(_cachedAccessDetailsKey),
        jsonStr,
      );
    } catch (e, stack) {
      // Silently catch serialization or storage errors to protect app flow
      debugPrint('UserLocalDataSource: Failed to cache access details: $e\n$stack');
    }
  }

  @override
  AccessDetailsResponseModel? getCachedAccessDetails() {
    try {
      final jsonStr = sharedPreferences.getString(
        _getKey(_cachedAccessDetailsKey),
      );
      if (jsonStr == null || jsonStr.isEmpty) return null;
      final map = json.decode(jsonStr);
      if (map is Map) {
        return AccessDetailsResponseModel.fromJson(
          Map<String, dynamic>.from(map),
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearCache() async {
    await sharedPreferences.remove(_getKey(_cachedAccessDetailsKey));
  }
}
