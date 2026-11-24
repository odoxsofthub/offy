import 'package:image_picker/image_picker.dart';
import '../../domain/repositories/log_note_repository.dart';
import '../datasources/log_note_remote_data_source.dart';
import '../models/log_note_model.dart';

class LogNoteRepositoryImpl implements LogNoteRepository {
  final LogNoteRemoteDataSource remoteDataSource;

  LogNoteRepositoryImpl({required this.remoteDataSource});

  @override
  Future<LogNoteResponseModel> getLogNotes(String source, int id, {int page = 1, int limit = 30}) async {
    return await remoteDataSource.getLogNotes(source, id, page: page, limit: limit);
  }

  @override
  Future<LogNoteModel> createLogNote({
    required String source,
    required int id,
    required String text,
    List<XFile> files = const [],
    List<String> mentionNames = const [],
    String? bodyPartsJson,
  }) async {
    return await remoteDataSource.createLogNote(
      source: source,
      id: id,
      text: text,
      files: files,
      mentionNames: mentionNames,
      bodyPartsJson: bodyPartsJson,
    );
  }

  @override
  Future<LogNoteModel> updateLogNote({
    required int messageId,
    required String text,
    List<XFile> files = const [],
    List<int> existingAttachments = const [],
    List<String> mentionNames = const [],
    String? bodyPartsJson,
  }) async {
    return await remoteDataSource.updateLogNote(
      messageId: messageId,
      text: text,
      files: files,
      existingAttachments: existingAttachments,
      mentionNames: mentionNames,
      bodyPartsJson: bodyPartsJson,
    );
  }

  @override
  Future<void> deleteLogNote(int messageId) async {
    return await remoteDataSource.deleteLogNote(messageId);
  }
}
