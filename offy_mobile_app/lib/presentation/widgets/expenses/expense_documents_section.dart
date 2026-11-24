import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/attachment_entity.dart';
import '../common/chat/app_document_badge_chip.dart';
import '../common/chat/app_document_launcher.dart';

/// Standalone section widget to display document attachment badge chips for expenses (Frame 2609865)
class ExpenseDocumentsSection extends StatelessWidget {
  final List<dynamic> documents;

  const ExpenseDocumentsSection({
    super.key,
    required this.documents,
  });

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<AttachmentEntity> attachmentEntities = documents.map((doc) {
      if (doc is AttachmentEntity) {
        return doc;
      }
      return AttachmentEntity(url: doc.toString());
    }).toList();

    final List<Widget> chips = [];
    for (int i = 0; i < attachmentEntities.length; i++) {
      final attachment = attachmentEntities[i];
      final isPdf = attachment.isPdf;
      final isImg = attachment.isImage;
      final isJson = attachment.isJson;
      final isCsv = attachment.isCsv;
      final isTxt = attachment.isText;
      final previewUrl = attachment.displayUrl;
      final fullPath = attachment.url;

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

      final isLocal = previewUrl.isNotEmpty && File(previewUrl).existsSync();
      chips.add(
        AppDocumentBadgeChip(
          label: badgeLabel,
          badgeColor: badgeColor,
          imageUrl: !isLocal ? previewUrl : null,
          imagePath: isLocal ? previewUrl : null,
          onTap: () {
            AppDocumentLauncher.open(
              context,
              path: fullPath,
              allAttachments: attachmentEntities,
              name: attachment.fileName,
              kind: attachment.kind,
            );
          },
        ),
      );
      if (i < attachmentEntities.length - 1) {
        chips.add(SizedBox(width: 8.w));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Documents',
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w400,
            height: 18 / 10,
            color: isDark ? AppColors.light : AppColors.navColor,
          ),
        ),
        SizedBox(height: 6.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: chips,
          ),
        ),
        SizedBox(height: 10.h),
      ],
    );
  }
}
