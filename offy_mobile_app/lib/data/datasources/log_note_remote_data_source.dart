import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/attachment_entity.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_globals.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../models/log_note_model.dart';

abstract class LogNoteRemoteDataSource {
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

class LogNoteRemoteDataSourceImpl implements LogNoteRemoteDataSource {
  final ApiClient client;

  LogNoteRemoteDataSourceImpl({required this.client});

  @override
  Future<LogNoteResponseModel> getLogNotes(String source, int id, {int page = 1, int limit = 30}) async {
    if (AppGlobals.isDesignMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return const LogNoteResponseModel();
    }

    final url = '${ApiConstants.logNoteMessages}?source=$source&id=$id&page=$page&limit=$limit';

    final response = await client.get<LogNoteResponseModel>(
      url,
      parser: (json) {
        if (json is Map<String, dynamic>) {
          return LogNoteResponseModel.fromJson(
            json,
            defaultExpenseId: id,
          );
        }
        return const LogNoteResponseModel();
      },
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw AppException(response.message);
    }
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
    if (AppGlobals.isDesignMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return LogNoteModel(
        id: 'log_${DateTime.now().millisecondsSinceEpoch}',
        expenseId: id,
        senderName: 'You',
        isUser: true,
        message: text.trim(),
        timestamp: DateTime.now(),
        attachments: files.map((f) => AttachmentEntity(url: f.path)).toList(),
        mentionNames: mentionNames,
      );
    }

    String finalBodyPartsJson = bodyPartsJson ?? '';
    if (finalBodyPartsJson.isEmpty) {
      final List<Map<String, dynamic>> bodyParts = [];
      if (text.trim().isNotEmpty) {
        bodyParts.add({"type": "text", "text": text.trim()});
      }
      finalBodyPartsJson = jsonEncode(bodyParts);
    }

    final fields = {
      'source': source,
      'id': id.toString(),
      'body_parts': finalBodyPartsJson,
    };

    List<http.MultipartFile> multipartFiles = [];
    for (var file in files) {
      multipartFiles.add(
        await http.MultipartFile.fromPath('attachment', file.path),
      );
    }

    final response = await client.postMultipart<LogNoteModel>(
      ApiConstants.createLogNoteMessage,
      fields: fields,
      files: multipartFiles,
      isSubmission: true,
      parser: (json) {
        if (json is Map<String, dynamic>) {
          // The created message might be nested inside 'message' field
          final messageJson = json['message'] is Map<String, dynamic> 
              ? json['message'] as Map<String, dynamic>
              : json;
          return LogNoteModel.fromJson(messageJson, defaultExpenseId: id);
        }
        return LogNoteModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          expenseId: id,
          senderName: 'You',
          isUser: true,
          message: text,
          timestamp: DateTime.now(),
        );
      },
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw AppException(response.message);
    }
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
    if (AppGlobals.isDesignMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return LogNoteModel(
        id: messageId.toString(),
        expenseId: 0,
        senderName: 'You',
        isUser: true,
        message: text.trim(),
        timestamp: DateTime.now(),
        attachments: files.map((f) => AttachmentEntity(url: f.path)).toList(),
        mentionNames: mentionNames,
      );
    }

    String finalBodyPartsJson = bodyPartsJson ?? '';
    if (finalBodyPartsJson.isEmpty) {
      final List<Map<String, dynamic>> bodyParts = [];
      if (text.trim().isNotEmpty) {
        bodyParts.add({"type": "text", "text": text.trim()});
      }
      finalBodyPartsJson = jsonEncode(bodyParts);
    }

    final fields = {
      'body_parts': finalBodyPartsJson,
    };
    if (existingAttachments.isNotEmpty) {
      fields['existing_attachments'] = jsonEncode(existingAttachments);
    }

    List<http.MultipartFile> multipartFiles = [];
    for (var file in files) {
      multipartFiles.add(
        await http.MultipartFile.fromPath('attachment', file.path),
      );
    }

    final url = '${ApiConstants.updateLogNoteMessage}/$messageId';

    final response = await client.patchMultipart<LogNoteModel>(
      url,
      fields: fields,
      files: multipartFiles,
      parser: (json) {
        if (json is Map<String, dynamic>) {
          final messageJson = json['message'] is Map<String, dynamic>
              ? json['message'] as Map<String, dynamic>
              : json;
          return LogNoteModel.fromJson(messageJson, defaultExpenseId: 0);
        }
        return LogNoteModel(
          id: messageId.toString(),
          expenseId: 0,
          senderName: 'You',
          isUser: true,
          message: text,
          timestamp: DateTime.now(),
        );
      },
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw AppException(response.message);
    }
  }

  @override
  Future<void> deleteLogNote(int messageId) async {
    if (AppGlobals.isDesignMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    final url = '${ApiConstants.deleteLogNoteMessage}?message_id=$messageId';

    try {
      final response = await client.delete<void>(
        url,
        parser: (json) {},
      );

      if (!response.success) {
        throw AppException(response.message);
      }
    } on AppException catch (e) {
      if (e.statusCode == 404 || (e.message != null && e.message!.toLowerCase().contains('not found'))) {
        return;
      }
      rethrow;
    }
  }
}
