import '../../core/utils/api_parser_utils.dart';

class TermsConditionsModel {
  final int? id;
  final String title;
  final String body;
  final bool? isPublished;
  final String? updatedAt;

  const TermsConditionsModel({
    this.id,
    required this.title,
    required this.body,
    this.isPublished,
    this.updatedAt,
  });

  String get content => body;

  factory TermsConditionsModel.fromJson(Map<String, dynamic> json) {
    final termsMap = json['terms_conditions'] is Map<String, dynamic>
        ? json['terms_conditions'] as Map<String, dynamic>
        : json;

    return TermsConditionsModel(
      id: parseField<int>(termsMap['id']),
      title: parseField<String>(termsMap['title']) ?? 'Terms of service',
      body: parseField<String>(termsMap['body']) ??
          parseField<String>(termsMap['content']) ??
          '',
      isPublished: parseField<bool>(termsMap['is_published']),
      updatedAt: parseField<String>(termsMap['updated_at']),
    );
  }
}
