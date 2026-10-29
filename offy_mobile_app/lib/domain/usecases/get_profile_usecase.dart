import '../repositories/profile_repository.dart';
import '../../data/models/profile_response_model.dart';

class GetProfileDataUseCase {
  final ProfileRepository repository;

  GetProfileDataUseCase({required this.repository});

  Future<ProfileModel> call() async {
    return await repository.getProfileData();
  }

  Future<dynamic> downloadDocument(int documentId) async {
    return await repository.downloadDocument(documentId);
  }

  Future<dynamic> previewDocument(int documentId) async {
    return await repository.previewDocument(documentId);
  }

  Future<dynamic> downloadIdCard() async {
    return await repository.downloadIdCard();
  }

  Future<dynamic> downloadDocumentByUrl(String url) async {
    return await repository.downloadDocumentByUrl(url);
  }
}
