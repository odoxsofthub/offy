import 'dart:developer' as developer;
import '../models/profile_response_model.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';

abstract class ProfileRemoteDataSource {
  Future<ProfileModel> getProfile();
  Future<dynamic> downloadDocument(int documentId);

  /// First page only, for the Docs card thumbnail.
  Future<dynamic> previewDocument(int documentId);

  Future<dynamic> downloadIdCard();
  Future<dynamic> downloadDocumentByUrl(String url);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final ApiClient client;

  ProfileRemoteDataSourceImpl({required this.client});

  @override
  Future<ProfileModel> getProfile() async {
    final response = await client.get<ProfileModel>(
      ApiConstants.profile,
      parser: (json) => ProfileModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw AppException(response.message);
    }
  }

  @override
  Future<dynamic> downloadDocument(int documentId) async {
    final endpoint = '/api/mobile/v1/profile/documents/$documentId/download';
    try {
      final bytes = await client.getBytes(endpoint);
      if (bytes.isNotEmpty) return bytes;
    } catch (e, stackTrace) {
      developer.log(
        'downloadDocument getBytes failed, falling back to JSON get: $e',
        error: e,
        stackTrace: stackTrace,
        name: 'ProfileRemoteDataSource',
      );
    }
    final response = await client.get<dynamic>(
      endpoint,
      parser: (json) => json,
    );
    return response.data;
  }

  @override
  Future<dynamic> previewDocument(int documentId) async {
    // Returns page 1 only, so a large scan costs a few KB instead of the
    // whole file just to fill a 99px-tall card.
    final endpoint = '/api/mobile/v1/profile/documents/$documentId/preview';
    try {
      final bytes = await client.getBytes(endpoint);
      if (bytes.isNotEmpty) return bytes;
    } catch (e, stackTrace) {
      developer.log(
        'previewDocument getBytes failed, falling back to JSON get: $e',
        error: e,
        stackTrace: stackTrace,
        name: 'ProfileRemoteDataSource',
      );
    }
    final response = await client.get<dynamic>(
      endpoint,
      parser: (json) => json,
    );
    return response.data;
  }

  @override
  Future<dynamic> downloadIdCard() async {
    const endpoint = '/api/mobile/v1/profile/id-card';
    try {
      final bytes = await client.getBytes(endpoint);
      if (bytes.isNotEmpty) return bytes;
    } catch (e, stackTrace) {
      developer.log(
        'downloadIdCard getBytes failed, falling back to JSON get: $e',
        error: e,
        stackTrace: stackTrace,
        name: 'ProfileRemoteDataSource',
      );
    }
    final response = await client.get<dynamic>(
      endpoint,
      parser: (json) => json,
    );
    return response.data;
  }

  @override
  Future<dynamic> downloadDocumentByUrl(String url) async {
    if (url.isEmpty) return null;
    try {
      final bytes = await client.getBytes(url);
      if (bytes.isNotEmpty) return bytes;
    } catch (e, stackTrace) {
      developer.log(
        'downloadDocumentByUrl getBytes failed, falling back to JSON get: $e',
        error: e,
        stackTrace: stackTrace,
        name: 'ProfileRemoteDataSource',
      );
    }
    final response = await client.get<dynamic>(
      url,
      parser: (json) => json,
    );
    return response.data;
  }
}
