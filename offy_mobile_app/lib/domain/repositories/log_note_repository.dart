import 'package:image_picker/image_picker.dart';
import '../../data/models/log_note_model.dart';

abstract class LogNoteRepository {
  Future<LogNoteResponseModel> getLogNotes(String source, int id, {int page = 1, int limit = 30});
  Future<LogNoteModel> createLogNote({
    required String source,
    required int id,
    required String text,
    List<XFile> files = const [],
    List<String> mentionNames = const [],
    String? bodyPartsJson,
  });
  Future<LogNoteModel> updateLogNote({
    required int messageId,
    required String text,
    List<XFile> files = const [],
    List<int> existingAttachments = const [],
    List<String> mentionNames = const [],
    String? bodyPartsJson,
  });
  Future<void> deleteLogNote(int messageId);
}
