import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/chat_message_entity.dart';
import '../../../domain/entities/attachment_entity.dart';
import '../../../data/models/calendar_day_schedule_model.dart';
import '../../../data/models/log_note_model.dart';
import '../../viewmodels/calendar/calendar_provider.dart';
import 'package:provider/provider.dart';
import '../../widgets/common/chat/app_chat_input_bar_widget.dart';
import '../../widgets/common/chat/app_chat_message_list_widget.dart';
import '../../widgets/common/chat/app_chat_message_list_shimmer.dart';
import '../../widgets/common/custom_screen_header.dart';
import '../../widgets/common/gradient_circle_painter.dart';
import '../../widgets/calendar/schedule_log_summary_card_widget.dart';
import '../../widgets/calendar/new_event_bottom_sheet.dart';

class ScheduleLogPage extends StatefulWidget {
  final CalendarScheduleItemModel item;

  const ScheduleLogPage({super.key, required this.item});

  @override
  State<ScheduleLogPage> createState() => _ScheduleLogPageState();
}

class _ScheduleLogPageState extends State<ScheduleLogPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  String? _editingMessageId;
  List<AttachmentEntity> _editingAttachments = [];
  List<String> _editingMentionNames = [];

  int _getParsedId() {
    if (_currentItem.sourceId > 0) {
      return _currentItem.sourceId;
    }
    final eventIdStr = _currentItem.iid.isNotEmpty
        ? _currentItem.iid
        : _currentItem.id;
    return int.tryParse(eventIdStr) ?? 0;
  }

  late CalendarScheduleItemModel _currentItem;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CalendarProvider>();
      provider.fetchCalendarLogs(_getParsedId());
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
    final hour = (timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12)
        .toString()
        .padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute $period';
  }

  Future<void> _sendMessage(
    String text,
    List<XFile> files,
    List<String> mentionNames,
    String bodyPartsJson,
  ) async {
    final provider = context.read<CalendarProvider>();

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
        _getParsedId(),
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
        _getParsedId(),
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
                  // Top Area Stack with Rectangle 1298 background behind header & card
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
                          // Fixed Top Custom Header (Group 5 / Rectangle 2 in Figma)
                          CustomScreenHeader(
                            title: _editingMessageId != null
                                ? 'Edit message'
                                : (AppLocalizations.of(context)?.calendarTitle ??
                                    'Calendar'),
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
                            centerTitle: false,
                            trailing: _editingMessageId != null || !_currentItem.isEditable
                                ? const SizedBox.shrink()
                                : GestureDetector(
                                    onTap: () async {
                                      final provider = context
                                          .read<CalendarProvider>();
                                      final result = await showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        enableDrag: false,
                                        backgroundColor: Colors.transparent,
                                        barrierColor: const Color(0xB2000000),
                                        builder: (ctx) =>
                                            ChangeNotifierProvider.value(
                                              value: provider,
                                              child: BackdropFilter(
                                                filter: ImageFilter.blur(
                                                  sigmaX: 4,
                                                  sigmaY: 4,
                                                ),
                                                child: NewEventBottomSheet(
                                                  eventToEdit: _currentItem,
                                                ),
                                              ),
                                            ),
                                      );
                                      if (result == true && mounted) {
                                        final dateStr =
                                            _currentItem.startDate.isNotEmpty
                                            ? _currentItem.startDate
                                            : (provider
                                                      .selectedDaySchedule
                                                      ?.date ??
                                                  '');
                                        if (dateStr.isNotEmpty) {
                                          await provider.fetchCalendarDay(
                                            date: dateStr,
                                          );
                                        }
                                        final matchingItem = provider
                                            .selectedDaySchedule
                                            ?.items
                                            .where(
                                              (it) =>
                                                  it.id == _currentItem.id ||
                                                  (it.iid.isNotEmpty &&
                                                      it.iid ==
                                                          _currentItem.iid),
                                            )
                                            .firstOrNull;
                                        if (matchingItem != null && mounted) {
                                          setState(() {
                                            _currentItem = matchingItem;
                                          });
                                        }
                                      }
                                    },
                                    child: CustomPaint(
                                      painter: GradientCirclePainter(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: isDark
                                              ? [
                                                  Colors.white.withValues(
                                                    alpha: 0.3,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: 0.0,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: 0.3,
                                                  ),
                                                ]
                                              : [
                                                  Colors.white,
                                                  Colors.white.withValues(
                                                    alpha: 0.0,
                                                  ),
                                                  Colors.white,
                                                ],
                                          stops: const [0.0, 0.5, 1.0],
                                        ),
                                        strokeWidth: 1.5.w,
                                      ),
                                      child: Container(
                                        width: 41.27.w,
                                        height: 41.27.w,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isDark
                                              ? const Color(
                                                  0xFF5E340E,
                                                ).withValues(alpha: 0.2)
                                              : Colors.white.withValues(
                                                  alpha: 0.5,
                                                ),
                                        ),
                                        child: Center(
                                          child: SvgPicture.asset(
                                            AppAssets.squarePen,
                                            width: 18.w,
                                            height: 18.w,
                                            colorFilter: ColorFilter.mode(
                                              isDark
                                                  ? AppColors.white
                                                  : AppColors.secondary,
                                              BlendMode.srcIn,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),

                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _editingMessageId != null ? 0.3 : 1.0,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                16.w,
                                10.h,
                                16.w,
                                10.h,
                              ),
                              child: ScheduleLogSummaryCardWidget(
                              title: _currentItem.title,
                              startTime: _currentItem.startDate,
                              endTime: _currentItem.endDate,
                              description: _currentItem.subtitle,
                              allDay: _currentItem.allDay,
                              timeDisplay: _currentItem.timeDisplay,
                              isCompact: isKeyboardOpen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                  // Scrollable Chat Messages Area
                  Expanded(
                    child: Consumer<CalendarProvider>(
                      builder: (context, provider, child) {
                        if (provider.isLoadingLogs) {
                          return const AppChatMessageListShimmer();
                        }

                        final logs = provider.getLogsForCalendarItem(
                          _getParsedId(),
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

                        final logError = provider.getLogErrorForCalendarItem(_getParsedId());

                        return AppChatMessageListWidget(
                          messages: messages,
                          controller: _scrollController,
                          errorMessage: logError,
                          editingMessageId: _editingMessageId,
                          onDelete: (item) async {
                            final log = logs.firstWhere(
                              (l) => l.message == item.message || l.id == item.id,
                              orElse: () => LogNoteModel(id: '', expenseId: _getParsedId()),
                            );
                            final logId = log.id;
                            if (logId != null && logId.isNotEmpty) {
                              final msgIdInt = int.tryParse(logId);
                              if (msgIdInt != null) {
                                final success = await provider.deleteLogNote(_getParsedId(), msgIdInt);
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
                              orElse: () => LogNoteModel(id: '', expenseId: _getParsedId()),
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

                  // Bottom Message Input Bar (Frame 2609824)
                  Consumer<CalendarProvider>(
                    builder: (context, provider, child) {
                      final logError = provider.getLogErrorForCalendarItem(_getParsedId());
                      final hasError = logError != null && logError.trim().isNotEmpty;
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
