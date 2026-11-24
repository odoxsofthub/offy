import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';

class ExpenseChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool isEditing;
  final VoidCallback? onCancelEdit;

  const ExpenseChatInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    this.isEditing = false,
    this.onCancelEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final containerBg = isDark ? AppColors.darkTopCard : AppColors.midLight;
    final inputBg = isDark
        ? const Color.fromRGBO(246, 243, 242, 0.1)
        : const Color(0xFFF6F3F2);

    final inputBorderColor = isDark
        ? const Color.fromRGBO(209, 199, 176, 0.1)
        : const Color(0xFFD1C7B0);

    return Container(
      padding: EdgeInsets.fromLTRB(
        12.w,
        8.h,
        12.w,
        MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom
            : 12.h,
      ),
      decoration: BoxDecoration(
        color: containerBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Edit Banner indicator if editing an existing log note
          if (isEditing) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              margin: EdgeInsets.only(bottom: 8.h),
              decoration: BoxDecoration(
                color: AppColors.main.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 18.w,
                    color: AppColors.main,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)?.editingLogNote ?? 'Editing Log Note',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.main,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onCancelEdit,
                    borderRadius: BorderRadius.circular(20.r),
                    child: Padding(
                      padding: EdgeInsets.all(8.r),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18.w,
                        color: AppColors.main,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Sticky Chat Text Field
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(22.r),
                    border: Border.all(
                      color: focusNode.hasFocus
                          ? AppColors.main
                          : inputBorderColor,
                      width: 1.0,
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 4,
                    cursorColor: AppColors.main,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w400,
                      color: isDark ? AppColors.white : AppColors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: isEditing
                          ? 'Update log note...'
                          : 'Add a log note...',
                      hintStyle: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w400,
                        color: isDark
                            ? const Color(0xFFA49D95)
                            : const Color(0xFF6B7280),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8.h),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),

              // WhatsApp-style Circular Send Button
              Material(
                color: AppColors.main,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onSend,
                  child: Container(
                    width: 44.w,
                    height: 44.w,
                    alignment: Alignment.center,
                    child: Icon(
                      isEditing ? Icons.check_rounded : Icons.send_rounded,
                      color: Colors.white,
                      size: 20.w,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
