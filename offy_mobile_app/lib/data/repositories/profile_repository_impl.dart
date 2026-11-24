import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';
import '../models/profile_response_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;

  ProfileRepositoryImpl({required this.remoteDataSource});

  @override
  Future<ProfileModel> getProfileData() async {
    return await remoteDataSource.getProfile();
  }

  @override
  Future<dynamic> downloadDocument(int documentId) async {
    return await remoteDataSource.downloadDocument(documentId);
  }

  @override
  Future<dynamic> previewDocument(int documentId) async {
    return await remoteDataSource.previewDocument(documentId);
  }

  @override
  Future<dynamic> downloadIdCard() async {
    return await remoteDataSource.downloadIdCard();
  }

  @override
  Future<dynamic> downloadDocumentByUrl(String url) async {
    return await remoteDataSource.downloadDocumentByUrl(url);
  }
}
