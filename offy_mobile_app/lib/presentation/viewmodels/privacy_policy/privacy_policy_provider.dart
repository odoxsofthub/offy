import 'package:flutter/material.dart';
import '../../../data/datasources/privacy_policy_remote_data_source.dart';
import '../../../data/models/privacy_policy_model.dart';
import '../../../core/errors/app_exception.dart';

class PrivacyPolicyProvider extends ChangeNotifier {
  final PrivacyPolicyRemoteDataSource dataSource;

  PrivacyPolicyProvider({required this.dataSource});

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  PrivacyPolicyModel? _privacyPolicy;
  PrivacyPolicyModel? get privacyPolicy => _privacyPolicy;

  Future<void> fetchPrivacyPolicy() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _privacyPolicy = await dataSource.getPrivacyPolicy();
    } on AppException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'An unexpected error occurred: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
