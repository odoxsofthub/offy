import '../../data/models/profile_response_model.dart';

abstract class ProfileRepository {
  Future<ProfileModel> getProfileData();
  Future<dynamic> downloadDocument(int documentId);
  Future<dynamic> previewDocument(int documentId);
  Future<dynamic> downloadIdCard();
  Future<dynamic> downloadDocumentByUrl(String url);
}
