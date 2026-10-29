import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/user/access_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/expense_category_model.dart';
import '../common/custom_error_text.dart';
import '../../../core/utils/date_formatter.dart';
import 'expense_category_selector_field.dart';

class SubmitExpenseFormCard extends StatefulWidget {
  final bool isSubmitting;
  final bool hasAttemptedSubmit;
  final TextEditingController amountController;
  final FocusNode amountFocusNode;
  final TextEditingController descriptionController;
  final FocusNode descriptionFocusNode;
  final String? selectedCategory;
  final List<ExpenseCategoryModel> categories;
  final DateTime? selectedDate;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onDateSelected;
  final bool isLoading;

  const SubmitExpenseFormCard({
    super.key,
    required this.isSubmitting,
    required this.hasAttemptedSubmit,
    required this.amountController,
    required this.amountFocusNode,
    required this.descriptionController,
    required this.descriptionFocusNode,
    required this.selectedCategory,
    required this.categories,
    required this.selectedDate,
    required this.onCategorySelected,
    required this.onDateSelected,
    this.isLoading = false,
  });

  @override
  State<SubmitExpenseFormCard> createState() => _SubmitExpenseFormCardState();
}

class _SubmitExpenseFormCardState extends State<SubmitExpenseFormCard> {
  @override
  void initState() {
    super.initState();
    widget.amountFocusNode.addListener(_onFocusChange);
    widget.descriptionFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.amountFocusNode.removeListener(_onFocusChange);
    widget.descriptionFocusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  String _formatDate(DateTime date) {
    return AppDateFormatter.dmyDash(date);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkCard
            : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0F2A2A2A),
            blurRadius: 20.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AMOUNT Label
          Text(
            AppLocalizations.of(context)?.amountUppercase ?? 'AMOUNT',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              height: 1.33,
              letterSpacing: 0.6.sp,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFEAE1D8)
                  : const Color(0xFF5B4039),
            ),
          ),
          SizedBox(height: 10.5.h),

          // Amount Input Box
          FormField<String>(
            initialValue: widget.amountController.text,
            // Silent until the first submit; afterwards re-validate on every change.
            autovalidateMode: widget.hasAttemptedSubmit
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            validator: (value) {
              final amountStr = value ?? '';
              if (amountStr.isEmpty) {
                return AppLocalizations.of(context)?.enterAmountCorrectly ??
                    'Enter amount correctly';
              }
              final parsed = double.tryParse(
                amountStr.replaceAll(RegExp(r'[^0-9.]'), ''),
              );
              if (parsed == null || parsed <= 0.0) {
                return AppLocalizations.of(context)?.enterAmountCorrectly ??
                    'Enter amount correctly';
              }
              return null;
            },
            builder: (FormFieldState<String> fieldState) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 17.h,
                    ),
                    decoration: BoxDecoration(
                      color: fieldState.hasError
                          ? (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0x26FD2323)
                                : const Color(0xFFFFEFEF))
                          : (Theme.of(context).brightness == Brightness.dark
                                ? const Color.fromRGBO(246, 243, 242, 0.1)
                                : const Color(0xFFF6F3F2)),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: fieldState.hasError
                            ? const Color(0xFFFD2323)
                            : (widget.amountFocusNode.hasFocus
                                  ? AppColors.main
                                  : (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color.fromRGBO(
                                            209,
                                            199,
                                            176,
                                            0.1,
                                          )
                                        : const Color(0xFFD1C7B0))),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          context
                                  .read<AccessProvider>()
                                  .accessDetails
                                  ?.company
                                  ?.defaultCompanyCurrency
                                  ?.symbol ??
                              '\$',
                          style: GoogleFonts.inter(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                            letterSpacing: 0.0,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF9F4122)
                                : const Color(0xFF5B4039),
                          ),
                        ),
                        SizedBox(width: 6.73.w),
                        Expanded(
                          child: TextFormField(
                            cursorColor: fieldState.hasError
                                ? const Color(0xFFFD2323)
                                : AppColors.main,
                            focusNode: widget.amountFocusNode,
                            controller: widget.amountController,
                            readOnly: widget.isSubmitting,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [AmountInputFormatter()],
                            onChanged: (val) {
                              fieldState.didChange(val);
                              if (widget.hasAttemptedSubmit) {
                                fieldState.validate();
                              }
                            },
                            style: TextStyle(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.w600,
                              height: 1.0,
                              letterSpacing: -0.24.sp,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.white
                                  : AppColors.black,
                            ),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              hintStyle: TextStyle(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.w600,
                                height: 1.0,
                                letterSpacing: -0.24.sp,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFCAC3C0)
                                    : const Color(0xFF6B7280),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CustomErrorText(errorText: fieldState.errorText),
                ],
              );
            },
          ),
          SizedBox(height: 24.h),

          SizedBox(height: 5.5.h),
          // CATEGORY Selector Label
          Text(
            AppLocalizations.of(context)?.categoryUppercase ?? 'CATEGORY',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              height: 1.33,
              letterSpacing: 0.6.sp,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFEAE1D8)
                  : const Color(0xFF5B4039),
            ),
          ),
          SizedBox(height: 10.5.h),

          // Category Selector
          ExpenseCategorySelectorField(
            isSubmitting: widget.isSubmitting,
            selectedCategory: widget.selectedCategory,
            categories: widget.categories,
            isLoading: widget.isLoading,
            errorText:
                widget.hasAttemptedSubmit && widget.selectedCategory == null
                ? (AppLocalizations.of(context)?.pleaseSelectCategory ??
                      '*Please select a category')
                : null,
            onCategorySelected: (cat) {
              widget.amountFocusNode.unfocus();
              widget.descriptionFocusNode.unfocus();
              FocusScope.of(context).unfocus();
              if (cat != null) {
                widget.onCategorySelected(cat);
              }
            },
          ),
          SizedBox(height: 26.h),

          SizedBox(height: 5.5.h),
          // DATE OF EXPENSE Label
          Text(
            AppLocalizations.of(context)?.dateOfExpense ?? 'DATE OF EXPENSE',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              height: 1.33,
              letterSpacing: 0.6.sp,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFEAE1D8)
                  : const Color(0xFF5B4039),
            ),
          ),
          SizedBox(height: 10.5.h),
          GestureDetector(
            onTap: widget.isSubmitting ? null : widget.onDateSelected,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color.fromRGBO(246, 243, 242, 0.1)
                    : const Color(0xFFF6F3F2),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color.fromRGBO(209, 199, 176, 0.1)
                      : const Color(0xFFD1C7B0),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(widget.selectedDate ?? DateTime.now()),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                      letterSpacing: 0.0,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFF3E9E0)
                          : AppColors.black,
                    ),
                  ),
                  Icon(
                    Icons.calendar_today_outlined,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF9F4122)
                        : AppColors.tertiary,
                    size: 20.w,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24.h),

          SizedBox(height: 5.5.h),
          // DESCRIPTION Label
          Text(
            AppLocalizations.of(context)?.descriptionUppercase ?? 'DESCRIPTION',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              height: 1.33,
              letterSpacing: 0.6.sp,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFEAE1D8)
                  : const Color(0xFF5B4039),
            ),
          ),
          SizedBox(height: 10.5.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color.fromRGBO(246, 243, 242, 0.1)
                  : const Color(0xFFF6F3F2),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: widget.descriptionFocusNode.hasFocus
                    ? AppColors.main
                    : (Theme.of(context).brightness == Brightness.dark
                          ? const Color.fromRGBO(209, 199, 176, 0.1)
                          : const Color(0xFFD1C7B0)),
                width: 1.0,
              ),
            ),
            child: TextFormField(
              cursorColor: AppColors.main,
              focusNode: widget.descriptionFocusNode,
              controller: widget.descriptionController,
              readOnly: widget.isSubmitting,
              maxLines: 3,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.white
                    : AppColors.black,
              ),
              decoration: InputDecoration(
                hintText:
                    AppLocalizations.of(context)?.addAdditionalDetails ??
                    'Add additional details about this expense...',
                hintStyle: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFA49D95)
                      : const Color(0xFF6B7280),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AmountInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    var selection = newValue.selection;

    if (text.isEmpty) {
      return newValue;
    }

    // If user types '.' first, automatically prepend '0'
    if (text.startsWith('.')) {
      text = '0$text';
      selection = TextSelection.collapsed(
        offset: (selection.baseOffset + 1).clamp(0, text.length),
      );
    }

    // If user types a digit after leading '0' without '.', strip leading zeros (e.g. '05' -> '5')
    if (text.length > 1 && text.startsWith('0') && !text.startsWith('0.')) {
      text = text.replaceFirst(RegExp(r'^0+'), '');
      if (text.isEmpty) {
        text = '0';
      } else if (text.startsWith('.')) {
        text = '0$text';
      }
      selection = TextSelection.collapsed(
        offset: (selection.baseOffset - 1).clamp(0, text.length),
      );
    }

    // Max 8 digits before decimal point, optional decimal point with max 4 digits after
    final regExp = RegExp(r'^(0|[1-9][0-9]{0,7})?(\.[0-9]{0,4})?$');
    if (regExp.hasMatch(text)) {
      return TextEditingValue(
        text: text,
        selection: selection,
      );
    }
    return oldValue;
  }
}
