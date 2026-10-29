import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/attachment_entity.dart';
import '../../../../data/models/log_note_model.dart';
import '../cached_image.dart';
import 'app_chat_mention_text_editing_controller.dart';
import 'app_document_launcher.dart';

class AppChatBubbleWidget extends StatelessWidget {
  final String message;
  final String timestamp;
  final bool isOutgoing;
  final String userName;
  final String avatarUrl;
  final List<AttachmentEntity> attachments;
  final List<String>? mentionableMemberNames;
  final List<LogNoteBodyPart>? bodyParts;
  final bool isEditing;
  final Widget? actionWidget;

  const AppChatBubbleWidget({
    super.key,
    required this.message,
    required this.timestamp,
    required this.isOutgoing,
    this.userName = '',
    this.avatarUrl = '',
    this.attachments = const [],
    this.mentionableMemberNames,
    this.bodyParts,
    this.isEditing = false,
    this.actionWidget,
  });

  Widget _buildAttachmentBadge(
    BuildContext context,
    AttachmentEntity attachment,
    int index, {
    required bool isLarge,
  }) {
    final isPdf = attachment.isPdf;
    final isImg = attachment.isImage;
    final isJson = attachment.isJson;
    final isCsv = attachment.isCsv;
    final isTxt = attachment.isText;
    final path = attachment.url;

    final double width = isLarge ? 126.w : 87.w;
    final double height = isLarge ? 42.h : 29.h;
    final double badgeWidth = isLarge ? 52.14.w : 36.w;
    final double borderRadius = isLarge ? 10.14.r : 7.r;
    final double fontSize = isLarge ? 17.38.sp : 12.sp;

    final String badgeLabel = isPdf
        ? 'PDF'
        : (isImg
              ? 'IMG'
              : (isJson
                    ? 'JSON'
                    : (isCsv
                          ? 'CSV'
                          : (isTxt
                                ? 'TXT'
                                : (attachment.fileExtension.length <= 4
                                      ? attachment.fileExtension
                                      : 'FILE')))));

    final Color badgeColor = isPdf
        ? const Color(0xFFFF383C)
        : (isImg
              ? const Color(0xFF00C8B3)
              : (isJson
                    ? const Color(0xFFFF9800)
                    : (isCsv
                          ? const Color(0xFF4CAF50)
                          : (isTxt
                                ? const Color(0xFF2196F3)
                                : const Color(0xFFFF5722)))));

    final isLocal = File(path).existsSync();
    final resolvedUrl =
        (path.startsWith('/') && !path.startsWith('//') && !isLocal)
        ? '${ApiConstants.baseUrl}$path'
        : path;
    final isUrl = resolvedUrl.startsWith('http');

    Widget bgWidget;
    if (isImg) {
      if (isLocal) {
        bgWidget = Image.file(
          File(path),
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              CachedImage.buildBrokenImageFallback(
            context,
            width: width,
            height: height,
          ),
        );
      } else if (isUrl) {
        bgWidget = CachedImage(
          imageUrl: resolvedUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
        );
      } else {
        bgWidget = CachedImage.buildBrokenImageFallback(
          context,
          width: width,
          height: height,
        );
      }
    } else {
      final IconData iconData = isPdf
          ? Icons.picture_as_pdf_rounded
          : (isJson
                ? Icons.data_object_rounded
                : (isCsv
                      ? Icons.table_chart_rounded
                      : (isTxt
                            ? Icons.description_rounded
                            : Icons.insert_drive_file_rounded)));
      bgWidget = Container(
        width: width,
        height: height,
        color: const Color(0xFFD9D9D9),
        child: Icon(iconData, color: Colors.white, size: isLarge ? 30.r : 20.r),
      );
    }

    return GestureDetector(
      onTap: () {
        AppDocumentLauncher.open(
          context,
          path: path,
          allAttachments: attachments,
          name: attachment.fileName,
          kind: attachment.kind,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(child: bgWidget),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: badgeWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w400,
                      height: 1.0,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentsWidget(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    final isSingle = attachments.length == 1;
    final hasContent =
        message.isNotEmpty || (bodyParts != null && bodyParts!.isNotEmpty);

    return Padding(
      padding: EdgeInsets.only(top: hasContent ? 8.h : 0),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: List.generate(attachments.length, (index) {
          return _buildAttachmentBadge(
            context,
            attachments[index],
            index,
            isLarge: isSingle,
          );
        }),
      ),
    );
  }

  Widget _buildMessageContent({
    required TextStyle defaultStyle,
    required TextStyle mentionStyle,
  }) {
    if (bodyParts != null && bodyParts!.isNotEmpty) {
      final spans = <InlineSpan>[];
      for (final part in bodyParts!) {
        if (part.isMention) {
          spans.add(TextSpan(text: part.text, style: mentionStyle));
        } else {
          spans.add(TextSpan(text: part.text, style: defaultStyle));
        }
      }
      return Text.rich(TextSpan(children: spans));
    } else if (message.isNotEmpty) {
      return Text.rich(
        AppChatMentionTextEditingController.buildMentionTextSpan(
          text: message,
          defaultStyle: defaultStyle,
          mentionStyle: mentionStyle,
          memberNames: mentionableMemberNames ?? const [],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final hasMessage =
        message.trim().isNotEmpty ||
        (bodyParts != null && bodyParts!.any((p) => p.text.trim().isNotEmpty));
    final hasDocuments = attachments.isNotEmpty;
    if (!hasMessage && !hasDocuments) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultStyle = TextStyle(
      fontSize: 14.sp,
      fontWeight: FontWeight.w500,
      height: 20 / 14,
      color: isDark ? AppColors.white : const Color(0xFF252525),
    );

    final mentionStyle = TextStyle(
      fontSize: 14.sp,
      fontWeight: FontWeight.w600,
      height: 20 / 14,
      color: AppColors.secondary,
    );

    // If align is own (isOutgoing == true): no name or image is shown.
    if (isOutgoing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ?actionWidget,
              Flexible(
                child: Container(
                  padding: EdgeInsets.all(10.r),
                  constraints: BoxConstraints(minWidth: 146.w, maxWidth: 275.w),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(10.r),
                    boxShadow: isEditing
                        ? [
                            BoxShadow(
                              color: const Color(0x26000000),
                              offset: const Offset(0, 4),
                              blurRadius: 4,
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMessageContent(
                        defaultStyle: defaultStyle,
                        mentionStyle: mentionStyle,
                      ),
                      _buildAttachmentsWidget(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Padding(
            padding: EdgeInsets.only(right: 10.w),
            child: Text(
              timestamp,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                height: 20 / 12,
                color: AppColors.darkNav,
              ),
            ),
          ),
        ],
      );
    }

    // If align is not own (isOutgoing == false): shows both avatar image and user name.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Container(
          constraints: BoxConstraints(minWidth: 198.w, maxWidth: 275.w),
          padding: EdgeInsets.all(10.r),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkTertiary : const Color(0xFFF6FFE2),
            borderRadius: BorderRadius.circular(10.r),
            boxShadow: isEditing
                ? [
                    BoxShadow(
                      color: const Color(0x26000000),
                      offset: const Offset(0, 4),
                      blurRadius: 4,
                    )
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (avatarUrl.isNotEmpty)
                    ClipOval(
                      child: CachedImage(
                        imageUrl: avatarUrl,
                        userName: userName,
                        isProfile: true,
                        width: 20.r,
                        height: 20.r,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      width: 20.r,
                      height: 20.r,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD9D9D9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        size: 14.r,
                        color: Colors.white,
                      ),
                    ),
                  SizedBox(width: 10.w),
                  Text(
                    userName.isNotEmpty ? userName : 'User',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      height: 20 / 14,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              _buildMessageContent(
                defaultStyle: defaultStyle,
                mentionStyle: mentionStyle,
              ),
              _buildAttachmentsWidget(context),
            ],
          ),
        ),
        ),
        ?actionWidget,
      ],
    ),
    SizedBox(height: 4.h),
    Padding(
      padding: EdgeInsets.only(left: 10.w),
      child: Text(
        timestamp,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w400,
          height: 20 / 12,
          color: AppColors.darkNav,
        ),
      ),
    ),
  ],
);
  }
}
