import 'package:flutter/material.dart';
import '../../../data/datasources/terms_conditions_remote_data_source.dart';
import '../../../data/models/terms_conditions_model.dart';
import '../../../core/errors/app_exception.dart';

class TermsConditionsProvider extends ChangeNotifier {
  final TermsConditionsRemoteDataSource dataSource;

  TermsConditionsProvider({required this.dataSource});

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  TermsConditionsModel? _termsConditions;
  TermsConditionsModel? get termsConditions => _termsConditions;

  Future<void> fetchTermsConditions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _termsConditions = await dataSource.getTermsConditions();
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
