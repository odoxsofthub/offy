import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/utils/api_parser_utils.dart';
import '../../domain/entities/attachment_entity.dart';
import 'expense_response_model.dart';

class LogNoteTrackingModel {
  final String field;
  final String? oldValue;
  final String? newValue;

  const LogNoteTrackingModel({
    required this.field,
    this.oldValue,
    this.newValue,
  });

  static LogNoteTrackingModel? tryParse(dynamic entry) {
    if (entry is! Map) return null;
    final field = parseField<String>(entry['field']);
    if (field == null || field.isEmpty) return null;
    return LogNoteTrackingModel(
      field: field,
      oldValue: _asText(entry['old_value']),
      newValue: _asText(entry['new_value']),
    );
  }

  static String? _asText(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    if (value is bool) return value ? 'Yes' : 'No';
    return value.toString();
  }

  String get display {
    final to = newValue ?? '—';
    if (oldValue == null) return '$field: $to';
    return '$field: $oldValue → $to';
  }
}

class LogNoteBodyPart {
  final String type;
  final String text;
  final int? partnerId;
  final String? name;

  const LogNoteBodyPart({
    required this.type,
    required this.text,
    this.partnerId,
    this.name,
  });

  bool get isMention => type == 'mention' || type == 'user';

  factory LogNoteBodyPart.fromJson(Map<String, dynamic> json) {
    final type = parseField<String>(json['type']) ?? 'text';
    final partnerId =
        parseField<int>(json['partner_id']) ?? parseField<int>(json['id']);
    final name = parseField<String>(json['name']) ??
        parseField<String>(json['partner_name']) ??
        parseField<String>(json['display_name']);

    String text = parseField<String>(json['text']) ??
        parseField<String>(json['content']) ??
        parseField<String>(json['value']) ??
        '';
    if (text.isEmpty && name != null && name.isNotEmpty) {
      text = '@$name';
    }

    return LogNoteBodyPart(
      type: type,
      text: text,
      partnerId: partnerId,
      name: name,
    );
  }
}

class LogNoteModel {
  final String? id;
  final int? expenseId;
  final String? senderName;
  final String? avatarUrl;
  final bool? isUser;
  final String? message;
  final DateTime? timestamp;
  final String? timeDisplay;
  final List<AttachmentEntity>? attachments;
  final List<String>? mentionNames;
  final List<LogNoteTrackingModel> tracking;
  final List<LogNoteBodyPart>? bodyParts;
  final bool? isEditable;
  final bool? isDeletable;

  LogNoteModel({
    this.id,
    this.expenseId,
    this.senderName,
    this.avatarUrl,
    this.isUser,
    this.message,
    this.timestamp,
    this.timeDisplay,
    this.attachments,
    this.mentionNames,
    this.tracking = const [],
    this.bodyParts,
    this.isEditable,
    this.isDeletable,
  });

  bool get isTrackingOnly =>
      (message == null || message!.trim().isEmpty) && tracking.isNotEmpty;

  bool get isEmpty =>
      (message == null || message!.trim().isEmpty) &&
      tracking.isEmpty &&
      (attachments == null || attachments!.isEmpty);

  factory LogNoteModel.fromJson(
    Map<String, dynamic> json, {
    int? defaultExpenseId,
  }) {
    final authorMap = json['author'] is Map<String, dynamic>
        ? json['author'] as Map<String, dynamic>
        : null;

    final parsedSenderName = authorMap != null
        ? parseField<String>(authorMap['name'])
        : parseField<String>(json['sender_name']);

    final parsedAvatarUrl = authorMap != null
        ? parseField<String>(authorMap['image_url'])
        : parseField<String>(json['avatar_url']);

    final alignStr = parseField<String>(json['align']);
    final bool? parsedIsUser = alignStr != null
        ? (alignStr == 'own')
        : (parseField<bool>(json['is_user']) ??
              parseField<bool>(json['is_outgoing']));

    String? rawMessage = "";

    final dateStr =
        parseField<String>(json['date']) ??
        parseField<String>(json['created_at']) ??
        parseField<String>(json['timestamp']);

    final parsedTimestamp = (dateStr != null && dateStr.isNotEmpty)
        ? DateTime.tryParse(dateStr)?.toLocal()
        : null;

    final parsedTimeDisplay = parseField<String>(json['time_display']);

    List<AttachmentEntity>? parsedAttachments;
    if (json['attachments'] is List) {
      parsedAttachments = [];
      for (var e in (json['attachments'] as List)) {
        if (e != null) {
          if (e is Map) {
            parsedAttachments.add(
              AttachmentEntity.fromJson(Map<String, dynamic>.from(e)),
            );
          } else {
            final str = e.toString();
            if (str.isNotEmpty) {
              parsedAttachments.add(AttachmentEntity(url: str));
            }
          }
        }
      }
    }

    List<String>? parsedMentions;
    if (json['mentions'] is List) {
      parsedMentions = [];
      for (var e in (json['mentions'] as List)) {
        if (e != null) {
          if (e is Map) {
            final name =
                parseField<String>(e['name']) ??
                parseField<String>(e['display_name']);
            if (name != null && name.isNotEmpty) {
              parsedMentions.add(name);
            }
          } else {
            final str = e.toString();
            if (str.isNotEmpty) parsedMentions.add(str);
          }
        }
      }
    } else if (json['mention_names'] is List) {
      parsedMentions = [];
      for (var e in (json['mention_names'] as List)) {
        if (e != null && e.toString().isNotEmpty) {
          parsedMentions.add(e.toString());
        }
      }
    }

    final parsedBodyParts = <LogNoteBodyPart>[];
    if (json['body_parts'] != null) {
      final bodyPartsRaw = json['body_parts'];
      List<dynamic> partsList = [];
      if (bodyPartsRaw is List) {
        partsList = bodyPartsRaw;
      } else if (bodyPartsRaw is String) {
        try {
          final decoded = jsonDecode(bodyPartsRaw);
          if (decoded is List) {
            partsList = decoded;
          }
        } on FormatException catch (e) {
          debugPrint('Failed to parse log note body_parts JSON: $e');
        }
      }

      if (partsList.isNotEmpty) {
        final buffer = StringBuffer();
        parsedMentions ??= [];
        for (final part in partsList) {
          if (part is Map) {
            final typeStr = parseField<String>(part['type']) ?? 'text';

            if (typeStr == 'attachment' || typeStr == 'file' || typeStr == 'image') {
              final url = parseField<String>(part['url']) ??
                  parseField<String>(part['path']) ??
                  parseField<String>(part['text']);
                  
              String kind = parseField<String>(part['kind']) ?? 
                            parseField<String>(part['mimetype']) ?? 
                            typeStr;
              
              final filename = parseField<String>(part['name']) ?? 
                               parseField<String>(part['filename']) ?? 
                               '';
                               
              if (kind == 'file' || kind == 'attachment') {
                if (filename.toLowerCase().endsWith('.pdf')) {
                  kind = 'pdf';
                }
              }

              if (url != null && url.isNotEmpty) {
                parsedAttachments ??= [];
                parsedAttachments.add(AttachmentEntity(
                  url: url,
                  kind: kind,
                  name: filename.isNotEmpty ? filename : null,
                ));
              }
              continue;
            }

            final bodyPart = LogNoteBodyPart.fromJson(Map<String, dynamic>.from(part));
            parsedBodyParts.add(bodyPart);
            buffer.write(bodyPart.text);

            if (bodyPart.isMention && bodyPart.name != null && bodyPart.name!.isNotEmpty) {
              if (!parsedMentions.contains(bodyPart.name)) {
                parsedMentions.add(bodyPart.name!);
              }
            }
          }
        }
        if (buffer.isNotEmpty) {
          rawMessage = buffer.toString();
        }
      }
    }

    if (rawMessage.isEmpty) {
      rawMessage = parseField<String>(json['message']) ?? '';
    }

    if (parsedBodyParts.isEmpty && rawMessage.isNotEmpty) {
      parsedBodyParts.add(LogNoteBodyPart(type: 'text', text: rawMessage));
    }

    final parsedTracking = <LogNoteTrackingModel>[];
    if (json['tracking'] is List) {
      for (final entry in (json['tracking'] as List)) {
        final tracking = LogNoteTrackingModel.tryParse(entry);
        if (tracking != null) parsedTracking.add(tracking);
      }
    }

    return LogNoteModel(
      tracking: parsedTracking,
      bodyParts: parsedBodyParts,
      id:
          parseField<int>(json['id'])?.toString() ??
          parseField<String>(json['id']),
      expenseId: parseField<int>(json['expense_id']) ?? defaultExpenseId,
      senderName: parsedSenderName,
      avatarUrl: parsedAvatarUrl,
      isUser: parsedIsUser,
      message: rawMessage,
      timestamp: parsedTimestamp,
      timeDisplay: parsedTimeDisplay,
      attachments: parsedAttachments,
      mentionNames: parsedMentions,
      isEditable: parseField<bool>(json['is_editable']),
      isDeletable: parseField<bool>(json['is_deletable']),
    );
  }

  LogNoteModel copyWith({
    String? id,
    int? expenseId,
    String? senderName,
    String? avatarUrl,
    bool? isUser,
    String? message,
    DateTime? timestamp,
    String? timeDisplay,
    List<AttachmentEntity>? attachments,
    List<String>? mentionNames,
    List<LogNoteBodyPart>? bodyParts,
    bool? isEditable,
    bool? isDeletable,
  }) {
    return LogNoteModel(
      id: id ?? this.id,
      expenseId: expenseId ?? this.expenseId,
      senderName: senderName ?? this.senderName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isUser: isUser ?? this.isUser,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      timeDisplay: timeDisplay ?? this.timeDisplay,
      attachments: attachments ?? this.attachments,
      mentionNames: mentionNames ?? this.mentionNames,
      bodyParts: bodyParts ?? this.bodyParts,
      isEditable: isEditable ?? this.isEditable,
      isDeletable: isDeletable ?? this.isDeletable,
    );
  }
}

class LogNoteResponseModel {
  final String source;
  final RecentExpenseModel? record;
  final String? timezone;
  final List<LogNoteModel> messages;

  const LogNoteResponseModel({
    this.source = '',
    this.record,
    this.timezone,
    this.messages = const [],
  });

  factory LogNoteResponseModel.fromJson(
    Map<String, dynamic> json, {
    int? defaultExpenseId,
  }) {
    RecentExpenseModel? parsedRecord;
    if (json['record'] is Map<String, dynamic>) {
      parsedRecord = RecentExpenseModel.fromJson(
        json['record'] as Map<String, dynamic>,
      );
    }

    final parsedMessages = <LogNoteModel>[];
    if (json['messages'] is List) {
      for (var m in (json['messages'] as List)) {
        if (m is Map<String, dynamic>) {
          parsedMessages.add(
            LogNoteModel.fromJson(
              m,
              defaultExpenseId: defaultExpenseId ?? parsedRecord?.id,
            ),
          );
        }
      }
    }

    return LogNoteResponseModel(
      source: parseField<String>(json['source']) ?? '',
      record: parsedRecord,
      timezone: parseField<String>(json['timezone']),
      messages: parsedMessages,
    );
  }
}

