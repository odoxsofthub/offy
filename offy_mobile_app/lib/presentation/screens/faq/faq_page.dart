import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/support_email_launcher.dart';
import '../../viewmodels/faq/faq_provider.dart';
import '../../widgets/common/custom_screen_header.dart';
import '../../widgets/faq/faq_item_tile.dart';
import '../../widgets/faq/faq_shimmer.dart';
import '../../widgets/faq/faq_support_card.dart';
import '../../../../l10n/app_localizations.dart';


class FaqPage extends StatefulWidget {
  const FaqPage({super.key});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  int? _expandedIndex;
  bool _isContactSupportLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FaqProvider>().fetchFaqs();
      }
    });
  }

  Future<void> _handleContactSupport() async {
    if (_isContactSupportLoading) return;
    setState(() {
      _isContactSupportLoading = true;
    });
    try {
      await SupportEmailLauncher.openSupportEmail(context);
    } finally {
      if (mounted) {
        setState(() {
          _isContactSupportLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<FaqProvider>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
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
              CustomScreenHeader(
                title: AppLocalizations.of(context)?.faqAndSupport ?? 'FAQ and Support',
                centerTitle: false,
                onBackTap: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isEmptyState =
                        !provider.isLoading &&
                        provider.error == null &&
                        provider.faqs.isEmpty;

                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisAlignment: isEmptyState
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: 20.h),
                            _buildContent(context, provider, isDark),
                            SizedBox(height: 20.h),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Fixed Bottom Support Card
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
                  child: FaqSupportCard(
                    isLoading: _isContactSupportLoading,
                    onContactSupportTap: _handleContactSupport,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    FaqProvider provider,
    bool isDark,
  ) {
    if (provider.isLoading) {
      return const FaqShimmer();
    }

    if (provider.error != null) {
      return _buildError(context, provider.error!, isDark);
    }

    final faqs = provider.faqs;

    if (faqs.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)?.noFaqsAvailable ?? 'No FAQs available',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w700,
                  height: 28 / 28,
                  color: AppColors.secondary,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                "No frequently asked questions are available at the moment.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w300,
                  height: 24 / 18,
                  color: isDark ? AppColors.white : AppColors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0D000000),
            offset: const Offset(0, 1),
            blurRadius: 2.r,
          ),
        ],
      ),
      child: Column(
        children: List.generate(faqs.length, (index) {
          final item = faqs[index];
          final isExpanded = _expandedIndex == index;
          return FaqItemTile(
            question: item.question,
            answer: item.answer,
            isFirst: index == 0,
            isLast: index == faqs.length - 1,
            isExpanded: isExpanded,
            onTap: () {
              setState(() {
                if (_expandedIndex == index) {
                  _expandedIndex = null;
                } else {
                  _expandedIndex = index;
                }
              });
            },
          );
        }),
      ),
    );
  }

  Widget _buildError(BuildContext context, String error, bool isDark) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: isDark ? AppColors.white : AppColors.black,
              ),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () {
                context.read<FaqProvider>().fetchFaqs();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.main,
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
