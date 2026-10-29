import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/chat_message_entity.dart';
import '../../../data/models/timeoff_response_model.dart';
import '../../../data/models/log_note_model.dart';
import '../../../domain/entities/attachment_entity.dart';
import '../../../l10n/app_localizations.dart';
import '../../viewmodels/time_off/time_off_provider.dart';
import 'package:provider/provider.dart';
import '../../widgets/common/chat/app_chat_input_bar_widget.dart';
import '../../widgets/common/chat/app_chat_message_list_widget.dart';
import '../../widgets/common/chat/app_chat_message_list_shimmer.dart';
import '../../widgets/common/custom_screen_header.dart';
import '../../widgets/time_off_log/time_off_summary_card_widget.dart';

class TimeOffLogPage extends StatefulWidget {
  final TimeOffLeaveItemModel leave;

  const TimeOffLogPage({super.key, required this.leave});

  @override
  State<TimeOffLogPage> createState() => _TimeOffLogPageState();
}

class _TimeOffLogPageState extends State<TimeOffLogPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  String? _editingMessageId;
  List<AttachmentEntity> _editingAttachments = [];
  List<String> _editingMentionNames = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TimeOffProvider>().fetchTimeOffLogs(widget.leave.id);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _unfocusKeyboard() {
    FocusScope.of(context).unfocus();
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
    final provider = context.read<TimeOffProvider>();

    if (_editingMessageId != null) {
      List<int> existingAttachmentIds = _editingAttachments
          .where((a) => a.id != null)
          .map((a) => int.tryParse(a.id.toString()) ?? 0)
          .where((id) => id > 0)
          .toList();

      if (text.trim().isEmpty && files.isEmpty && existingAttachmentIds.isEmpty) return;

      final msgIdInt = int.tryParse(_editingMessageId!);
      if (msgIdInt == null) return;

      final success = await provider.editLogNote(
        msgIdInt,
        text,
        widget.leave.id,
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
        _messageController.clear();
        _unfocusKeyboard();
      }
    } else {
      if (text.trim().isEmpty && files.isEmpty) return;

      final success = await provider.addLogNote(
        widget.leave.id,
        text,
        files: files,
        mentionNames: mentionNames,
        bodyPartsJson: bodyPartsJson,
      );

      if (success) {
        _messageController.clear();
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: PopScope(
        canPop: _editingMessageId == null,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_editingMessageId != null) {
            setState(() {
              _editingMessageId = null;
              _editingAttachments = [];
              _editingMentionNames = [];
            });
            _messageController.clear();
            _unfocusKeyboard();
          }
        },
        child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.white,
        body: SafeArea(
          bottom: false,
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  // Top Area Stack with Rectangle 1298 background behind header corners & card
                  Stack(
                    children: [
                      Positioned.fill(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          color: _editingMessageId != null
                              ? Color.alphaBlend(Colors.black.withValues(alpha: 0.6), isDark ? AppColors.darkBg : AppColors.white)
                              : (isDark
                                  ? AppColors.darkTopCard.withValues(alpha: 0.4)
                                  : AppColors.light.withValues(alpha: 0.4)),
                        ),
                      ),
                      Column(
                        children: [
                          // Fixed Top Custom Header (Group 5 in Figma)
                          CustomScreenHeader(
                            title: _editingMessageId != null
                                ? 'Edit message'
                                : (AppLocalizations.of(context)?.timeOffTitle ??
                                    'Time off'),
                            onBackTap: () {
                              if (_editingMessageId != null) {
                                setState(() {
                                  _editingMessageId = null;
                                  _editingAttachments = [];
                                  _editingMentionNames = [];
                                });
                                _messageController.clear();
                                _unfocusKeyboard();
                              } else {
                                Navigator.of(context).pop();
                              }
                            },
                          ),

                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _editingMessageId != null ? 0.3 : 1.0,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 5.h),
                              child: TimeOffSummaryCardWidget(
                              dateRange:
                                  AppDateFormatter.formatTimeOffLogRangeStr(
                                    widget.leave.dateFrom,
                                    widget.leave.dateTo,
                                    widget.leave.days,
                                  ),
                              leaveType:
                                  widget.leave.leaveType?.name ??
                                  (AppLocalizations.of(context)?.unknown ??
                                      'Unknown'),
                              reason: widget.leave.name,
                              isForceCollapsed: isKeyboardOpen,
                            ),
                          ),
                        ),
                        ]
                      ),
                    ],
                  ),

                  // Sole Scrollable Chat Message Area
                  Expanded(
                    child: Consumer<TimeOffProvider>(
                      builder: (context, provider, child) {
                        if (provider.isLoadingLogs) {
                          return const AppChatMessageListShimmer();
                        }

                        final logError = provider.getLogErrorForTimeOff(
                          widget.leave.id,
                        );
                        final logs = provider.getLogsForTimeOff(
                          widget.leave.id,
                        );
                        final messages = logs.map((log) {
                          final timeStr =
                              (log.timeDisplay != null &&
                                  log.timeDisplay!.isNotEmpty)
                              ? log.timeDisplay!
                              : (log.timestamp != null
                                    ? _formatTime(log.timestamp!)
                                    : '');
                            return ChatMessageEntity(
                              id: log.id,
                              message: log.message ?? '',
                              timestamp: timeStr,
                              date: log.timestamp ?? DateTime.now(),
                              isOutgoing: log.isUser ?? false,
                              userName: log.senderName ?? '',
                              avatarUrl: log.avatarUrl ?? '',
                              attachments: log.attachments ?? [],
                              mentionNames: log.mentionNames ?? [],
                              bodyParts: log.bodyParts,
                              isEditable: log.isEditable ?? false,
                              isDeletable: log.isDeletable ?? false,
                            );
                        }).toList();

                        return AppChatMessageListWidget(
                          messages: messages,
                          controller: _scrollController,
                          errorMessage: logError,
                          editingMessageId: _editingMessageId,
                          onDelete: (item) async {
                            final log = logs.firstWhere(
                              (l) => l.message == item.message || l.id == item.id,
                              orElse: () => LogNoteModel(id: '', expenseId: widget.leave.id),
                            );
                            final logId = log.id;
                            if (logId != null && logId.isNotEmpty) {
                              final msgIdInt = int.tryParse(logId);
                              if (msgIdInt != null) {
                                final success = await provider.deleteLogNote(widget.leave.id, msgIdInt);
                                if (success && _editingMessageId == logId) {
                                  setState(() {
                                    _editingMessageId = null;
                                    _editingAttachments = [];
                                    _editingMentionNames = [];
                                  });
                                  _messageController.clear();
                                  _unfocusKeyboard();
                                }
                              }
                            }
                          },
                          onEdit: (item) {
                            final log = logs.firstWhere(
                              (l) => l.message == item.message || l.id == item.id,
                              orElse: () => LogNoteModel(id: '', expenseId: widget.leave.id),
                            );
                            if (log.id != null && log.id!.isNotEmpty) {
                              setState(() {
                                _editingMessageId = log.id;
                                _messageController.text = log.message ?? '';
                                _editingAttachments = List.from(log.attachments ?? []);
                                _editingMentionNames = List.from(log.mentionNames ?? []);
                              });
                              _focusNode.requestFocus();
                            }
                          },
                        );
                      },
                    ),
                  ),

                  // Fixed Bottom Message Input Bar (Frame 2609824)
                  Consumer<TimeOffProvider>(
                    builder: (context, provider, child) {
                      final logError = provider.getLogErrorForTimeOff(
                        widget.leave.id,
                      );
                      final hasError =
                          logError != null && logError.trim().isNotEmpty;
                      if (hasError) return const SizedBox.shrink();

                      return AppChatInputBarWidget(
                        enabled: !provider.isLoadingLogs,
                        forceAllowSend: _editingMessageId != null,
                        existingAttachments: _editingAttachments,
                        editingMentionNames: _editingMentionNames,
                        onRemoveExistingAttachment: (attachment) {
                          setState(() {
                            _editingAttachments.removeWhere((a) => a.id == attachment.id);
                          });
                        },
                        controller: _messageController,
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
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
      ),
    );
  }
}
