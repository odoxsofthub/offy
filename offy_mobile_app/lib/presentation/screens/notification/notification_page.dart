import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../viewmodels/notification/notification_provider.dart';
import '../../widgets/notification/notification_header.dart';
import '../../widgets/notification/swipeable_notification_card.dart';
import '../../widgets/notification/notification_shimmer.dart';
import '../../widgets/empty_state/empty_state_view.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final ScrollController _scrollController = ScrollController();

  // Tracks which notification card currently has the delete button revealed.
  int? _revealedCardId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationProvider>().fetchNotifications(refresh: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<NotificationProvider>().fetchNotifications();
    }
  }

  String _formatGroupHeader(BuildContext context, String key) {
    final l10n = AppLocalizations.of(context);
    if (key == 'NEW') {
      return l10n?.newUpper ?? 'NEW';
    } else if (key == 'TODAY') {
      return l10n?.today ?? 'TODAY';
    } else if (key == 'YESTERDAY') {
      return l10n?.yesterday ?? 'YESTERDAY';
    } else if (key == '2 DAYS AGO') {
      return l10n?.twoDaysAgo ?? '2 DAYS AGO';
    } else {
      final parsedDate = DateTime.tryParse(key);
      if (parsedDate != null) {
        final locale = Localizations.localeOf(context).toString();
        return DateFormat('d MMM yyyy', locale).format(parsedDate).toUpperCase();
      }
      return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final bool isEmpty =
        !provider.isLoading &&
        ((provider.notifications as List?) == null ||
            provider.notifications.isEmpty);
    final grouped = provider.groupedNotifications;

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
              // Custom Header - using standalone widget
              const NotificationHeader(),

              // Notification List Content
              Expanded(
                child: SafeArea(
                  top: false,
                  child: provider.isLoading
                      ? const NotificationShimmer()
                      : isEmpty
                      ? RefreshIndicator(
                          onRefresh: () async {
                            await context
                                .read<NotificationProvider>()
                                .fetchNotifications(refresh: true);
                          },
                          color: AppColors.main,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.7,
                              child: EmptyStateView(
                                imagePath: AppAssets.noNotifications,
                                title: AppLocalizations.of(context)?.noNotifications ?? 'No notifications',
                                subtitle:
                                    AppLocalizations.of(context)?.noNotificationsSubtitle ?? "You're all caught up. New updates will appear here.",
                              ),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            await context
                                .read<NotificationProvider>()
                                .fetchNotifications(refresh: true);
                          },
                          color: const Color(0xFFFD5223),
                          // Collapse any revealed delete button when tapping the scroll background.
                          child: GestureDetector(
                            onTap: () {
                              if (_revealedCardId != null) {
                                setState(() => _revealedCardId = null);
                              }
                            },
                            behavior: HitTestBehavior.translucent,
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.only(
                                top: 18.h,
                                left: 16.w,
                                right: 16.w,
                                bottom: 24.h,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (var entry in grouped.entries) ...[
                                    Text(
                                      _formatGroupHeader(context, entry.key),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.sp,
                                        height: 16 / 12,
                                        letterSpacing: 0.6.sp,
                                        color: isDark
                                            ? (entry.key == 'NEW'
                                                  ? AppColors.main
                                                  : const Color(0xFF9F4122))
                                            : const Color(0xFF5B4039),
                                      ),
                                    ),
                                    SizedBox(height: 12.h),
                                    for (
                                      int i = 0;
                                      i < entry.value.length;
                                      i++
                                    ) ...[
                                      SwipeableNotificationCard(
                                        key: ValueKey(
                                          'notification_${entry.key}_${entry.value[i].id}_$i',
                                        ),
                                        item: entry.value[i],
                                        isNew: !entry.value[i].isRead,
                                        isRevealed:
                                            _revealedCardId == entry.value[i].id,
                                        onReveal: () => setState(
                                          () => _revealedCardId =
                                              entry.value[i].id,
                                        ),
                                        onCollapse: () => setState(
                                          () => _revealedCardId = null,
                                        ),
                                      ),
                                      if (i < entry.value.length - 1)
                                        SizedBox(height: 12.h),
                                    ],
                                    if (entry.key != grouped.keys.last)
                                      SizedBox(height: 30.h),
                                  ],
                                  if (provider.isLoadingMore) ...[
                                    SizedBox(height: 16.h),
                                    const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFFFD5223),
                                      ),
                                    ),
                                  ],
                                ],
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
    );
  }
}
