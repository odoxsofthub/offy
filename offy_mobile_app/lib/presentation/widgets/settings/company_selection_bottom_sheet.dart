import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../viewmodels/user/access_provider.dart';
import '../common/custom_back_button.dart';

class CompanyItem {
  final int id;
  final String name;
  final bool isDefault;

  const CompanyItem({
    required this.id,
    required this.name,
    this.isDefault = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompanyItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class CompanySelectionBottomSheet extends StatefulWidget {
  final String currentCompany;
  final List<CompanyItem> companies;
  final Future<void> Function(CompanyItem) onCompanySelected;

  const CompanySelectionBottomSheet({
    super.key,
    required this.currentCompany,
    required this.companies,
    required this.onCompanySelected,
  });

  static void show(
    BuildContext context, {
    required String currentCompany,
    required Future<void> Function(CompanyItem) onCompanySelected,
    List<CompanyItem>? companies,
  }) {
    FocusScope.of(context).unfocus();
    final effectiveCompanies = companies ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (BuildContext context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
        child: CompanySelectionBottomSheet(
          currentCompany: currentCompany,
          companies: effectiveCompanies,
          onCompanySelected: onCompanySelected,
        ),
      ),
    );
  }

  @override
  State<CompanySelectionBottomSheet> createState() =>
      _CompanySelectionBottomSheetState();
}

class _CompanySelectionBottomSheetState
    extends State<CompanySelectionBottomSheet> {
  late CompanyItem _tempSelectedCompany;
  bool _isLoading = false;
  double _dragOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _tempSelectedCompany = widget.companies.firstWhere(
      (c) => c.name == widget.currentCompany,
      orElse: () => widget.companies.isNotEmpty
          ? widget.companies.first
          : CompanyItem(id: 0, name: widget.currentCompany),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultCompanyId = context
        .watch<AccessProvider>()
        .accessDetails
        ?.company
        ?.defaultCompanyId;
    final hasExplicitDefault = widget.companies.any((c) => c.isDefault);

    return PopScope(
      canPop: !_isLoading,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: isDark
              ? AppColors.darkTopCard
              : AppColors.midLight,
          systemNavigationBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: GestureDetector(
                onTap: () {},
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkTopCard : AppColors.light,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x1F000000),
                        offset: const Offset(0, -8),
                        blurRadius: 40.r,
                        spreadRadius: 0,
                      ),
                    ],
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32.r),
                      topRight: Radius.circular(32.r),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: (details) {
                          if (_isLoading) return;
                          if (details.delta.dy > 0 || _dragOffset > 0) {
                            setState(() {
                              _dragOffset =
                                  (_dragOffset + details.delta.dy).clamp(
                                0.0,
                                400.0,
                              );
                            });
                          }
                        },
                        onVerticalDragEnd: (details) {
                          // Guard: ignore end event if loading started mid-drag.
                          if (_isLoading) {
                            setState(() {
                              _dragOffset = 0.0;
                            });
                            return;
                          }
                          if (_dragOffset > 80 ||
                              (details.primaryVelocity ?? 0) > 300) {
                            Navigator.of(context).pop();
                          } else {
                            setState(() {
                              _dragOffset = 0.0;
                            });
                          }
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(height: 20.h),
                              Row(
                                children: [
                                  CustomBackButton(
                                    onTap: _isLoading ? () {} : null,
                                  ),
                                  SizedBox(width: 19.w),
                                  Expanded(
                                    child: Text(
                                      AppLocalizations.of(
                                            context,
                                          )?.chooseCompany ??
                                          'Choose company',
                                      style: TextStyle(
                                        fontSize: 20.sp,
                                        fontWeight: FontWeight.w600,
                                        height: 28 / 20,
                                        color: isDark
                                            ? AppColors.white
                                            : const Color(0xFF1B1C1C),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 24.h),
                            ],
                          ),
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          physics: _isLoading
                              ? const NeverScrollableScrollPhysics()
                              : const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: widget.companies.map((company) {
                                  final isSelected =
                                      _tempSelectedCompany == company;
                                  final isDefaultCompany = hasExplicitDefault
                                      ? company.isDefault
                                      : (defaultCompanyId != null &&
                                          defaultCompanyId != 0 &&
                                          company.id == defaultCompanyId);
                                  return InkWell(
                                    onTap: _isLoading
                                        ? null
                                        : () {
                                            setState(() {
                                              _tempSelectedCompany = company;
                                            });
                                          },
                                    borderRadius: BorderRadius.circular(12.r),
                                    child: Container(
                                      margin: EdgeInsets.only(bottom: 10.h),
                                      padding: EdgeInsets.fromLTRB(
                                        16.w,
                                        16.h,
                                        15.w,
                                        16.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.darkCard
                                            : Colors.white.withValues(
                                                alpha: 0.8,
                                              ),
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(
                                                  0x4DE4BEB4,
                                                ).withValues(alpha: 0.3)
                                              : const Color(0x4DE4BEB4),
                                          width: 1.w,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          if (isDefaultCompany) ...[
                                            SvgPicture.asset(
                                              AppAssets.company,
                                              width: 20.w,
                                              height: 20.w,
                                              colorFilter: ColorFilter.mode(
                                                isDark
                                                    ? AppColors.darkNav
                                                    : AppColors.navColor,
                                                BlendMode.srcIn,
                                              ),
                                            ),
                                            SizedBox(width: 10.w),
                                          ],
                                          Expanded(
                                            child: Text(
                                              company.name,
                                              style: TextStyle(
                                                fontSize: 16.sp,
                                                fontWeight: FontWeight.w500,
                                                height: 28 / 16,
                                                color: isDark
                                                    ? AppColors.white
                                                    : const Color(0xFF1B1C1C),
                                              ),
                                            ),
                                          ),
                                          isSelected
                                              ? Container(
                                                  width: 26.w,
                                                  height: 26.w,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Color(
                                                          0xFFB02F00,
                                                        ),
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: Center(
                                                    child: Container(
                                                      height: 9.w,
                                                      width: 9.w,
                                                      decoration: BoxDecoration(
                                                        color: AppColors.white,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : Container(
                                                  width: 26.w,
                                                  height: 26.w,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: isDark
                                                          ? Colors.white
                                                                .withValues(
                                                                  alpha: 0.2,
                                                                )
                                                          : const Color(
                                                              0x33000000,
                                                            ),
                                                      width: 1.w,
                                                    ),
                                                  ),
                                                ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              SizedBox(height: 10.h),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        color: isDark ? AppColors.darkCard : AppColors.midLight,
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              16.w,
                              10.h,
                              16.w,
                              12.h,
                            ),
                            child: GestureDetector(
                              onTap: _isLoading
                                  ? null
                                  : () async {
                                      final navigator = Navigator.of(context);
                                      if (_tempSelectedCompany.name ==
                                          widget.currentCompany) {
                                        navigator.pop();
                                        return;
                                      }
                                      setState(() {
                                        _isLoading = true;
                                      });
                                      try {
                                        await widget.onCompanySelected(
                                          _tempSelectedCompany,
                                        );
                                        if (mounted) {
                                          navigator.pop();
                                        }
                                      } catch (_) {
                                        if (mounted) {
                                          setState(() {
                                            _isLoading = false;
                                          });
                                        }
                                      }
                                    },
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Color(0xFFFF5722),
                                      Color(0xFFFF8A65),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFFF5722,
                                      ).withValues(alpha: 0.25),
                                      offset: const Offset(0, 8),
                                      blurRadius: 15.r,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: _isLoading
                                      ? SizedBox(
                                          width: 20.w,
                                          height: 20.w,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.w,
                                            color: AppColors.white,
                                          ),
                                        )
                                      : Text(
                                          AppLocalizations.of(
                                                context,
                                              )?.confirm ??
                                              'Confirm',
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w400,
                                            height: 24 / 16,
                                            color: AppColors.white,
                                          ),
                                        ),
                                ),
                              ),
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
      ),
    );
  }
}
