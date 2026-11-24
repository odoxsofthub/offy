import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/expense_response_model.dart';

class ExpenseExpandableBottomSection extends StatefulWidget {
  final String date;
  final String? amountDisplay;
  final String? paymentStatus;
  final List<ExpenseBreakdownItem>? breakdownItems;
  final bool isPartiallyPaid;
  final String? amountPaidDisplay;

  const ExpenseExpandableBottomSection({
    super.key,
    required this.date,
    this.amountDisplay,
    this.paymentStatus,
    this.breakdownItems,
    this.isPartiallyPaid = false,
    this.amountPaidDisplay,
  });

  @override
  State<ExpenseExpandableBottomSection> createState() =>
      _ExpenseExpandableBottomSectionState();
}

class _ExpenseExpandableBottomSectionState
    extends State<ExpenseExpandableBottomSection> {
  bool _isExpanded = false;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _extentAfterNotifier = ValueNotifier<double>(
    100.0,
  );

  @override
  void dispose() {
    _scrollController.dispose();
    _extentAfterNotifier.dispose();
    super.dispose();
  }

  DateTime? _tryParseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  String _formatExpenseDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return AppDateFormatter.mmmmDdYyyy(dt);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatAmountWithPrefix(double amount, String referenceDisplay) {
    final cleanRef = referenceDisplay.replaceAll(RegExp(r'[()\s]'), '');
    final match = RegExp(r'^[^\d.,]+').firstMatch(cleanRef);
    final prefix = match != null ? match.group(0)! : '';

    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$prefix$intPart.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final rawItems = widget.breakdownItems ?? const [];
    final itemsToDisplay = List<ExpenseBreakdownItem>.from(rawItems)
      ..sort((a, b) {
        final dtA = _tryParseDate(a.date);
        final dtB = _tryParseDate(b.date);
        if (dtA != null && dtB != null) {
          return dtB.compareTo(dtA);
        } else if (dtA != null) {
          return -1;
        } else if (dtB != null) {
          return 1;
        }
        return b.date.compareTo(a.date);
      });
    final hasItems = itemsToDisplay.isNotEmpty;

    final latestPaidDateStr = (hasItems && itemsToDisplay.first.date.isNotEmpty)
        ? itemsToDisplay.first.date
        : widget.date;
    final formattedMainDate = _formatExpenseDate(latestPaidDateStr);

    final statusText = widget.paymentStatus;
    final formattedStatus = (statusText != null && statusText.isNotEmpty)
        ? (statusText.startsWith('(') ? statusText : '($statusText)')
        : null;

    final rawDisplayAmount = widget.amountDisplay ?? '';
    final displayAmount = rawDisplayAmount
        .replaceAll('(', '')
        .replaceAll(')', '');

    final isPartiallyPaidStatus =
        widget.isPartiallyPaid ||
        (widget.paymentStatus?.toLowerCase().contains('partial') ?? false);

    String finalDisplayAmount = displayAmount;

    if (isPartiallyPaidStatus && displayAmount.isNotEmpty) {
      String? paidAmountText;
      if (widget.amountPaidDisplay != null &&
          widget.amountPaidDisplay!.isNotEmpty) {
        paidAmountText = widget.amountPaidDisplay!
            .replaceAll('(', '')
            .replaceAll(')', '')
            .trim();
      } else if (hasItems) {
        final totalPaid = itemsToDisplay.fold<double>(
          0.0,
          (sum, item) => sum + item.amount,
        );
        if (totalPaid > 0) {
          final referenceForPrefix =
              itemsToDisplay.first.amountDisplay.isNotEmpty
              ? itemsToDisplay.first.amountDisplay
              : rawDisplayAmount;
          paidAmountText = _formatAmountWithPrefix(
            totalPaid,
            referenceForPrefix,
          );
        }
      }

      if (paidAmountText != null && paidAmountText.isNotEmpty) {
        finalDisplayAmount = '$paidAmountText / $displayAmount';
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Frame 29: Collapsed Summary Row
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: hasItems
              ? () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                }
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Dynamic Date Text from API on the Left
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formattedMainDate,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      height: 18 / 13,
                      color: isDark ? AppColors.light : const Color(0xFF6C6966),
                    ),
                  ),
                ),
              ),

              SizedBox(width: 8.w),

              // Amount, Status Subtitle, & Chevron Container on the Right
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (finalDisplayAmount.isNotEmpty)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                finalDisplayAmount,
                                maxLines: 1,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w500,
                                  height: 18 / 16,
                                  color: isDark
                                      ? AppColors.white
                                      : AppColors.black,
                                ),
                              ),
                            ),
                          if (formattedStatus != null) ...[
                            SizedBox(height: 2.h),
                            Text(
                              formattedStatus,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w500,
                                height: 6 / 9,
                                color: AppColors.darkNav,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (hasItems) ...[
                      SizedBox(width: 5.w),
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 14.r,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Expanded List: Frame 2609866 items from API breakdown
        if (_isExpanded && hasItems) ...[
          SizedBox(height: 6.h),
          if (itemsToDisplay.length > 3)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 92.h),
              child: ValueListenableBuilder<double>(
                valueListenable: _extentAfterNotifier,
                builder: (context, extentAfter, child) {
                  final isAtBottom = extentAfter <= 1.0;
                  return ShaderMask(
                    shaderCallback: (Rect bounds) {
                      if (isAtBottom) {
                        return const LinearGradient(
                          colors: [Colors.black, Colors.black],
                        ).createShader(bounds);
                      }
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black,
                          Colors.black,
                          Colors.black,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.7, 0.88, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: child,
                  );
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification notification) {
                    if (notification.metrics.axis == Axis.vertical) {
                      _extentAfterNotifier.value =
                          notification.metrics.extentAfter;
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: itemsToDisplay.map((item) {
                        return _ExpenseBreakdownRow(
                          item: item,
                          isDark: isDark,
                          formattedDate: _formatExpenseDate(item.date),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            )
          else
            ...itemsToDisplay.map((item) {
              return _ExpenseBreakdownRow(
                item: item,
                isDark: isDark,
                formattedDate: _formatExpenseDate(item.date),
              );
            }),
        ],
      ],
    );
  }
}

class _ExpenseBreakdownRow extends StatelessWidget {
  final ExpenseBreakdownItem item;
  final bool isDark;
  final String formattedDate;

  const _ExpenseBreakdownRow({
    required this.item,
    required this.isDark,
    required this.formattedDate,
  });

  @override
  Widget build(BuildContext context) {
    final cleanItemAmount = item.amountDisplay
        .replaceAll('(', '')
        .replaceAll(')', '');
    return Padding(
      padding: EdgeInsets.only(top: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formattedDate,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  height: 18 / 13,
                  color: isDark ? AppColors.light : const Color(0xFF6C6966),
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Flexible(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    cleanItemAmount,
                    maxLines: 1,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      height: 18 / 14,
                      color: isDark ? AppColors.white : AppColors.black,
                    ),
                  ),
                ),
                SizedBox(width: 5.w + 14.r),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
