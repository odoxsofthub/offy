import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../viewmodels/expenses/expenses_provider.dart';
import '../../viewmodels/attendance/attendance_provider.dart';
import '../../viewmodels/home/home_provider.dart';
import '../../viewmodels/user/access_provider.dart';
import '../../widgets/expenses/expenses_header.dart';
import '../../widgets/expenses/submit_expense_card.dart';
import '../../widgets/expenses/pending_reimbursements_card.dart';
import '../../widgets/expenses/expenses_list.dart';
import '../../widgets/empty_state/empty_state_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../viewmodels/home/home_navigation_provider.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/network/network_interceptor.dart';
import 'submit_expense_page.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    _wasOffline = NetworkInterceptor.instance.isOfflineBlocking;
    NetworkInterceptor.instance.addListener(_onNetworkStateChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context
          .read<HomeNavigationProvider>()
          .consumeSuppressNextTabFetch()) {
        return;
      }
      context.read<ExpensesProvider>().fetchExpenseSummary();
    });
  }

  void _onNetworkStateChange() {
    if (!mounted) return;
    final isOffline = NetworkInterceptor.instance.isOfflineBlocking;
    if (_wasOffline && !isOffline) {
      _wasOffline = false;
      _refreshAllData();
    } else {
      _wasOffline = isOffline;
    }
  }

  @override
  void dispose() {
    NetworkInterceptor.instance.removeListener(_onNetworkStateChange);
    super.dispose();
  }

  Future<void> _refreshAllData() async {
    if (!mounted) return;
    await context.read<ExpensesProvider>().fetchExpenseSummary();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpensesProvider>();
    final accessProvider = context.watch<AccessProvider>();
    final hasExpense = accessProvider.hasFeature('expense');
    final l10n = AppLocalizations.of(context);

    final bool hasError =
        !provider.isLoading &&
        provider.summary == null &&
        provider.errorMessage != null;

    final bool isEmpty =
        !provider.isLoading &&
        provider.summary != null &&
        provider.summary!.recentExpenses.isEmpty;

    return Container(
      decoration: Theme.of(context).brightness == Brightness.dark
          ? const BoxDecoration(color: AppColors.darkBg)
          : const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.light, AppColors.light, Colors.white],
                stops: [0.0, 0.5375, 1.0],
              ),
            ),
      child: Column(
        children: [
          ExpensesHeader(),
          Expanded(
            child: hasError
                ? EmptyStateView(
                    imagePath: AppAssets.noExpenses,
                    title:
                        l10n?.failedToLoadExpenses ?? 'Failed to load expenses',
                    subtitle: provider.errorMessage ?? 'Something went wrong.',
                    showActionButton: true,
                    actionButtonText: l10n?.retry ?? 'Retry',
                    actionButtonIcon: Icons.refresh_rounded,
                    onActionButtonTap: () {
                      context.read<ExpensesProvider>().fetchExpenseSummary();
                    },
                  )
                : isEmpty
                ? EmptyStateView(
                    imagePath: AppAssets.noExpenses,
                    title: l10n?.noExpensesFound ?? 'No expenses found',
                    subtitle:
                        l10n?.youHaventLoggedAnyExpensesYet ??
                        "You haven't logged any expenses yet.",
                    showActionButton: hasExpense,
                    actionButtonText: l10n?.addNewExpense ?? 'Add new expense',
                    onActionButtonTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          settings: const RouteSettings(
                            name: AppRouter.submitExpense,
                          ),
                          builder: (context) => const SubmitExpensePage(),
                        ),
                      );

                      if (result == true && context.mounted) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (context.mounted) {
                            final attendanceProvider = context
                                .read<AttendanceProvider>();
                            context.read<HomeProvider>().fetchHomeData(
                              attendanceProvider,
                            );
                            context
                                .read<ExpensesProvider>()
                                .fetchExpenseSummary();
                          }
                        });
                      }
                    },
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      await context
                          .read<ExpensesProvider>()
                          .fetchExpenseSummary();
                    },
                    color: const Color(0xFFD66A46),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: SafeArea(
                        top: false,
                        bottom: false,
                        left: false,
                        right: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 28.h),
                            if (hasExpense) ...[
                              SubmitExpenseCard(
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      settings: const RouteSettings(
                                        name: AppRouter.submitExpense,
                                      ),
                                      builder: (context) =>
                                          const SubmitExpensePage(),
                                    ),
                                  );

                                  if (result == true && context.mounted) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (context.mounted) {
                                            final attendanceProvider = context
                                                .read<AttendanceProvider>();
                                            context
                                                .read<HomeProvider>()
                                                .fetchHomeData(
                                                  attendanceProvider,
                                                );
                                            context
                                                .read<ExpensesProvider>()
                                                .fetchExpenseSummary();
                                          }
                                        });
                                  }
                                },
                              ),
                              SizedBox(height: 16.h),
                            ],
                            const PendingReimbursementsCard(),
                            SizedBox(height: 26.h),
                            const ExpensesList(),
                            SizedBox(height: 24.h),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
