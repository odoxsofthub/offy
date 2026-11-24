import 'dart:typed_data';
import '../../core/utils/api_parser_utils.dart';
import '../../core/utils/document_payload_utils.dart';

class ProfileResponseModel {
  final bool success;
  final String message;
  final ProfileModel? data;

  ProfileResponseModel({
    required this.success,
    required this.message,
    this.data,
  });

  factory ProfileResponseModel.fromJson(Map<String, dynamic> json) {
    return ProfileResponseModel(
      success: parseField<bool>(json['success']) ?? false,
      message: parseField<String>(json['message']) ?? '',
      data: json['data'] != null ? ProfileModel.fromJson(json['data']) : null,
    );
  }
}

class ProfileModel {
  final int id;
  final String name;
  final String? jobTitle;
  final String? email;
  final String? phone;
  final String? mobile;
  final String department;
  final String company;
  final String? workLocation;
  final String avatarUrl;
  final String initials;

  final ProfileHeaderModel? header;
  final ProfileWorkModel? work;
  final ProfilePersonalModel? personal;
  final ProfileDocsModel? docs;
  final List<ProfileCompanyModel> companies;
  final int? selectedCompanyId;
  final String? selectedCompanyName;
  final bool showPrivacyPolicy;
  final bool showTermsConditions;
  final bool showFaq;
  final EmployeeModel? reportTo;
  final List<EmployeeModel> team;

  ProfileModel({
    required this.id,
    required this.name,
    this.jobTitle,
    this.email,
    this.phone,
    this.mobile,
    required this.department,
    required this.company,
    this.workLocation,
    required this.avatarUrl,
    required this.initials,
    this.header,
    this.work,
    this.personal,
    this.docs,
    this.companies = const [],
    this.selectedCompanyId,
    this.selectedCompanyName,
    this.showPrivacyPolicy = true,
    this.showTermsConditions = true,
    this.showFaq = true,
    this.reportTo,
    required this.team,
  });

  factory ProfileModel.empty() {
    return ProfileModel(
      id: 0,
      name: '...',
      jobTitle: null,
      email: null,
      phone: null,
      mobile: null,
      department: '',
      company: '',
      workLocation: null,
      avatarUrl: '',
      initials: '',
      header: null,
      work: null,
      personal: null,
      docs: null,
      companies: const [],
      selectedCompanyId: null,
      selectedCompanyName: null,
      showPrivacyPolicy: true,
      showTermsConditions: true,
      showFaq: true,
      reportTo: null,
      team: const [],
    );
  }

  // Backward compatibility helper for documents list
  List<ProfileDocumentModel> get documents {
    final list = <ProfileDocumentModel>[];
    final empDocs = docs?.employeeDocuments ?? const [];
    final hasIdCardInEmpDocs = empDocs.any((d) => d.code == 'id_card');

    if (!hasIdCardInEmpDocs &&
        docs?.companyId != null &&
        (docs?.companyId?.available ?? false)) {
      list.add(
        ProfileDocumentModel(
          id: -1,
          type: 'company_id',
          name: docs!.companyId!.name,
          imageUrl: docs!.companyId!.downloadEndpoint ?? '',
          mimetype: docs!.companyId!.mimetype,
          code: 'id_card',
          kind: docs!.companyId!.kind,
        ),
      );
    }

    for (int i = 0; i < empDocs.length; i++) {
      final empDoc = empDocs[i];
      final isLegacyIdCard = empDoc.code == 'id_card' && empDoc.id <= 0;
      final resolvedId = empDoc.id > 0 ? empDoc.id : (isLegacyIdCard ? -1 : -(i + 2));
      list.add(
        ProfileDocumentModel(
          id: resolvedId,
          type: isLegacyIdCard
              ? 'company_id'
              : (empDoc.code ?? 'employee_document'),
          name: empDoc.name,
          imageUrl: empDoc.downloadUrl,
          filename: empDoc.filename ?? empDoc.name,
          mimetype: empDoc.mimetype,
          fileSize: empDoc.fileSize,
          code: empDoc.code,
          kind: empDoc.kind,
          initialPayload: empDoc.inlineBytes ?? empDoc.inlineContent,
        ),
      );
    }
    if (docs?.certificates != null) {
      for (int i = 0; i < docs!.certificates.length; i++) {
        final cert = docs!.certificates[i];
        list.add(
          ProfileDocumentModel(
            id: cert.id,
            type: 'certificate',
            name: cert.name,
            imageUrl: cert.downloadUrl,
            filename: cert.filename,
            mimetype: cert.mimetype,
            fileSize: cert.fileSize,
            kind: cert.kind,
          ),
        );
      }
    }
    return list;
  }

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: parseField<int>(json['id']) ?? 0,
      name: parseField<String>(json['name']) ?? 'Employee',
      jobTitle: parseField<String>(json['job_title']),
      email: parseField<String>(json['email']),
      phone: parseField<String>(json['phone']),
      mobile: parseField<String>(json['mobile']),
      department: parseField<String>(json['department']) ?? '',
      company: parseField<String>(json['company']) ?? '',
      workLocation: parseField<String>(json['work_location']),
      avatarUrl: parseField<String>(json['avatar_url']) ?? '',
      initials: parseField<String>(json['initials']) ?? '',
      header: json['header'] is Map<String, dynamic>
          ? ProfileHeaderModel.fromJson(json['header'])
          : null,
      work: json['work'] is Map<String, dynamic>
          ? ProfileWorkModel.fromJson(json['work'])
          : null,
      personal: json['personal'] is Map<String, dynamic>
          ? ProfilePersonalModel.fromJson(json['personal'])
          : null,
      docs: json['docs'] is Map<String, dynamic>
          ? ProfileDocsModel.fromJson(json['docs'])
          : null,
      companies:
          (json['companies'] as List<dynamic>?)
              ?.map(
                (e) => ProfileCompanyModel.fromJson(
                  e is Map<String, dynamic> ? e : {},
                ),
              )
              .toList() ??
          [],
      selectedCompanyId: parseField<int>(json['selected_company_id']),
      selectedCompanyName: parseField<String>(json['selected_company_name']),
      showPrivacyPolicy: parseField<bool>(json['show_privacy_policy']) ?? true,
      showTermsConditions:
          parseField<bool>(json['show_terms_conditions']) ?? true,
      showFaq: parseField<bool>(json['show_faq']) ?? true,
      reportTo: json['report_to'] is Map<String, dynamic>
          ? EmployeeModel.fromJson(json['report_to'])
          : null,
      team:
          (json['team'] as List<dynamic>?)
              ?.map(
                (e) =>
                    EmployeeModel.fromJson(e is Map<String, dynamic> ? e : {}),
              )
              .toList() ??
          [],
    );
  }
}

class ProfileCompanyModel {
  final int? id;
  final String? name;
  final bool? isDefault;
  final bool? isSelected;

  ProfileCompanyModel({this.id, this.name, this.isDefault, this.isSelected});

  factory ProfileCompanyModel.fromJson(Map<String, dynamic> json) {
    return ProfileCompanyModel(
      id: parseField<int>(json['id']),
      name: parseField<String>(json['name']),
      isDefault: parseField<bool>(json['is_default']),
      isSelected: parseField<bool>(json['is_selected']),
    );
  }
}

class ProfileHeaderModel {
  final String name;
  final String? jobTitle;
  final String avatarUrl;
  final String initials;

  ProfileHeaderModel({
    required this.name,
    this.jobTitle,
    required this.avatarUrl,
    required this.initials,
  });

  factory ProfileHeaderModel.fromJson(Map<String, dynamic> json) {
    return ProfileHeaderModel(
      name: parseField<String>(json['name']) ?? '',
      jobTitle: parseField<String>(json['job_title']),
      avatarUrl: parseField<String>(json['avatar_url']) ?? '',
      initials: parseField<String>(json['initials']) ?? '',
    );
  }
}

class ProfileWorkManagerModel {
  final int id;
  final String name;
  final String? email;
  final bool canConnect;

  ProfileWorkManagerModel({
    required this.id,
    required this.name,
    this.email,
    this.canConnect = false,
  });

  factory ProfileWorkManagerModel.fromJson(Map<String, dynamic> json) {
    return ProfileWorkManagerModel(
      id: parseField<int>(json['id']) ?? 0,
      name: parseField<String>(json['name']) ?? '',
      email: parseField<String>(json['email']),
      canConnect: parseField<bool>(json['can_connect']) ?? false,
    );
  }
}

class ProfileWorkModel {
  final String? email;
  final String? phone;
  final String? jobTitle;
  final String? jobPosition;
  final ProfileWorkManagerModel? manager;
  final String? contractStartDate;
  final String? contractStartDateDisplay;
  final ProfileBankModel? bank;
  final List<ProfileBankModel> bankAccounts;

  ProfileWorkModel({
    this.email,
    this.phone,
    this.jobTitle,
    this.jobPosition,
    this.manager,
    this.contractStartDate,
    this.contractStartDateDisplay,
    this.bank,
    this.bankAccounts = const [],
  });

  String? get managerName => manager?.name;
  bool get managerCanConnect => manager?.canConnect ?? false;

  factory ProfileWorkModel.fromJson(Map<String, dynamic> json) {
    ProfileWorkManagerModel? managerModel;
    if (json['manager'] is Map<String, dynamic>) {
      managerModel = ProfileWorkManagerModel.fromJson(json['manager']);
    } else if (json['manager'] is String) {
      managerModel = ProfileWorkManagerModel(
        id: 0,
        name: parseField<String>(json['manager']) ?? '',
        canConnect: parseField<bool>(json['can_connect']) ?? false,
      );
    }

    return ProfileWorkModel(
      email: parseField<String>(json['email']),
      phone: parseField<String>(json['phone']),
      jobTitle: parseField<String>(json['job_title']),
      jobPosition: parseField<String>(json['job_position']),
      manager: managerModel,
      contractStartDate: parseField<String>(json['contract_start_date']),
      contractStartDateDisplay: parseField<String>(
        json['contract_start_date_display'],
      ),
      bankAccounts: (json['bank_accounts'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ProfileBankModel.fromJson)
              .toList() ??
          const [],
      bank: json['bank'] is Map<String, dynamic>
          ? ProfileBankModel.fromJson(json['bank'])
          : null,
    );
  }
}

class ProfileBankModel {
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;

  ProfileBankModel({this.bankName, this.accountNumber, this.ifscCode});

  factory ProfileBankModel.fromJson(Map<String, dynamic> json) {
    return ProfileBankModel(
      bankName: parseField<String>(json['bank_name']),
      accountNumber: parseField<String>(json['account_number']),
      ifscCode: parseField<String>(json['ifsc_code']),
    );
  }
}

class ProfilePersonalModel {
  final String? personalEmail;
  final String? phone;
  final String? bloodGroup;
  final String? gender;
  final String? dateOfBirth;
  final String? dateOfBirthDisplay;
  final String? maritalStatus;
  final String? nationality;
  final String? birthPlace;
  final String? residentialAddress;
  final String? permanentAddress;
  final String? educationLevel;
  final String? fieldOfStudy;

  ProfilePersonalModel({
    this.personalEmail,
    this.phone,
    this.bloodGroup,
    this.gender,
    this.dateOfBirth,
    this.dateOfBirthDisplay,
    this.maritalStatus,
    this.nationality,
    this.birthPlace,
    this.residentialAddress,
    this.permanentAddress,
    this.educationLevel,
    this.fieldOfStudy,
  });

  factory ProfilePersonalModel.fromJson(Map<String, dynamic> json) {
    return ProfilePersonalModel(
      personalEmail: parseField<String>(json['personal_email']),
      phone: parseField<String>(json['phone']),
      bloodGroup: parseField<String>(json['blood_group']),
      gender: parseField<String>(json['gender']),
      dateOfBirth: parseField<String>(json['date_of_birth']),
      dateOfBirthDisplay: parseField<String>(json['date_of_birth_display']),
      maritalStatus: parseField<String>(json['marital_status']),
      nationality: parseField<String>(json['nationality']),
      birthPlace: parseField<String>(json['birth_place']),
      residentialAddress: parseField<String>(json['residential_address']),
      permanentAddress: parseField<String>(json['permanent_address']),
      educationLevel: parseField<String>(json['education_level']),
      fieldOfStudy: parseField<String>(json['field_of_study']),
    );
  }
}

class ProfileDocsModel {
  final ProfileDocItemModel? companyId;
  final List<ProfileEmployeeDocModel> employeeDocuments;
  final List<ProfileCertificateDocModel> certificates;

  ProfileDocsModel({
    this.companyId,
    this.employeeDocuments = const [],
    this.certificates = const [],
  });

  factory ProfileDocsModel.fromJson(Map<String, dynamic> json) {
    return ProfileDocsModel(
      companyId: json['company_id'] is Map<String, dynamic>
          ? ProfileDocItemModel.fromJson(
              json['company_id'] as Map<String, dynamic>,
            )
          : null,
      employeeDocuments:
          (json['employee_documents'] as List<dynamic>?)
              ?.map(
                (e) => ProfileEmployeeDocModel.fromJson(
                  e is Map<String, dynamic> ? e : {},
                ),
              )
              .toList() ??
          [],
      certificates:
          (json['certificates'] as List<dynamic>?)
              ?.map(
                (e) => ProfileCertificateDocModel.fromJson(
                  e is Map<String, dynamic> ? e : {},
                ),
              )
              .toList() ??
          [],
    );
  }
}

class ProfileDocItemModel {
  final bool available;
  final String name;
  final String? mimetype;
  final String? kind;
  final String? downloadEndpoint;

  ProfileDocItemModel({
    required this.available,
    required this.name,
    this.mimetype,
    this.kind,
    this.downloadEndpoint,
  });

  factory ProfileDocItemModel.fromJson(Map<String, dynamic> json) {
    final download = json['download'];
    return ProfileDocItemModel(
      available: parseField<bool>(json['available']) ?? false,
      name: parseField<String>(json['name']) ?? 'Company ID',
      mimetype: parseField<String>(json['mimetype']),
      kind: parseField<String>(json['kind']),
      downloadEndpoint: download is Map<String, dynamic>
          ? parseField<String>(download['endpoint'])
          : parseField<String>(download),
    );
  }
}

class ProfileEmployeeDocModel {
  final int id;
  final String? code;
  final String name;
  final String? filename;
  final String? mimetype;
  final String? kind;
  final int? fileSize;
  final ProfileDocDownloadInfoModel? downloadInfo;
  final ProfileDocPreviewInfoModel? previewInfo;
  final String? url;
  final String? inlineContent;

  ProfileEmployeeDocModel({
    this.id = 0,
    this.code,
    required this.name,
    this.filename,
    this.mimetype,
    this.kind,
    this.fileSize,
    this.downloadInfo,
    this.previewInfo,
    this.url,
    this.inlineContent,
  });

  Uint8List? get inlineBytes {
    if (inlineContent != null && inlineContent!.isNotEmpty) {
      return DocumentPayloadUtils.extractBytes(inlineContent);
    }
    if (url != null && (DocumentPayloadUtils.isDataUri(url!) || DocumentPayloadUtils.isBase64(url!))) {
      return DocumentPayloadUtils.extractBytes(url!);
    }
    return null;
  }

  String get downloadUrl {
    final ep = downloadInfo?.endpoint;
    if (ep != null && ep.isNotEmpty) return ep;
    if (url != null && url!.isNotEmpty) return url!;
    if (id > 0) return '/api/mobile/v1/profile/documents/$id/download';
    if (code != null && code!.isNotEmpty) return '/api/mobile/v1/profile/employee-documents/$code';
    return '';
  }

  String get previewUrl {
    final ep = previewInfo?.endpoint;
    if (ep != null && ep.isNotEmpty) return ep;
    if (id > 0) return '/api/mobile/v1/profile/documents/$id/preview';
    return '';
  }

  factory ProfileEmployeeDocModel.fromJson(Map<String, dynamic> json) {
    final rawDownload = json['download'];
    ProfileDocDownloadInfoModel? download;
    String? downloadString;
    if (rawDownload is Map<String, dynamic>) {
      download = ProfileDocDownloadInfoModel.fromJson(rawDownload);
    } else if (rawDownload is String) {
      downloadString = rawDownload;
    }

    final rawPreview = json['preview'];
    ProfileDocPreviewInfoModel? preview;
    String? previewString;
    if (rawPreview is Map<String, dynamic>) {
      preview = ProfileDocPreviewInfoModel.fromJson(rawPreview);
    } else if (rawPreview is String) {
      previewString = rawPreview;
    }

    final directUrl = parseField<String>(json['url']) ??
        parseField<String>(json['image_url']) ??
        parseField<String>(json['path']) ??
        parseField<String>(json['image']) ??
        downloadString;

    final inline = parseField<String>(json['content']) ??
        parseField<String>(json['base64']) ??
        parseField<String>(json['data']) ??
        previewString;

    return ProfileEmployeeDocModel(
      id: parseField<int>(json['id']) ?? 0,
      code: parseField<String>(json['code']),
      name: parseField<String>(json['name']) ?? 'Document',
      filename: parseField<String>(json['filename']),
      mimetype: parseField<String>(json['mimetype']),
      kind: parseField<String>(json['kind']),
      fileSize: parseField<int>(json['file_size']),
      downloadInfo: download,
      previewInfo: preview,
      url: directUrl,
      inlineContent: inline,
    );
  }
}

class ProfileCertificateDocModel {
  final int id;
  final String name;
  final String? filename;
  final String? mimetype;
  final int? fileSize;
  final ProfileDocDownloadInfoModel? downloadInfo;
  final String? kind;
  final ProfileDocPreviewInfoModel? previewInfo;

  ProfileCertificateDocModel({
    required this.id,
    required this.name,
    this.filename,
    this.mimetype,
    this.fileSize,
    this.downloadInfo,
    this.kind,
    this.previewInfo,
  });

  String get downloadUrl =>
      downloadInfo?.endpoint ?? '/api/mobile/v1/profile/documents/$id/download';

  String get previewUrl =>
      previewInfo?.endpoint ?? '/api/mobile/v1/profile/documents/$id/preview';

  factory ProfileCertificateDocModel.fromJson(Map<String, dynamic> json) {
    ProfileDocDownloadInfoModel? info;
    if (json['download'] is Map<String, dynamic>) {
      info = ProfileDocDownloadInfoModel.fromJson(
        json['download'] as Map<String, dynamic>,
      );
    }

    ProfileDocPreviewInfoModel? preview;
    if (json['preview'] is Map<String, dynamic>) {
      preview = ProfileDocPreviewInfoModel.fromJson(
        json['preview'] as Map<String, dynamic>,
      );
    }

    return ProfileCertificateDocModel(
      id: parseField<int>(json['id']) ?? 0,
      name: parseField<String>(json['name']) ?? 'Certificate',
      filename: parseField<String>(json['filename']),
      mimetype: parseField<String>(json['mimetype']),
      fileSize: parseField<int>(json['file_size']),
      downloadInfo: info,
      kind: parseField<String>(json['kind']),
      previewInfo: preview,
    );
  }
}

class ProfileDocDownloadInfoModel {
  final String? endpoint;
  final String? method;
  final bool requiresAuth;
  final String? responseType;

  ProfileDocDownloadInfoModel({
    this.endpoint,
    this.method,
    this.requiresAuth = true,
    this.responseType,
  });

  factory ProfileDocDownloadInfoModel.fromJson(Map<String, dynamic> json) {
    return ProfileDocDownloadInfoModel(
      endpoint: parseField<String>(json['endpoint']),
      method: parseField<String>(json['method']),
      requiresAuth: parseField<bool>(json['requires_auth']) ?? true,
      responseType: parseField<String>(json['response']),
    );
  }
}

class ProfileDocPreviewInfoModel {
  final String? endpoint;
  final String? method;
  final bool requiresAuth;
  final String? previewAs;

  ProfileDocPreviewInfoModel({
    this.endpoint,
    this.method,
    this.requiresAuth = true,
    this.previewAs,
  });

  factory ProfileDocPreviewInfoModel.fromJson(Map<String, dynamic> json) {
    return ProfileDocPreviewInfoModel(
      endpoint: parseField<String>(json['endpoint']),
      method: parseField<String>(json['method']),
      requiresAuth: parseField<bool>(json['requires_auth']) ?? true,
      previewAs: parseField<String>(json['preview_as']),
    );
  }
}

class ProfileDocumentModel {
  final int id;
  final String type;
  final String name;
  final String imageUrl;
  final String? filename;
  final String? mimetype;
  final int? fileSize;
  final String? code;
  final String? kind;
  final dynamic initialPayload;

  ProfileDocumentModel({
    required this.id,
    required this.type,
    required this.name,
    required this.imageUrl,
    this.filename,
    this.mimetype,
    this.fileSize,
    this.code,
    this.kind,
    this.initialPayload,
  });

  factory ProfileDocumentModel.fromJson(Map<String, dynamic> json) {
    return ProfileDocumentModel(
      id: parseField<int>(json['id']) ?? 0,
      type: parseField<String>(json['type']) ?? '',
      name: parseField<String>(json['name']) ?? '',
      imageUrl: parseField<String>(json['image_url']) ?? '',
      filename: parseField<String>(json['filename']),
      mimetype: parseField<String>(json['mimetype']),
      fileSize: parseField<int>(json['file_size']),
      code: parseField<String>(json['code']),
      kind: parseField<String>(json['kind']),
      initialPayload: json['payload'] ?? json['content'] ?? json['base64'],
    );
  }
}

class EmployeeModel {
  final int id;
  final String name;
  final String jobTitle;
  final String avatarUrl;
  final String? email;
  final bool canConnect;
  final bool isOnline;

  EmployeeModel({
    required this.id,
    required this.name,
    required this.jobTitle,
    required this.avatarUrl,
    this.email,
    this.canConnect = false,
    this.isOnline = false,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: parseField<int>(json['id']) ?? 0,
      name: parseField<String>(json['name']) ?? '',
      jobTitle: parseField<String>(json['job_title']) ?? '',
      avatarUrl: parseField<String>(json['avatar_url']) ?? '',
      email: parseField<String>(json['email']),
      canConnect: parseField<bool>(json['can_connect']) ?? false,
      isOnline: parseField<bool>(json['is_online']) ?? false,
    );
  }
}
