import '../repositories/log_note_repository.dart';

class DeleteLogNoteUseCase {
  final LogNoteRepository repository;

  DeleteLogNoteUseCase({required this.repository});

  Future<void> call(int messageId) async {
    return await repository.deleteLogNote(messageId);
  }
}
