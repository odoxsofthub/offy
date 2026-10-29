import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';

class CustomSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClearTap;
  final VoidCallback? onFilterTap;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool enabled;
  final bool isSearching;
  final bool isFiltering;
  final bool hasActiveFilters;
  final String? hintText;

  const CustomSearchBar({
    super.key,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onClearTap,
    this.onFilterTap,
    this.onTap,
    this.readOnly = false,
    this.enabled = true,
    this.isSearching = false,
    this.isFiltering = false,
    this.hasActiveFilters = false,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveHint =
        hintText ?? AppLocalizations.of(context)?.search ?? 'Search';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : Colors.black;
    final dividerColor = isDark ? Colors.white : Colors.black;
    final isFilterClickable = onFilterTap != null && !isSearching;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.searchPill,
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 27.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    child: AnimatedOpacity(
                      opacity: isFiltering ? 0.5 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 18.sp,
                            color: primaryColor,
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: TextField(
                              controller: controller,
                              focusNode: focusNode,
                              onChanged: onChanged,
                              onSubmitted: (val) {
                                focusNode?.unfocus();
                                FocusManager.instance.primaryFocus?.unfocus();
                                FocusScope.of(context).unfocus();
                                onSubmitted?.call(val);
                              },
                              onTap: isFiltering ? null : onTap,
                              onTapOutside: (_) {
                                focusNode?.unfocus();
                                FocusManager.instance.primaryFocus?.unfocus();
                                FocusScope.of(context).unfocus();
                              },
                              textInputAction: TextInputAction.search,
                              cursorHeight: 18.sp,
                              textAlignVertical: TextAlignVertical.center,
                              readOnly: readOnly || isFiltering,
                              enabled: enabled && !isFiltering,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400,
                                color: primaryColor,
                                height: 32 / 14,
                              ),
                              decoration: InputDecoration(
                                hintText: effectiveHint,
                                hintStyle: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w400,
                                  color: primaryColor,
                                  height: 32 / 14,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (controller != null)
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: controller!,
                              builder: (context, value, _) {
                                if (value.text.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return GestureDetector(
                                  onTap: onClearTap,
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4.w,
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 18.sp,
                                      color: primaryColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 0.5.w,
                      height: 22.5.h,
                      color: dividerColor,
                    ),
                    AnimatedOpacity(
                      opacity: isSearching ? 0.38 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: GestureDetector(
                        onTap: isFilterClickable ? onFilterTap : null,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: EdgeInsets.fromLTRB(15.w, 10.h, 12.w, 10.h),
                          color: Colors.transparent,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              SizedBox(
                                width: 22.sp,
                                height: 22.sp,
                                child: Center(
                                  child: Icon(
                                    Icons.tune_rounded,
                                    size: 22.sp,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                              if (hasActiveFilters)
                                Positioned(
                                  top: -1.75.h,
                                  right: 3.w,
                                  child: Container(
                                    width: 10.w,
                                    height: 10.w,
                                    decoration: BoxDecoration(
                                      color: AppColors.main,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.white,
                                        width: 1.w,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isSearching || isFiltering)
            Positioned(
              bottom: 0,
              left: 24.w,
              right: 24.w,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2.r),
                child: const LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.main,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
