import '../../data/models/log_note_model.dart';
import 'attachment_entity.dart';

class ChatMessageEntity {
  final String? id;
  final String message;
  final String timestamp;
  final DateTime date;
  final bool isOutgoing;
  final String userName;
  final String avatarUrl;
  final List<AttachmentEntity> attachments;
  final List<String> mentionNames;
  final List<LogNoteBodyPart>? bodyParts;
  final bool isEditable;
  final bool isDeletable;

  const ChatMessageEntity({
    this.id,
    required this.message,
    required this.timestamp,
    required this.date,
    required this.isOutgoing,
    this.userName = '',
    this.avatarUrl = '',
    this.attachments = const [],
    this.mentionNames = const [],
    this.bodyParts,
    this.isEditable = false,
    this.isDeletable = false,
  });

  bool get hasContent {
    final hasMessage = message.trim().isNotEmpty ||
        (bodyParts != null &&
            bodyParts!.any((p) => p.text.trim().isNotEmpty));
    final hasDocuments = attachments.isNotEmpty;
    return hasMessage || hasDocuments;
  }

  bool get isEmpty => !hasContent;
}
