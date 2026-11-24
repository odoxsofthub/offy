import 'package:image_picker/image_picker.dart';
import '../repositories/log_note_repository.dart';
import '../../data/models/log_note_model.dart';

class CreateLogNoteUseCase {
  final LogNoteRepository repository;

  CreateLogNoteUseCase({required this.repository});

  Future<LogNoteModel> call({
    required String source,
    required int id,
    required String text,
    List<XFile> files = const [],
    List<String> mentionNames = const [],
    String? bodyPartsJson,
  }) async {
    return await repository.createLogNote(
      source: source,
      id: id,
      text: text,
      files: files,
      mentionNames: mentionNames,
      bodyPartsJson: bodyPartsJson,
    );
  }
}
