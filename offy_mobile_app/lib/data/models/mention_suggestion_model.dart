import '../../core/utils/api_parser_utils.dart';

class MentionSuggestionModel {
  final String id;
  final String name;
  final String avatarUrl;
  final String email;
  final bool isInternalUser;
  final int? userId;

  const MentionSuggestionModel({
    required this.id,
    required this.name,
    this.avatarUrl = '',
    this.email = '',
    this.isInternalUser = false,
    this.userId,
  });

  factory MentionSuggestionModel.fromJson(Map<String, dynamic> json) {
    return MentionSuggestionModel(
      id: parseField<String>(json['id']) ??
          parseField<int>(json['id'])?.toString() ??
          parseField<String>(json['user_id']) ??
          parseField<int>(json['user_id'])?.toString() ??
          '',
      name: parseField<String>(json['name']) ??
          parseField<String>(json['display_name']) ??
          parseField<String>(json['user_name']) ??
          '',
      avatarUrl: parseField<String>(json['image_url']) ??
          parseField<String>(json['avatar_url']) ??
          parseField<String>(json['avatar']) ??
          parseField<String>(json['image']) ??
          '',
      email: parseField<String>(json['email']) ?? '',
      isInternalUser: parseField<bool>(json['is_internal_user']) ?? false,
      userId: parseField<int>(json['user_id']),
    );
  }
}
