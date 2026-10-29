import '../../core/utils/api_parser_utils.dart';

class FaqItemModel {
  final int id;
  final String title;
  final String description;

  const FaqItemModel({
    required this.id,
    required this.title,
    required this.description,
  });

  String get question => title;
  String get answer => description;

  factory FaqItemModel.fromJson(Map<String, dynamic> json) {
    return FaqItemModel(
      id: parseField<int>(json['id']) ?? 0,
      title: parseField<String>(json['title']) ?? '',
      description: parseField<String>(json['description']) ?? '',
    );
  }
}

class FaqResponseModel {
  final List<FaqItemModel> faqs;

  const FaqResponseModel({
    required this.faqs,
  });

  factory FaqResponseModel.fromJson(Map<String, dynamic> json) {
    final dataMap = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    final faqsList = dataMap['faqs'];
    List<FaqItemModel> parsedFaqs = [];
    if (faqsList is List) {
      parsedFaqs = faqsList
          .whereType<Map<String, dynamic>>()
          .map((item) => FaqItemModel.fromJson(item))
          .toList();
    }

    return FaqResponseModel(faqs: parsedFaqs);
  }
}
