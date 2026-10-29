import '../../core/utils/api_parser_utils.dart';

class AttachmentEntity {
  final int? id;
  final String? name;
  final String? mimetype;
  final String? kind;
  final int? size;
  final String url;
  final bool? downloadRequiresAuth;
  final String? thumbnailUrl;

  const AttachmentEntity({
    this.id,
    this.name,
    this.mimetype,
    this.kind,
    this.size,
    required this.url,
    this.downloadRequiresAuth,
    this.thumbnailUrl,
  });

  factory AttachmentEntity.fromJson(Map<String, dynamic> json) {
    return AttachmentEntity(
      id: parseField<int>(json['id']),
      name: parseField<String>(json['name']),
      mimetype: parseField<String>(json['mimetype']),
      kind: parseField<String>(json['kind']),
      size: parseField<int>(json['size']),
      url: parseField<String>(json['url']) ??
          parseField<String>(json['path']) ??
          '',
      downloadRequiresAuth: parseField<bool>(json['download_requires_auth']),
      thumbnailUrl: parseField<String>(json['thumbnail_url']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (mimetype != null) 'mimetype': mimetype,
      if (kind != null) 'kind': kind,
      if (size != null) 'size': size,
      'url': url,
      if (downloadRequiresAuth != null)
        'download_requires_auth': downloadRequiresAuth,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
    };
  }

  String get displayUrl =>
      (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) ? thumbnailUrl! : url;

  bool get isPdf {
    final lowerKind = kind?.toLowerCase() ?? '';
    if (lowerKind == 'pdf' || lowerKind == 'application/pdf') return true;
    final lowerName = name?.toLowerCase() ?? '';
    if (lowerName.endsWith('.pdf')) return true;
    final pathWithoutQuery = url.split('?').first.toLowerCase();
    if (pathWithoutQuery.startsWith('data:application/pdf')) return true;
    return pathWithoutQuery.endsWith('.pdf');
  }

  bool get isImage {
    if (isText || isPdf) return false;
    final lowerKind = kind?.toLowerCase() ?? '';
    if (lowerKind == 'image' ||
        lowerKind == 'img' ||
        lowerKind.startsWith('image/')) {
      return true;
    }
    final lowerName = name?.toLowerCase() ?? '';
    if (lowerName.endsWith('.png') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.webp') ||
        lowerName.endsWith('.svg') ||
        lowerName.endsWith('.gif') ||
        lowerName.endsWith('.bmp') ||
        lowerName.endsWith('.heic')) {
      return true;
    }
    final pathWithoutQuery = url.split('?').first.toLowerCase();
    if (pathWithoutQuery.startsWith('data:image/')) return true;
    return pathWithoutQuery.endsWith('.png') ||
        pathWithoutQuery.endsWith('.jpg') ||
        pathWithoutQuery.endsWith('.jpeg') ||
        pathWithoutQuery.endsWith('.webp') ||
        pathWithoutQuery.endsWith('.svg') ||
        pathWithoutQuery.endsWith('.gif') ||
        pathWithoutQuery.endsWith('.bmp') ||
        pathWithoutQuery.endsWith('.heic');
  }
  bool get isText {
    final lowerKind = kind?.toLowerCase() ?? '';
    if (lowerKind.startsWith('text/') ||
        lowerKind == 'json' ||
        lowerKind == 'application/json' ||
        lowerKind == 'csv' ||
        lowerKind == 'text/csv' ||
        lowerKind == 'xml' ||
        lowerKind == 'text/xml' ||
        lowerKind == 'application/xml') {
      return true;
    }
    final lowerName = name?.toLowerCase() ?? '';
    if (lowerName.endsWith('.txt') ||
        lowerName.endsWith('.json') ||
        lowerName.endsWith('.csv') ||
        lowerName.endsWith('.log') ||
        lowerName.endsWith('.xml') ||
        lowerName.endsWith('.md') ||
        lowerName.endsWith('.yaml') ||
        lowerName.endsWith('.yml')) {
      return true;
    }
    final pathWithoutQuery = url.split('?').first.toLowerCase();
    return pathWithoutQuery.endsWith('.txt') ||
        pathWithoutQuery.endsWith('.json') ||
        pathWithoutQuery.endsWith('.csv') ||
        pathWithoutQuery.endsWith('.log') ||
        pathWithoutQuery.endsWith('.xml') ||
        pathWithoutQuery.endsWith('.md') ||
        pathWithoutQuery.endsWith('.yaml') ||
        pathWithoutQuery.endsWith('.yml');
  }

  bool get isJson {
    final lowerKind = kind?.toLowerCase() ?? '';
    if (lowerKind == 'json' || lowerKind == 'application/json') return true;
    final lowerName = name?.toLowerCase() ?? '';
    if (lowerName.endsWith('.json')) return true;
    final pathWithoutQuery = url.split('?').first.toLowerCase();
    return pathWithoutQuery.endsWith('.json');
  }

  bool get isCsv {
    final lowerKind = kind?.toLowerCase() ?? '';
    if (lowerKind == 'csv' || lowerKind == 'text/csv') return true;
    final lowerName = name?.toLowerCase() ?? '';
    if (lowerName.endsWith('.csv')) return true;
    final pathWithoutQuery = url.split('?').first.toLowerCase();
    return pathWithoutQuery.endsWith('.csv');
  }

  String get fileName {
    if (name != null && name!.isNotEmpty) return name!;
    final pathWithoutQuery = url.split('?').first;
    final seg = pathWithoutQuery.split('/').last;
    if (seg.isNotEmpty) return seg;
    return 'Document';
  }

  String get fileExtension {
    final fn = fileName;
    if (fn.contains('.')) {
      return fn.split('.').last.toUpperCase();
    }
    if (isPdf) return 'PDF';
    if (isImage) return 'IMG';
    if (isJson) return 'JSON';
    if (isCsv) return 'CSV';
    if (isText) return 'TXT';
    return 'FILE';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttachmentEntity &&
        other.url == url &&
        other.name == name &&
        other.id == id;
  }

  @override
  int get hashCode => Object.hash(url, name, id);
}
