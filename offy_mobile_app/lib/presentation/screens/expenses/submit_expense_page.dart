import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:office_app/core/constants/app_assets.dart';
import 'package:provider/provider.dart';
import '../../../../l10n/app_localizations.dart';

import '../../../core/theme/app_colors.dart';
import '../../viewmodels/expenses/expenses_provider.dart';
import '../../widgets/expenses/submit_claim_button.dart';
import '../../widgets/common/custom_screen_header.dart';
import '../../widgets/expenses/submit_expense_form_card.dart';
import '../../widgets/expenses/receipt_upload_card.dart';
import '../../widgets/common/image_upload_bottom_sheet.dart';
import '../../widgets/common/custom_snackbar.dart';
import '../../widgets/common/action_failure_dialog.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/image_compressor_util.dart';
import '../../../core/constants/app_globals.dart';
import '../../../core/constants/error_messages.dart';
import '../../../data/models/expense_category_model.dart';
import '../../../data/models/expense_response_model.dart';
import '../../../domain/entities/attachment_entity.dart';
import '../../../core/network/mock_api_data.dart';

class SubmitExpensePage extends StatefulWidget {
  final RecentExpenseModel? expenseToEdit;

  const SubmitExpensePage({super.key, this.expenseToEdit});

  @override
  State<SubmitExpensePage> createState() => _SubmitExpensePageState();
}

class _SubmitExpensePageState extends State<SubmitExpensePage>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _scrollController = ScrollController();

  String? _selectedCategory;
  DateTime? _selectedDate;
  final List<XFile> _selectedImages = [];
  List<AttachmentEntity> _existingAttachments = [];
  final FocusNode _amountFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();
  bool _isSubmitting = false;
  bool _isDeleting = false;
  bool _isCompressing = false;
  int _compressingCount = 0;
  bool _hasAttemptedSubmit = false;
  bool _isAtBottom = false;

  List<ExpenseCategoryModel> _getCategories(ExpensesProvider provider) {
    if (provider.categories.isEmpty && AppGlobals.isDesignMode) {
      final mockData = MockApiData.getMockResponse(
        'GET',
        '/api/mobile/v1/expense/categories',
      )['data'];
      if (mockData is List) {
        return mockData
            .map(
              (e) => ExpenseCategoryModel.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
    }
    return provider.categories;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.expenseToEdit != null) {
      final item = widget.expenseToEdit!;
      if (item.amount > 0) {
        _amountController.text = item.amount % 1 == 0
            ? item.amount.toInt().toString()
            : item.amount.toString();
      }
      if (item.title.isNotEmpty) {
        _descriptionController.text = item.title;
      }
      if (item.category.isNotEmpty) {
        _selectedCategory = item.category;
      }
      if (item.date.isNotEmpty) {
        _selectedDate = DateTime.tryParse(item.date);
      }
      if (item.attachments != null && item.attachments!.isNotEmpty) {
        _existingAttachments = List.from(item.attachments!);
      }
    }
    _amountFocusNode.addListener(() {
      setState(() {});
    });
    _descriptionFocusNode.addListener(() {
      setState(() {});
    });
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollListener();
      context.read<ExpensesProvider>().fetchCategories();
    });
  }

  @override
  void didChangeMetrics() {
    // Re-check _isAtBottom when the keyboard toggles so the nav bar colour doesn't flicker.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollListener();
    });
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final containerHeight =
        76.h + (bottomPadding > 0 ? (bottomPadding - 8.h) : 8.h);
    final isAtBottom =
        maxExtent <= containerHeight ||
        (maxExtent > containerHeight &&
            _scrollController.position.pixels >= maxExtent - containerHeight);
    if (_isAtBottom != isAtBottom) {
      setState(() {
        _isAtBottom = isAtBottom;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _amountFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return AppDateFormatter.ymdSlash(date);
  }

  Future<void> _selectDate(BuildContext context) async {
    _amountFocusNode.unfocus();
    _descriptionFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).brightness == Brightness.dark
                ? const ColorScheme.dark(
                    primary: AppColors.main,
                    onPrimary: Colors.white,
                    onSurface: AppColors.white,
                  )
                : const ColorScheme.light(
                    primary: AppColors.main,
                    onPrimary: Colors.white,
                    onSurface: AppColors.black,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSelectedImages(List<XFile> images) async {
    if (images.isEmpty) return;

    final totalCurrent = _existingAttachments.length + _selectedImages.length;
    final remaining = 5 - totalCurrent;
    if (remaining <= 0) {
      if (mounted) {
        CustomSnackbar.show(
          context,
          message:
              AppLocalizations.of(context)?.maximumUpload5Files ??
              'Maximum upload 5 files',
        );
      }
      return;
    }

    final cappedFiles = images.take(remaining).toList();
    if (images.length > remaining && mounted) {
      CustomSnackbar.show(
        context,
        message:
            AppLocalizations.of(context)?.maximumUpload5FilesExtraIgnored ??
            'Maximum upload 5 files. Extra files ignored.',
      );
    }

    final validFiles = <XFile>[];
    bool hasOverSized = false;
    for (final f in cappedFiles) {
      final len = await f.length();
      if (len > 10 * 1024 * 1024) {
        // 10MB limit per file
        hasOverSized = true;
      } else {
        validFiles.add(f);
      }
    }

    if (hasOverSized && mounted) {
      CustomSnackbar.show(
        context,
        message:
            AppLocalizations.of(context)?.fileSizeExceeds10MbLimit ??
            'File size exceeds 10MB limit',
      );
    }

    if (validFiles.isEmpty) return;

    setState(() {
      _isCompressing = true;
      _compressingCount = validFiles.length;
    });

    try {
      final compressedImages = await ImageCompressorUtil.compressImageList(
        validFiles,
      );

      if (mounted) {
        setState(() {
          _selectedImages.addAll(compressedImages);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCompressing = false;
          _compressingCount = 0;
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (_isSubmitting || _isCompressing) return;
    _amountFocusNode.unfocus();
    _descriptionFocusNode.unfocus();
    FocusScope.of(context).unfocus();

    if (!mounted) return;
    setState(() {
      _hasAttemptedSubmit = true;
    });

    if (_formKey.currentState!.validate()) {
      final amountVal = double.tryParse(_amountController.text) ?? 0.0;
      if (amountVal <= 0.0) {
        CustomSnackbar.show(
          context,
          message:
              AppLocalizations.of(context)?.enterValidAmount ??
              'Please enter a valid amount greater than 0',
        );
        _scrollToTop();
        return;
      }

      final provider = context.read<ExpensesProvider>();

      final currentCategory = _selectedCategory;
      if (currentCategory == null) {
        _scrollToTop();
        return;
      }

      final category = _getCategories(
        provider,
      ).firstWhere((c) => c.name == currentCategory);

      setState(() {
        _isSubmitting = true;
      });

      final submissionDate = _selectedDate ?? DateTime.now();

      final data = {
        'amount': amountVal.toString(),
        'category_id': category.id.toString(),
        'expense_date': _formatDate(submissionDate),
        'description': _descriptionController.text,
        if (widget.expenseToEdit != null) ...{
          'id': widget.expenseToEdit!.id.toString(),
          'existing_attachments': jsonEncode(
            _existingAttachments
                .map(
                  (e) =>
                      e.id ??
                      int.tryParse(e.url.split('?').first.split('/').last),
                )
                .whereType<int>()
                .toList(),
          ),
        },
      };

      final success = await provider.submitNewExpense(data, _selectedImages);

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        Navigator.pop(context, true);
        CustomSnackbar.show(
          context,
          message:
              AppLocalizations.of(context)?.expenseClaimSubmitted ??
              'Expense claim submitted successfully',
          isSuccess: true,
        );
      } else {
        if (provider.errorMessage != ErrorMessages.requestCancelled) {
          showDialog(
            context: context,
            builder: (_) =>
                ActionFailureDialog(errorMessage: provider.errorMessage),
          );
        }
      }
    } else {
      _scrollToTop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBgColor = _isAtBottom
        ? (isDark ? AppColors.darkTopCard : AppColors.midLight)
        : (isDark ? AppColors.darkBg : Colors.white);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: isDark ? AppColors.darkTopCard : AppColors.midLight,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: scaffoldBgColor,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _amountFocusNode.unfocus();
          _descriptionFocusNode.unfocus();
          FocusScope.of(context).unfocus();
        },
        child: PopScope(
          canPop: !(_isSubmitting || _isCompressing || _isDeleting),
          child: Scaffold(
            backgroundColor: scaffoldBgColor,
          extendBody: true,
          body: SafeArea(
            bottom: true,
            top: false,
            child: Container(
              decoration: Theme.of(context).brightness == Brightness.dark
                  ? const BoxDecoration(color: AppColors.darkBg)
                  : const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.light, Colors.white],
                        stops: [0.5375, 1.0],
                      ),
                    ),
              child: Column(
                children: [
                  // Custom Header Bar with Back Button
                  CustomScreenHeader(
                    isSubmitting: _isSubmitting || _isDeleting,
                    title: widget.expenseToEdit != null
                        ? (AppLocalizations.of(context)?.editExpense ??
                              'Edit Expense')
                        : (AppLocalizations.of(context)?.expenses ??
                              'Expenses'),
                    trailing: widget.expenseToEdit != null
                        ? GestureDetector(
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(
                                    AppLocalizations.of(context)?.delete ??
                                        'Delete',
                                  ),
                                  content: Text(
                                    AppLocalizations.of(
                                          context,
                                        )?.deleteExpenseConfirmation ??
                                        'Are you sure you want to delete this expense?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text(
                                        AppLocalizations.of(context)?.cancel ??
                                            'Cancel',
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(
                                        AppLocalizations.of(context)?.delete ??
                                            'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && context.mounted) {
                                setState(() {
                                  _isDeleting = true;
                                });
                                final provider = context
                                    .read<ExpensesProvider>();
                                final success = await provider.deleteExpense(
                                  widget.expenseToEdit!.id,
                                );
                                if (!context.mounted) return;
                                setState(() {
                                  _isDeleting = false;
                                });
                                if (success) {
                                  Navigator.pop(context, 'deleted');
                                } else if (provider.errorMessage !=
                                    ErrorMessages.requestCancelled) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        provider.errorMessage ??
                                            'Failed to delete expense',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 8.h,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.darkCard
                                    : AppColors.white.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(100.r),
                                border: Border.all(
                                  color: AppColors.red.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isDeleting)
                                    SizedBox(
                                      width: 18.w,
                                      height: 18.w,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.red,
                                            ),
                                      ),
                                    )
                                  else
                                    SvgPicture.asset(
                                      AppAssets.delete,
                                      width: 18.w,
                                      height: 18.w,
                                      colorFilter: const ColorFilter.mode(
                                        AppColors.red,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    AppLocalizations.of(context)?.delete ??
                                        'Delete',
                                    style: TextStyle(
                                      color: AppColors.red,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : null,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const ClampingScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 20.h),
                            // Container 1: Amount, Category, Date, Description
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              child: Consumer<ExpensesProvider>(
                                builder: (context, provider, child) {
                                  return SubmitExpenseFormCard(
                                    isSubmitting: _isSubmitting,
                                    hasAttemptedSubmit: _hasAttemptedSubmit,
                                    amountController: _amountController,
                                    amountFocusNode: _amountFocusNode,
                                    descriptionController:
                                        _descriptionController,
                                    descriptionFocusNode: _descriptionFocusNode,
                                    selectedCategory: _selectedCategory,
                                    categories: _getCategories(provider),
                                    selectedDate: _selectedDate,
                                    isLoading:
                                        provider.isFetchingCategories &&
                                        _getCategories(provider).isEmpty,
                                    onCategorySelected: (cat) {
                                      setState(() {
                                        _selectedCategory = cat;
                                      });
                                    },
                                    onDateSelected: () => _selectDate(context),
                                  );
                                },
                              ),
                            ),
                            SizedBox(height: 16.h),

                            // Container 2: Receipts Upload
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              child: ReceiptUploadCard(
                                isSubmitting: _isSubmitting,
                                isCompressing: _isCompressing,
                                compressingCount: _compressingCount,
                                selectedImages: _selectedImages,
                                existingAttachments: _existingAttachments,
                                onAddImageTap: () {
                                  if (_isSubmitting || _isCompressing) return;
                                  _amountFocusNode.unfocus();
                                  _descriptionFocusNode.unfocus();

                                  final totalCurrent =
                                      _existingAttachments.length +
                                      _selectedImages.length;
                                  final remaining = 5 - totalCurrent;
                                  if (remaining <= 0) {
                                    CustomSnackbar.show(
                                      context,
                                      message:
                                          AppLocalizations.of(
                                            context,
                                          )?.maximumUpload5Files ??
                                          'Maximum upload 5 files',
                                    );
                                    return;
                                  }

                                  ImageUploadBottomSheet.show(
                                    context,
                                    isExpense: true,
                                    onImagesSelected: (images) {
                                      _handleSelectedImages(images);
                                    },
                                  );
                                },
                                onRemoveImageTap: (index) {
                                  if (_isSubmitting || _isCompressing) return;
                                  setState(() {
                                    _selectedImages.removeAt(index);
                                  });
                                },
                                onRemoveExistingAttachmentTap: (index) {
                                  if (_isSubmitting || _isCompressing) return;
                                  setState(() {
                                    _existingAttachments.removeAt(index);
                                  });
                                },
                              ),
                            ),
                            SizedBox(height: 20.h),
                            // Action Button
                            Container(
                              padding: EdgeInsets.fromLTRB(
                                16.w,
                                10.h,
                                16.w,
                                // Fallback for notchless devices without system navigation bars
                                MediaQuery.of(context).padding.bottom > 0
                                    ? 10.h
                                    : 16.h,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.darkTopCard
                                    : AppColors.midLight,
                              ),
                              child: SafeArea(
                                top: false,
                                child: SubmitClaimButton(
                                  isSubmitting: _isSubmitting,
                                  onTap: (_isSubmitting || _isCompressing || _isDeleting)
                                      ? null
                                      : _submitForm,
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
            ),
          ),
        ),
      ),
    ),
    );
  }
}
