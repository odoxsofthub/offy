import 'package:image_picker/image_picker.dart';
import '../../data/models/log_note_model.dart';
import '../repositories/log_note_repository.dart';

class UpdateLogNoteUseCase {
  final LogNoteRepository repository;

  UpdateLogNoteUseCase({required this.repository});

  Future<LogNoteModel> call({
    required int messageId,
    required String text,
    List<XFile> files = const [],
    List<int> existingAttachments = const [],
    List<String> mentionNames = const [],
    String? bodyPartsJson,
  }) async {
    return await repository.updateLogNote(
      messageId: messageId,
      text: text,
      files: files,
      existingAttachments: existingAttachments,
      mentionNames: mentionNames,
      bodyPartsJson: bodyPartsJson,
    );
  }
}
