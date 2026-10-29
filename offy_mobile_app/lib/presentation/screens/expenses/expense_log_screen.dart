import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:office_app/data/models/log_note_model.dart';
import 'package:office_app/domain/entities/attachment_entity.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/chat_message_entity.dart';
import '../../viewmodels/expenses/expenses_provider.dart';
import '../../widgets/common/chat/app_chat_input_bar_widget.dart';
import '../../widgets/common/chat/app_chat_message_list_widget.dart';
import '../../widgets/common/custom_screen_header.dart';
import '../../widgets/common/gradient_circle_painter.dart';
import '../../widgets/expenses/expense_summary_card_widget.dart';
import '../../widgets/expenses/expense_summary_card_shimmer.dart';
import '../../widgets/common/chat/app_chat_message_list_shimmer.dart';
import '../../../../l10n/app_localizations.dart';
import 'submit_expense_page.dart';

class ExpenseLogsScreen extends StatefulWidget {
  final int expenseId;

  const ExpenseLogsScreen({super.key, required this.expenseId});

  @override
  State<ExpenseLogsScreen> createState() => _ExpenseLogsScreenState();
}

class _ExpenseLogsScreenState extends State<ExpenseLogsScreen> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  String? _editingMessageId;
  List<AttachmentEntity> _editingAttachments = [];
  List<String> _editingMentionNames = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ExpensesProvider>().fetchExpenseLogs(widget.expenseId);
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
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

  void _unfocusKeyboard() {
    _focusNode.unfocus();
    FocusScope.of(context).unfocus();
  }

  Future<void> _sendMessage(
    String text,
    List<XFile> files,
    List<String> mentionNames,
    String bodyPartsJson,
  ) async {
    final provider = context.read<ExpensesProvider>();
    if (provider.isAddingLogNote || provider.isSubmittingLogNote) return;

    bool success = false;
    final wasEditing = _editingMessageId != null;

    if (wasEditing) {
      final msgIdInt = int.tryParse(_editingMessageId!);
      if (msgIdInt != null) {
        List<int> existingAttachmentIds = _editingAttachments
            .where((a) => a.id != null)
            .map((a) => int.tryParse(a.id.toString()) ?? 0)
            .where((id) => id > 0)
            .toList();

        if (text.trim().isEmpty &&
            files.isEmpty &&
            existingAttachmentIds.isEmpty) {
          return;
        }

        success = await provider.editLogNote(
          msgIdInt,
          text,
          widget.expenseId,
          files: files,
          mentionNames: mentionNames,
          bodyPartsJson: bodyPartsJson,
          existingAttachments: existingAttachmentIds,
        );
      }
    } else {
      if (text.trim().isEmpty && files.isEmpty) return;
      success = await provider.addLogNote(
        widget.expenseId,
        text,
        files: files,
        mentionNames: mentionNames,
        bodyPartsJson: bodyPartsJson,
      );
    }

    if (success) {
      setState(() {
        _editingMessageId = null;
        _editingAttachments = [];
        _editingMentionNames = [];
      });
      _inputController.clear();
      _unfocusKeyboard();
      if (!wasEditing) {
        _scrollToBottom();
      }
    }
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<ExpensesProvider>();
    final expenseDetail = provider.getExpenseDetail(widget.expenseId);
    final logs = provider.getLogsForExpense(widget.expenseId);

    final chatItems = logs
        .map(
          (log) => ChatMessageEntity(
            id: log.id,
            avatarUrl: log.avatarUrl ?? '',
            message: log.message ?? '',
            timestamp: (log.timeDisplay != null && log.timeDisplay!.isNotEmpty)
                ? log.timeDisplay!
                : (log.timestamp != null ? _formatTime(log.timestamp!) : ''),
            date: log.timestamp ?? DateTime.now(),
            isOutgoing: log.isUser ?? true,
            userName: log.senderName ?? '',
            attachments: log.attachments ?? const [],
            mentionNames: log.mentionNames ?? const [],
            bodyParts: log.bodyParts,
            isEditable: log.isEditable ?? false,
            isDeletable: log.isDeletable ?? false,
          ),
        )
        .toList();

    final scaffoldBgColor = isDark ? AppColors.darkBg : AppColors.white;

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
            _inputController.clear();
            _unfocusKeyboard();
          }
        },
        child: Scaffold(
        backgroundColor: scaffoldBgColor,
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
                          CustomScreenHeader(
                            onBackTap: () {
                              if (_editingMessageId != null) {
                                setState(() {
                                  _editingMessageId = null;
                                  _editingAttachments = [];
                                  _editingMentionNames = [];
                                });
                                _inputController.clear();
                                _unfocusKeyboard();
                              } else {
                                Navigator.pop(context);
                              }
                            },
                            centerTitle: false,
                            title: _editingMessageId != null
                                ? 'Edit message'
                                : (AppLocalizations.of(context)?.myExpenses ??
                                    'My Expenses'),
                            trailing: _editingMessageId != null || !((expenseDetail?.isDraft ?? false) || (expenseDetail?.isPending ?? false))
                                ? const SizedBox.shrink()
                                : GestureDetector(
                                    onTap: () async {
                                      final provider = context
                                          .read<ExpensesProvider>();
                                      final currentDetail = provider
                                          .getExpenseDetail(widget.expenseId);
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              SubmitExpensePage(
                                                expenseToEdit: currentDetail,
                                              ),
                                        ),
                                      );
                                      if (!context.mounted) return;
                                      if (result == 'deleted') {
                                        Navigator.pop(context, true);
                                      } else if (result == true) {
                                        await provider.fetchExpenseLogs(
                                          widget.expenseId,
                                        );
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
                              child: expenseDetail != null
                                ? ExpenseSummaryCardWidget(
                                    icon: expenseDetail.iconData,
                                    category: expenseDetail.category,
                                    title: expenseDetail.title,
                                    date: expenseDetail.date,
                                    status:
                                        expenseDetail.statusDisplay.isNotEmpty
                                        ? expenseDetail.statusDisplay
                                        : expenseDetail.status,
                                    isCompact: isKeyboardOpen,
                                    hasReceipt: expenseDetail.hasReceipt,
                                    documents: expenseDetail.attachments,
                                    amountDisplay: expenseDetail.amountDisplay,
                                    paymentStatus:
                                        expenseDetail.paymentStatusDisplay ??
                                        expenseDetail.paymentStatus,
                                    breakdownItems:
                                        expenseDetail.breakdownItems,
                                    isPartiallyPaid:
                                        expenseDetail.isPartiallyPaid,
                                    amountPaidDisplay:
                                        expenseDetail.amountPaidDisplay,
                                  )
                                : ExpenseSummaryCardShimmer(
                                    isCompact: isKeyboardOpen,
                                  ),
                          ),
                      )],
                      ),
                    ],
                  ),

                  // Scrollable Chat Logs List
                  Expanded(
                    child: provider.isLoadingLogs
                        ? const AppChatMessageListShimmer()
                        : AppChatMessageListWidget(
                            messages: chatItems,
                            controller: _scrollController,
                            emptyMessage:
                                AppLocalizations.of(context)?.noLogNotesYet ??
                                'No log notes yet.',
                            errorMessage: provider.getLogErrorForExpense(
                              widget.expenseId,
                            ),
                            editingMessageId: _editingMessageId,
                            onEdit: (item) {
                              final log = logs.firstWhere(
                                (l) =>
                                    l.message == item.message ||
                                    l.id == item.id,
                                orElse: () => LogNoteModel(
                                  id: '',
                                  expenseId: widget.expenseId,
                                ),
                              );
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
                            },
                            onDelete: (item) async {
                              final log = logs.firstWhere(
                                (l) =>
                                    l.message == item.message ||
                                    l.id == item.id,
                                orElse: () => LogNoteModel(
                                  id: '',
                                  expenseId: widget.expenseId,
                                ),
                              );
                              final logId = log.id;
                              if (logId != null && logId.isNotEmpty) {
                                final msgIdInt = int.tryParse(logId);
                                if (msgIdInt != null) {
                                  final success = await provider.deleteLogNote(
                                    widget.expenseId,
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
                          ),
                  ),

                  // Sticky Chat Input Bar (Frame 2609824)
                  if (provider.getLogErrorForExpense(widget.expenseId) ==
                          null ||
                      provider
                          .getLogErrorForExpense(widget.expenseId)!
                          .trim()
                          .isEmpty)
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
              );
            },
          ),
        ),
      ),
      ),
    );
  }
}
