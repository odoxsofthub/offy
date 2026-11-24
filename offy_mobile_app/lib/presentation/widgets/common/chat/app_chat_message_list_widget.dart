import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/chat_message_entity.dart';
import 'app_chat_bubble_widget.dart';
import 'app_chat_date_divider.dart';

class AppChatMessageListWidget extends StatefulWidget {
  final List<ChatMessageEntity> messages;
  final ScrollController? controller;
  final String emptyMessage;
  final String? errorMessage;
  final Color? backgroundColor;
  final String? editingMessageId;

  final Function(ChatMessageEntity)? onDelete;
  final Function(ChatMessageEntity)? onEdit;

  const AppChatMessageListWidget({
    super.key,
    required this.messages,
    this.controller,
    this.emptyMessage = 'No messages yet.',
    this.errorMessage,
    this.backgroundColor,
    this.editingMessageId,
    this.onDelete,
    this.onEdit,
  });

  @override
  State<AppChatMessageListWidget> createState() =>
      _AppChatMessageListWidgetState();
}

class _AppChatMessageListWidgetState extends State<AppChatMessageListWidget> {
  String? _activeActionItemId;

  bool _isSameDay(DateTime dt1, DateTime dt2) {
    return dt1.year == dt2.year && dt1.month == dt2.month && dt1.day == dt2.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBgColor =
        widget.backgroundColor ?? (isDark ? AppColors.darkBg : AppColors.white);
    final isEditingAny = widget.editingMessageId != null;
    final bgColor = isEditingAny
        ? Color.alphaBlend(Colors.black.withValues(alpha: 0.6), baseBgColor)
        : baseBgColor;

    final hasError =
        widget.errorMessage != null && widget.errorMessage!.trim().isNotEmpty;
    final visibleMessages = widget.messages
        .where((item) => item.hasContent)
        .toList();

    void hideActions() {
      if (_activeActionItemId != null) {
        setState(() {
          _activeActionItemId = null;
        });
      }
    }

    return GestureDetector(
      onTap: hideActions,
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          if (scrollNotification is ScrollUpdateNotification) {
            hideActions();
          }
          return false;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(color: bgColor),
          child: hasError
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Text(
                      widget.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: isDark
                            ? const Color(0xFFA49D95)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                )
              : visibleMessages.isEmpty
              ? Center(
                  child: Text(
                    widget.emptyMessage,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: isDark
                          ? const Color(0xFFA49D95)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  controller: widget.controller,
                  padding: EdgeInsets.symmetric(
                    vertical: 12.h,
                    horizontal: 16.w,
                  ),
                  itemCount: visibleMessages.length,
                  itemBuilder: (context, index) {
                    // reverse: true builds from bottom up. Index 0 is visually at bottom.
                    final item = visibleMessages[index];

                    // Show date header if this is the oldest message (last item in list)
                    // or if its date differs from the NEXT (older) item's date.
                    final showDateHeader =
                        index == visibleMessages.length - 1 ||
                        !_isSameDay(item.date, visibleMessages[index + 1].date);

                    final bubbleWidget = Padding(
                      padding: EdgeInsets.only(bottom: 15.h),
                      child: _ChatBubbleWithActions(
                        item: item,
                        isEditing:
                            widget.editingMessageId != null &&
                            widget.editingMessageId == item.id,
                        onDelete: widget.onDelete,
                        onEdit: widget.onEdit,
                        showActions: _activeActionItemId == item.id,
                        onToggleActions: () {
                          setState(() {
                            if (_activeActionItemId == item.id) {
                              _activeActionItemId = null;
                            } else {
                              _activeActionItemId = item.id;
                            }
                          });
                        },
                        onHideActions: hideActions,
                      ),
                    );

                    Widget finalBubble = bubbleWidget;

                    if (showDateHeader) {
                      finalBubble = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(bottom: 15.h),
                            child: AppChatDateDivider(date: item.date),
                          ),
                          bubbleWidget,
                        ],
                      );
                    }

                    final isThisEdited = widget.editingMessageId == item.id;

                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isEditingAny && !isThisEdited ? 0.3 : 1.0,
                      child: finalBubble,
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _ChatBubbleWithActions extends StatelessWidget {
  final ChatMessageEntity item;
  final bool isEditing;
  final Function(ChatMessageEntity)? onDelete;
  final Function(ChatMessageEntity)? onEdit;
  final bool showActions;
  final VoidCallback onToggleActions;
  final VoidCallback onHideActions;

  const _ChatBubbleWithActions({
    required this.item,
    this.isEditing = false,
    this.onDelete,
    this.onEdit,
    required this.showActions,
    required this.onToggleActions,
    required this.onHideActions,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleWidget = AppChatBubbleWidget(
      message: item.message,
      timestamp: item.timestamp,
      isOutgoing: item.isOutgoing,
      userName: item.userName,
      avatarUrl: item.avatarUrl,
      attachments: item.attachments,
      mentionableMemberNames: item.mentionNames.isNotEmpty
          ? item.mentionNames
          : null,
      bodyParts: item.bodyParts,
      isEditing: isEditing,
      actionWidget: showActions ? _buildActions(context) : null,
    );

    final canEdit = onEdit != null && item.isEditable;
    final canDelete = onDelete != null && item.isDeletable;

    if (!canEdit && !canDelete) {
      return bubbleWidget;
    }

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.vibrate();
        onToggleActions();
      },
      child: Container(
        color: Colors.transparent,
        child: bubbleWidget,
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deleteBgColor = isDark
        ? const Color(0xFF3B1D1D)
        : const Color(0xFFFFEBEB);
    final deleteIconColor = isDark
        ? const Color(0xFFFF6B6B)
        : const Color(0xFFFF4D4F);
    final editBgColor = isDark ? AppColors.darkCard : const Color(0xFFF4F0F7);
    final editIconColor = isDark ? AppColors.white : const Color(0xFFA05F41);

    return Padding(
      padding: EdgeInsets.only(
        right: item.isOutgoing ? 12.w : 0,
        left: !item.isOutgoing ? 12.w : 0,
        // top: 10.h,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          if (onDelete != null && item.isDeletable)
            GestureDetector(
              onTap: () {
                onHideActions();
                onDelete!(item);
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.all(4.r),
                child: Container(
                  width: 36.r,
                  height: 36.r,
                  decoration: BoxDecoration(
                    color: deleteBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: deleteIconColor,
                    size: 18.r,
                  ),
                ),
              ),
            ),
          if ((onDelete != null && item.isDeletable) &&
              (onEdit != null && item.isEditable))
            SizedBox(width: 4.w),
          if (onEdit != null && item.isEditable)
            GestureDetector(
              onTap: () {
                onHideActions();
                onEdit!(item);
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.all(4.r),
                child: Container(
                  width: 36.r,
                  height: 36.r,
                  decoration: BoxDecoration(
                    color: editBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    color: editIconColor,
                    size: 18.r,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
