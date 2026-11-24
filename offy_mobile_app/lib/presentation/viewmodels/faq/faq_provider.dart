import 'package:flutter/material.dart';
import '../../../data/datasources/faq_remote_data_source.dart';
import '../../../data/models/faq_response_model.dart';
import '../../../core/errors/app_exception.dart';

class FaqProvider extends ChangeNotifier {
  final FaqRemoteDataSource dataSource;

  FaqProvider({required this.dataSource});

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  List<FaqItemModel> _faqs = [];
  List<FaqItemModel> get faqs => _faqs;

  Future<void> fetchFaqs() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await dataSource.getFaqs();
      _faqs = response.faqs;
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
