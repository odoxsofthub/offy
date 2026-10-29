import '../../core/utils/api_parser_utils.dart';

class PrivacyPolicyModel {
  final int? id;
  final String title;
  final String body;
  final bool? isPublished;
  final String? updatedAt;

  const PrivacyPolicyModel({
    this.id,
    required this.title,
    required this.body,
    this.isPublished,
    this.updatedAt,
  });

  String get content => body;

  factory PrivacyPolicyModel.fromJson(Map<String, dynamic> json) {
    final policyMap = json['privacy_policy'] is Map<String, dynamic>
        ? json['privacy_policy'] as Map<String, dynamic>
        : json;

    return PrivacyPolicyModel(
      id: parseField<int>(policyMap['id']),
      title: parseField<String>(policyMap['title']) ?? 'User policy',
      body: parseField<String>(policyMap['body']) ??
          parseField<String>(policyMap['content']) ??
          '',
      isPublished: parseField<bool>(policyMap['is_published']),
      updatedAt: parseField<String>(policyMap['updated_at']),
    );
  }
}
