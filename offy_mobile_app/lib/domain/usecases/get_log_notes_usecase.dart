import '../repositories/log_note_repository.dart';
import '../../data/models/log_note_model.dart';

class GetLogNotesUseCase {
  final LogNoteRepository repository;

  GetLogNotesUseCase({required this.repository});

  Future<LogNoteResponseModel> call(String source, int id, {int page = 1, int limit = 30}) async {
    return await repository.getLogNotes(source, id, page: page, limit: limit);
  }
}
