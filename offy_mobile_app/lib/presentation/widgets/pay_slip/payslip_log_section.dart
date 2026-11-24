import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../domain/entities/chat_message_entity.dart';
import '../common/chat/app_chat_input_bar_widget.dart';
import '../common/chat/app_chat_message_list_widget.dart';
import '../common/chat/app_chat_message_list_shimmer.dart';

import '../../../../data/models/log_note_model.dart';
import '../../../../domain/entities/attachment_entity.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../viewmodels/pay_slip/payslip_provider.dart';
import '../../../../l10n/app_localizations.dart';

class PayslipLogSection extends StatefulWidget {
  final int payslipId;

  const PayslipLogSection({super.key, required this.payslipId});

  @override
  State<PayslipLogSection> createState() => _PayslipLogSectionState();
}

class _PayslipLogSectionState extends State<PayslipLogSection> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  String? _editingMessageId;
  List<AttachmentEntity> _editingAttachments = [];
  List<String> _editingMentionNames = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PayslipProvider>().fetchPayslipLogs(widget.payslipId);
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _unfocusKeyboard() {
    FocusScope.of(context).unfocus();
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<void> _sendMessage(
    String text,
    List<XFile> files,
    List<String> mentionNames,
    String bodyPartsJson,
  ) async {
    final provider = context.read<PayslipProvider>();

    if (_editingMessageId != null) {
      List<int> existingAttachmentIds = _editingAttachments
          .where((a) => a.id != null)
          .map((a) => int.tryParse(a.id.toString()) ?? 0)
          .where((id) => id > 0)
          .toList();

      if (text.trim().isEmpty && files.isEmpty && existingAttachmentIds.isEmpty) {
        return;
      }

      final msgIdInt = int.tryParse(_editingMessageId!);
      if (msgIdInt == null) return;

      final success = await provider.editLogNote(
        msgIdInt,
        text,
        widget.payslipId,
        files: files,
        existingAttachments: existingAttachmentIds,
        mentionNames: mentionNames,
        bodyPartsJson: bodyPartsJson,
      );

      if (success) {
        setState(() {
          _editingMessageId = null;
          _editingAttachments = [];
          _editingMentionNames = [];
        });
        _inputController.clear();
        _unfocusKeyboard();
      }
    } else {
      if (text.trim().isEmpty && files.isEmpty) return;

      final success = await provider.addLogNote(
        widget.payslipId,
        text,
        files: files,
        mentionNames: mentionNames,
        bodyPartsJson: bodyPartsJson,
      );

      if (success) {
        _inputController.clear();
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Consumer<PayslipProvider>(
          builder: (context, provider, child) {
            final logError = provider.getLogErrorForPayslip(widget.payslipId);
            final hasError = logError != null && logError.trim().isNotEmpty;
            final logs = provider.getLogsForPayslip(widget.payslipId);
            final messages = logs.map((log) {
              return ChatMessageEntity(
                id: log.id,
                message: log.message ?? '',
                timestamp:
                    (log.timeDisplay != null && log.timeDisplay!.isNotEmpty)
                    ? log.timeDisplay!
                    : (log.timestamp != null
                          ? _formatTime(log.timestamp!)
                          : ''),
                date: log.timestamp ?? DateTime.now(),
                isOutgoing: log.isUser ?? true,
                userName: log.senderName ?? '',
                avatarUrl: log.avatarUrl ?? '',
                attachments: log.attachments ?? [],
                mentionNames: log.mentionNames ?? [],
                bodyParts: log.bodyParts,
                isEditable: log.isEditable ?? false,
                isDeletable: log.isDeletable ?? false,
              );
            }).toList();

            final isDark = Theme.of(context).brightness == Brightness.dark;

            return PopScope(
              canPop: _editingMessageId == null,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) return;
                if (_editingMessageId != null) {
                  setState(() {
                    _editingMessageId = null;
                    _editingAttachments = [];
                  });
                  _inputController.clear();
                  _unfocusKeyboard();
                }
              },
              child: Column(
                children: [
                  if (_editingMessageId != null)
                    Container(
                      color: isDark
                          ? Colors.black
                          : Colors.black.withValues(alpha: 0.6),
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _editingMessageId = null;
                                _editingAttachments = [];
                                _editingMentionNames = [];
                              });
                              _inputController.clear();
                              _unfocusKeyboard();
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: EdgeInsets.all(8.r),
                              child: Icon(
                                Icons.arrow_back_ios_new,
                                size: 20.r,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            'Edit message',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: provider.isLoadingLogs
                        ? const AppChatMessageListShimmer()
                        : AppChatMessageListWidget(
                            messages: messages,
                            controller: _scrollController,
                            emptyMessage:
                                AppLocalizations.of(context)?.noLogNotesYet ??
                                'No log notes yet.',
                            errorMessage: logError,
                            editingMessageId: _editingMessageId,
                            onDelete: (item) async {
                              final log = logs.firstWhere(
                                (l) =>
                                    l.message == item.message ||
                                    l.id == item.id,
                                orElse: () => LogNoteModel(
                                  id: '',
                                  expenseId: widget.payslipId,
                                ),
                              );
                              final logId = log.id;
                              if (logId != null && logId.isNotEmpty) {
                                final msgIdInt = int.tryParse(logId);
                                if (msgIdInt != null) {
                                  final success = await provider.deleteLogNote(
                                    widget.payslipId,
                                    msgIdInt,
                                  );
                                  if (success && _editingMessageId == logId) {
                                    setState(() {
                                      _editingMessageId = null;
                                      _editingAttachments = [];
                                      _editingMentionNames = [];
                                    });
                                    _inputController.clear();
                                    _unfocusKeyboard();
                                  }
                                }
                              }
                            },
                            onEdit: (item) {
                              final log = logs.firstWhere(
                                (l) =>
                                    l.message == item.message ||
                                    l.id == item.id,
                                orElse: () => LogNoteModel(
                                  id: '',
                                  expenseId: widget.payslipId,
                                ),
                              );
                              if (log.id != null && log.id!.isNotEmpty) {
                                setState(() {
                                  _editingMessageId = log.id;
                                  _inputController.text = log.message ?? '';
                                  _editingAttachments = List.from(
                                    log.attachments ?? [],
                                  );
                                  _editingMentionNames = List.from(
                                    log.mentionNames ?? [],
                                  );
                                });
                                _focusNode.requestFocus();
                              }
                            },
                          ),
                  ),
                  if (!hasError)
                    AppChatInputBarWidget(
                      enabled: !provider.isLoadingLogs,
                      forceAllowSend: _editingMessageId != null,
                      existingAttachments: _editingAttachments,
                      editingMentionNames: _editingMentionNames,
                      onRemoveExistingAttachment: (attachment) {
                        setState(() {
                          _editingAttachments.removeWhere(
                            (a) => a.id == attachment.id,
                          );
                        });
                      },
                      controller: _inputController,
                      focusNode: _focusNode,
                      maxAvailableHeight: constraints.maxHeight,
                      onSend: () {},
                      onSendWithFiles:
                          (text, files, mentionNames, bodyPartsJson) =>
                              _sendMessage(
                                text,
                                files,
                                mentionNames,
                                bodyPartsJson,
                              ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
