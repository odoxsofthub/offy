import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/filter_model.dart';

class AppFilterPresetChips extends StatefulWidget {
  final String selectedPreset;
  final ValueChanged<String> onPresetSelected;
  final bool isDisabled;
  final List<String> presets;
  final List<FilterBucketModel>? buckets;
  final Set<String>? bucketsWithSelection;

  const AppFilterPresetChips({
    super.key,
    required this.selectedPreset,
    required this.onPresetSelected,
    this.isDisabled = false,
    this.presets = const ['Recent', '2025', '2026'],
    this.buckets,
    this.bucketsWithSelection,
  });

  @override
  State<AppFilterPresetChips> createState() => _AppFilterPresetChipsState();
}

class _AppFilterPresetChipsState extends State<AppFilterPresetChips> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};
  bool _hasScrolled = false;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedBucket();
    });
  }

  @override
  void didUpdateWidget(covariant AppFilterPresetChips oldWidget) {
    super.didUpdateWidget(oldWidget);

    final hadBuckets =
        oldWidget.buckets != null && oldWidget.buckets!.isNotEmpty;
    final hasBuckets =
        widget.buckets != null && widget.buckets!.isNotEmpty;
    final presetChanged = oldWidget.selectedPreset.trim().toLowerCase() !=
        widget.selectedPreset.trim().toLowerCase();
    final bucketsWithSelectionChanged =
        oldWidget.bucketsWithSelection != widget.bucketsWithSelection;

    if ((!hadBuckets && hasBuckets) ||
        (oldWidget.isDisabled && !widget.isDisabled) ||
        presetChanged ||
        bucketsWithSelectionChanged ||
        !_hasScrolled) {
      _hasScrolled = false;
      _retryCount = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedBucket();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedBucket() {
    if (!mounted) return;

    // No selection in any bucket: don't auto-scroll; keep the first chip visible.
    final hasAnySelection =
        widget.bucketsWithSelection != null &&
        widget.bucketsWithSelection!.isNotEmpty;
    if (!hasAnySelection) {
      _hasScrolled = true;
      return;
    }

    final targetKey = widget.selectedPreset.trim().toLowerCase();
    final key = _itemKeys[targetKey];
    final targetContext = key?.currentContext;

    if (targetContext != null && targetContext.mounted) {
      final renderObject = targetContext.findRenderObject();
      if (renderObject is RenderBox &&
          renderObject.hasSize &&
          renderObject.attached) {
        _hasScrolled = true;
        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
        return;
      }
    }

    if (!_hasScrolled && _retryCount < 5) {
      _retryCount++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedBucket();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasBuckets = widget.buckets != null && widget.buckets!.isNotEmpty;
    final count = hasBuckets ? widget.buckets!.length : widget.presets.length;

    if (count == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppColors.darkNav.withValues(alpha: 0.3)
                : const Color(0xFFE7E0D8).withValues(alpha: 0.5),
            width: 1.03.w,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.49.w, vertical: 14.43.h),
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(count, (index) {
            final key = hasBuckets
                ? widget.buckets![index].key.trim().toLowerCase()
                : widget.presets[index].trim().toLowerCase();
            final label = hasBuckets
                ? widget.buckets![index].label
                : widget.presets[index];

            final isSelected =
                widget.selectedPreset.trim().toLowerCase() == key;
            final hasSelection = widget.bucketsWithSelection != null &&
                widget.bucketsWithSelection!.contains(key);
            final isLast = index == count - 1;

            return Padding(
              key: _itemKeys.putIfAbsent(key, () => GlobalKey()),
              padding: EdgeInsets.only(right: isLast ? 0 : 17.52.w),
              child: InkWell(
                onTap: widget.isDisabled
                    ? null
                    : () => widget.onPresetSelected(
                          hasBuckets ? key : widget.presets[index],
                        ),
                borderRadius: BorderRadius.circular(100.r),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (widget.isDisabled
                            ? AppColors.main.withValues(alpha: 0.35)
                            : AppColors.main)
                        : (widget.isDisabled
                            ? (isDark
                                ? AppColors.darkTertiary.withValues(alpha: 0.4)
                                : AppColors.light.withValues(alpha: 0.4))
                            : (isDark
                                ? AppColors.darkTertiary
                                : AppColors.light)),
                    borderRadius: BorderRadius.circular(100.r),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: isDark
                                ? AppColors.darkNav.withValues(alpha: 0.4)
                                : const Color(0xFFE7E0D8),
                            width: 1.03.w,
                          ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13.39.sp,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          height: 18 / 13.39,
                          color: isSelected
                              ? (widget.isDisabled
                                  ? AppColors.white.withValues(alpha: 0.6)
                                  : AppColors.white)
                              : (widget.isDisabled
                                  ? (isDark
                                      ? AppColors.white.withValues(alpha: 0.25)
                                      : const Color(0xFF75706B)
                                          .withValues(alpha: 0.4))
                                  : (isDark
                                      ? AppColors.white.withValues(alpha: 0.8)
                                      : const Color(0xFF43403D))),
                        ),
                      ),
                      if (hasSelection) ...[
                        SizedBox(width: 5.w),
                        Container(
                          width: 6.w,
                          height: 6.w,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (widget.isDisabled
                                    ? AppColors.white.withValues(alpha: 0.6)
                                    : AppColors.white)
                                : (widget.isDisabled
                                    ? AppColors.main.withValues(alpha: 0.4)
                                    : AppColors.main),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
