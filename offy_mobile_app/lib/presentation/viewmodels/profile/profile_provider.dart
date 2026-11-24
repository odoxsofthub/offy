import '../../../core/constants/api_constants.dart';
import '../../../core/base/session_provider.dart';
import '../../../data/models/profile_response_model.dart';
import '../../../domain/usecases/get_profile_usecase.dart';
import '../../../core/errors/app_exception.dart';
import '../../widgets/common/cached_image.dart';

class ProfileProvider extends SessionProvider {
  final GetProfileDataUseCase getProfileDataUseCase;

  ProfileProvider({
    required this.getProfileDataUseCase,
    super.sessionResetService,
  });

  @override
  void resetState() {
    _profileData = null;
    _docPreviewData.clear();
    _docDownloadData.clear();
    _docLoadingState.clear();
    _isExpanded = false;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  ProfileModel? _profileData;
  ProfileModel? get profileData => _profileData;

  bool _isExpanded = false;
  bool get isExpanded => _isExpanded;

  void setExpanded(bool value) {
    if (_isExpanded != value) {
      _isExpanded = value;
      notifyListeners();
    }
  }

  Future<void> fetchProfileData() async {
    _isLoading = _profileData == null;
    _error = null;
    if (_isLoading) {
      notifyListeners();
    }

    try {
      _profileData = await getProfileDataUseCase();

      if (_profileData != null && _profileData!.avatarUrl.isNotEmpty) {
        CachedImage.precache(_profileData!.avatarUrl);
      }

      // Re-fetch all documents fresh each time profile data is loaded
      await reloadAllDocuments();
    } on AppException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'An unexpected error occurred: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  final Map<int, dynamic> _docPreviewData = {};
  final Map<int, dynamic> _docDownloadData = {};
  final Map<int, bool> _docLoadingState = {};
  bool _isReloadingDocs = false;
  DateTime? _lastReloadDocsTime;

  dynamic getDocPreview(int documentId) => _docPreviewData[documentId];
  dynamic getDocDownload(int documentId) => _docDownloadData[documentId];
  dynamic getDocPayload(int documentId) =>
      _docPreviewData[documentId] ?? _docDownloadData[documentId];
  bool isDocLoading(int documentId) => _docLoadingState[documentId] ?? false;

  /// Clear all document data so no data is stored.
  void clearDocumentData() {
    _docPreviewData.clear();
    _docDownloadData.clear();
    _docLoadingState.clear();
    notifyListeners();
  }

  /// Reloads all documents from preview API and download API each time the profile tab is opened.
  Future<void> reloadAllDocuments({bool force = false}) async {
    final now = DateTime.now();
    if (!force && _isReloadingDocs) return;
    if (!force &&
        _lastReloadDocsTime != null &&
        now.difference(_lastReloadDocsTime!) < const Duration(milliseconds: 1500)) {
      return;
    }
    _isReloadingDocs = true;
    _lastReloadDocsTime = now;

    try {
      if (_profileData == null) return;

      // 1. Evict any cached image URLs from disk and memory
      for (final doc in _profileData!.documents) {
        if (doc.imageUrl.isNotEmpty) {
          CachedImage.evict(doc.imageUrl);
          if (doc.imageUrl.startsWith('/')) {
            CachedImage.evict('${ApiConstants.baseUrl}${doc.imageUrl}');
          }
        }
      }
      CachedImage.evict('/api/mobile/v1/profile/id-card');
      CachedImage.evict('${ApiConstants.baseUrl}/api/mobile/v1/profile/id-card');

      // 2. Clear previous payloads and show loading shimmer together
      _docPreviewData.clear();
      _docDownloadData.clear();
      for (final doc in _profileData!.documents) {
        _docLoadingState[doc.id] = true;
      }
      notifyListeners();

      // 3. Fetch preview API fresh for card thumbnails (full download is deferred to tap)
      final futures = <Future<void>>[];
      for (final doc in _profileData!.documents) {
        if (doc.type == 'company_id' && doc.id <= 0) {
          futures.add(fetchIdCardPayload());
        } else if (doc.id > 0) {
          // Preview is for the card thumbnail
          futures.add(fetchDocumentPreview(doc.id));
        } else if (doc.imageUrl.isNotEmpty) {
          futures.add(fetchDocumentByUrl(doc.id, doc.imageUrl));
        }
      }
      await Future.wait(futures);
    } finally {
      _isReloadingDocs = false;
    }
  }

  Future<void> fetchDocumentPreview(int documentId) async {
    try {
      final payload = await previewDocument(documentId);
      _docPreviewData[documentId] = payload;
    } catch (_) {
      _docPreviewData[documentId] = null;
    } finally {
      _docLoadingState[documentId] = false;
      notifyListeners();
    }
  }

  Future<void> fetchDocumentDownload(int documentId) async {
    try {
      final payload = await downloadDocument(documentId);
      _docDownloadData[documentId] = payload;
      // Only update preview if preview endpoint did not return data
      if (_docPreviewData[documentId] == null && payload != null) {
        _docPreviewData[documentId] = payload;
        _docLoadingState[documentId] = false;
        notifyListeners();
      }
    } catch (_) {
      _docDownloadData[documentId] = null;
    }
  }

  Future<dynamic> fetchDocumentDownloadSync(int documentId) async {
    try {
      final payload = await downloadDocument(documentId);
      if (payload != null) {
        _docDownloadData[documentId] = payload;
      }
      return payload;
    } catch (_) {
      return null;
    }
  }

  Future<void> fetchDocumentByUrl(int documentId, String url) async {
    _docLoadingState[documentId] = true;
    notifyListeners();

    try {
      final payload = await getProfileDataUseCase.downloadDocumentByUrl(url);
      _docPreviewData[documentId] = payload;
      _docDownloadData[documentId] = payload;
    } catch (_) {
      _docPreviewData[documentId] = null;
      _docDownloadData[documentId] = null;
    } finally {
      _docLoadingState[documentId] = false;
      notifyListeners();
    }
  }

  Future<void> fetchDocumentPayload(
    int documentId, {
    bool preview = false,
    bool force = false,
  }) async {
    if (preview) {
      await fetchDocumentPreview(documentId);
    } else {
      await fetchDocumentDownload(documentId);
    }
  }

  Future<dynamic> previewDocument(int documentId) async {
    return await getProfileDataUseCase.previewDocument(documentId);
  }

  Future<dynamic> downloadDocument(int documentId) async {
    return await getProfileDataUseCase.downloadDocument(documentId);
  }

  static const int idCardDocumentId = -1;

  Future<void> fetchIdCardPayload() async {
    const key = idCardDocumentId;
    _docLoadingState[key] = true;
    notifyListeners();
    try {
      final payload = await getProfileDataUseCase.downloadIdCard();
      _docPreviewData[key] =
          (payload is Map && payload['success'] == false) ? null : payload;
      _docDownloadData[key] = _docPreviewData[key];
    } catch (_) {
      _docPreviewData[key] = null;
      _docDownloadData[key] = null;
    } finally {
      _docLoadingState[key] = false;
      notifyListeners();
    }
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }
}
