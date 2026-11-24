import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../viewmodels/pay_slip/payslip_provider.dart';
import '../../widgets/common/custom_screen_header.dart';
import '../../widgets/empty_state/empty_state_view.dart';
import '../../widgets/pay_slip/payslip_history_section.dart';
import '../../widgets/pay_slip/payslip_overview_card.dart';

class PaySlipPage extends StatefulWidget {
  const PaySlipPage({super.key});

  @override
  State<PaySlipPage> createState() => _PaySlipPageState();
}

class _PaySlipPageState extends State<PaySlipPage> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PayslipProvider>();
      provider.fetchPayslip().then((_) {
        if (mounted) setState(() => _isInitialized = true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {


    final provider = context.watch<PayslipProvider>();
    final bool isEmpty =
        _isInitialized &&
        !provider.isLoading &&
        (provider.payslip == null || provider.payslip!.id == 0);

    final bool isHistoryEmpty =
        (provider.payslip?.history?.isEmpty ?? true);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isDark ? AppColors.darkBg : Colors.white,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkTopCard : AppColors.midLight,
        body: Container(
          decoration: isDark
              ? const BoxDecoration(color: AppColors.darkBg)
              : const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF3E9E0), Colors.white],
                    stops: [0.5375, 1.0],
                  ),
                ),
          child: Column(
            children: [
              // Custom Header with centered "Payslip" title
              CustomScreenHeader(
                isSubmitting: false,
                title: AppLocalizations.of(context)?.paySlip ?? 'Payslip',
                centerTitle: true,
              ),

              // Main body content with gradient background
              Expanded(
                child: SafeArea(
                  top: false,
                  bottom: true,
                  child: isEmpty
                      ? RefreshIndicator(
                          onRefresh: () async {
                            await provider.fetchPayslip();
                          },
                          color: AppColors.main,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: ClampingScrollPhysics(),
                            ),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.7,
                              child: EmptyStateView(
                                imagePath: AppAssets.noPayslips,
                                title:
                                    AppLocalizations.of(
                                      context,
                                    )?.noPayslipsAvailable ??
                                    'No payslips available',
                                subtitle:
                                    AppLocalizations.of(
                                      context,
                                    )?.noPayslipsSubtitle ??
                                    'Your generated payslips will appear here.',
                              ),
                            ),
                          ),
                        )
                      : isHistoryEmpty
                          ? RefreshIndicator(
                              onRefresh: () async {
                                await provider.fetchPayslip();
                              },
                              color: AppColors.main,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return SingleChildScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(
                                          parent: ClampingScrollPhysics(),
                                        ),
                                    child: SizedBox(
                                      height: constraints.maxHeight,
                                      child: Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          16.w,
                                          27.h,
                                          16.w,
                                          30.h,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const PayslipOverviewCard(),
                                            SizedBox(height: 36.h),
                                            const Expanded(
                                              child: PayslipHistorySection(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                      : RefreshIndicator(
                          onRefresh: () async {
                            await provider.fetchPayslip();
                          },
                          color: AppColors.main,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: ClampingScrollPhysics(),
                            ),
                            padding: EdgeInsets.fromLTRB(
                              16.w,
                              27.h,
                              16.w,
                              13.h,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const PayslipOverviewCard(),
                                SizedBox(height: 36.h),
                                const PayslipHistorySection(),
                              ],
                            ),
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
}
