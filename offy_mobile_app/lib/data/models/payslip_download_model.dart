class PayslipDownloadModel {
  final String filename;
  final String contentType;
  final String base64;

  PayslipDownloadModel({
    required this.filename,
    required this.contentType,
    required this.base64,
  });

  factory PayslipDownloadModel.fromJson(Map<String, dynamic> json) {
    return PayslipDownloadModel(
      filename: json['filename'] ?? '',
      contentType: json['content_type'] ?? '',
      base64: json['base64'] ?? '',
    );
  }
}
