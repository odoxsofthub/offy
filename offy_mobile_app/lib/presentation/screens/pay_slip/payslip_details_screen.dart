import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/payslip_response_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../viewmodels/pay_slip/payslip_provider.dart';
import '../../widgets/common/custom_screen_header.dart';
import '../../widgets/pay_slip/payslip_log_section.dart';
import '../../widgets/pay_slip/payslip_pdf_shimmer.dart';
import '../../widgets/pay_slip/payslip_tab_bar_widget.dart';

class PayslipDetailsScreen extends StatefulWidget {
  final PayslipModel payslipItem;

  const PayslipDetailsScreen({super.key, required this.payslipItem});

  @override
  State<PayslipDetailsScreen> createState() => _PayslipDetailsScreenState();
}

class _PayslipDetailsScreenState extends State<PayslipDetailsScreen> {
  Uint8List? _pdfBytes;
  bool _isPdfLoaded = false;
  String? _error;
  int _selectedTabIndex = 0;
  PdfDownloadState _downloadState = PdfDownloadState.idle;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    final provider = context.read<PayslipProvider>();
    final bytes = await provider.fetchPayslipPdfBytes(widget.payslipItem);

    if (mounted) {
      setState(() {
        _pdfBytes = bytes;
        if (bytes == null) {
          _error =
              provider.errorMessage ??
              (AppLocalizations.of(context)?.failedToLoadPdf ??
                  'Failed to load PDF.');
        }
      });
    }
  }

  void _downloadPdf() async {
    // Prevent double-tap while a download is already in progress
    if (_downloadState == PdfDownloadState.loading) return;
    setState(() => _downloadState = PdfDownloadState.loading);

    final provider = context.read<PayslipProvider>();
    final success = await provider.downloadPayslipPdf(
      widget.payslipItem,
      existingBytes: _pdfBytes,
    );

    if (mounted) {
      setState(
        () => _downloadState = success
            ? PdfDownloadState.success
            : PdfDownloadState.error,
      );

      // Revert icon back to idle after 1.5 s
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _downloadState = PdfDownloadState.idle);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: isDark ? AppColors.darkTopCard : AppColors.midLight,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.white,
        body: SafeArea(
          bottom: false,
          top: false,
          child: Stack(
            children: [
              // Fixed header and main content block
              Column(
                children: [
                  CustomScreenHeader(
                    title: AppLocalizations.of(context)?.paySlip ?? 'Payslip',
                    onBackTap: () => Navigator.pop(context),
                  ),
                  PayslipTabBarWidget(
                    selectedIndex: _selectedTabIndex,
                    onTabSelected: (index) {
                      setState(() => _selectedTabIndex = index);
                    },
                    onPdfDownloadTap: _downloadPdf,
                    isPdfReady: _isPdfLoaded,
                    downloadState: _downloadState,
                  ),
                  Expanded(
                    child: _selectedTabIndex == 1
                        ? PayslipLogSection(payslipId: widget.payslipItem.id)
                        : _error != null
                        ? SafeArea(
                            top: false,
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.all(20.w),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 48.w,
                                      color: Colors.red,
                                    ),
                                    SizedBox(height: 16.h),
                                    Text(
                                      _error!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: isDark
                                            ? AppColors.white.withValues(
                                                alpha: 0.7,
                                              )
                                            : AppColors.tertiary,
                                      ),
                                    ),
                                    SizedBox(height: 16.h),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _isPdfLoaded = false;
                                          _error = null;
                                          _pdfBytes = null;
                                        });
                                        _loadPdf();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.main,
                                        foregroundColor: AppColors.white,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 20.w,
                                          vertical: 10.h,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8.r,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        AppLocalizations.of(context)?.retry ??
                                            'Retry',
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : Stack(
                            children: [
                              if (_pdfBytes != null)
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: 15.w,
                                    right: 15.w,
                                    top: 15.h,
                                    bottom: 15.h,
                                  ),
                                  child: SfPdfViewerTheme(
                                    data: SfPdfViewerThemeData(
                                      backgroundColor: Colors.transparent,
                                      progressBarColor: Colors.transparent,
                                    ),
                                    child: SfPdfViewer.memory(
                                      _pdfBytes!,
                                      pageLayoutMode: PdfPageLayoutMode.continuous,
                                      canShowScrollHead: true,
                                      canShowScrollStatus: true,
                                      onDocumentLoaded: (details) {
                                        Future.delayed(
                                          const Duration(milliseconds: 150),
                                          () {
                                            if (mounted) {
                                              setState(() {
                                                _isPdfLoaded = true;
                                              });
                                            }
                                          },
                                        );
                                      },
                                      onDocumentLoadFailed: (details) {
                                        if (mounted) {
                                          setState(() {
                                            _error = details.description;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              if (!_isPdfLoaded)
                                const Positioned.fill(
                                  child: PayslipPdfShimmer(
                                    key: ValueKey('payslip_pdf_shimmer'),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
