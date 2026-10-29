import '../../core/utils/api_parser_utils.dart';

class LoginResponseModel {
  const LoginResponseModel({
    required this.token,
    this.refreshToken,
    this.user,
    required this.expiresAt,
    required this.refreshExpiresAt,
    required this.selectedCompanyIds,
    this.companySessionId,
  });

  final String token;
  final String? refreshToken;
  final UserModel? user;
  final String expiresAt;
  final String refreshExpiresAt;
  final List<int> selectedCompanyIds;
  final String? companySessionId;

  int? get primarySelectedCompanyId =>
      selectedCompanyIds.isNotEmpty ? selectedCompanyIds.first : null;

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      token: parseField<String>(json['token']) ?? '',
      refreshToken: parseField<String>(json['refreshToken']),
      user: json['user'] is Map<String, dynamic>
          ? UserModel.fromJson(json['user'])
          : null,
      expiresAt: parseField<String>(json['expiresAt']) ?? '',
      refreshExpiresAt: parseField<String>(json['refreshExpiresAt']) ?? '',
      selectedCompanyIds:
          (json['selectedCompanyIds'] as List<dynamic>?)
              ?.map((e) => parseField<int>(e) ?? 0)
              .where((e) => e != 0)
              .toList() ??
          const [],
      companySessionId: parseField<String>(json['companySessionId']),
    );
  }
}

class UserModel {
  const UserModel({required this.id, required this.name, required this.login});

  final int id;
  final String name;
  final String login;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: parseField<int>(json['id']) ?? 0,
      name: parseField<String>(json['name']) ?? '',
      login: parseField<String>(json['login']) ?? '',
    );
  }
}
