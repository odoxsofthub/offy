import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/profile_response_model.dart';
import 'profile_contact_card.dart';
import '../common/custom_snackbar.dart';
import '../../../../l10n/app_localizations.dart';


class WorkTabContent extends StatelessWidget {
  static List<ProfileBankModel> _bankAccounts(ProfileWorkModel? work) {
    if (work == null) return const [];
    if (work.bankAccounts.isNotEmpty) return work.bankAccounts;
    return work.bank != null ? [work.bank!] : const [];
  }

  final ProfileModel profile;
  final ScrollPhysics? physics;

  const WorkTabContent({super.key, required this.profile, this.physics});

  Future<void> _connectWithManager(
    BuildContext context,
    String managerEmail,
    String? userEmail,
  ) async {
    final userEmailTrimmed = userEmail?.trim();
    final String urlString;
    if (userEmailTrimmed != null && userEmailTrimmed.isNotEmpty) {
      urlString =
          'mailto:${Uri.encodeComponent(managerEmail)}?from=${Uri.encodeComponent(userEmailTrimmed)}';
    } else {
      urlString = 'mailto:${Uri.encodeComponent(managerEmail)}';
    }
    final Uri emailLaunchUri = Uri.parse(urlString);

    try {
      final bool canLaunch = await canLaunchUrl(emailLaunchUri);
      if (canLaunch) {
        await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
      } else {
        final bool launched = await launchUrl(
          emailLaunchUri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched && context.mounted) {
          CustomSnackbar.show(
            context,
            message:
                AppLocalizations.of(context)?.couldNotFindEmailApp ??
                'Could not find an email application on device.',
            isError: true,
          );
        }
      }
    } catch (_) {
      try {
        await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (context.mounted) {
          CustomSnackbar.show(
            context,
            message:
                AppLocalizations.of(context)?.failedToLaunchEmailClient ??
                'Failed to launch email client.',
            isError: true,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final work = profile.work;
    final rawEmail = work?.email ?? profile.email;
    final rawPhone = work?.phone ?? profile.phone;
    final emailVal = rawEmail?.toLowerCase() ?? 'N/A';
    final phoneVal = rawPhone ?? 'N/A';
    final jobTitleVal = work?.jobTitle ?? profile.jobTitle ?? 'N/A';
    final jobPosVal = work?.jobPosition ?? profile.department;
    final managerVal = work?.managerName ?? profile.reportTo?.name ?? 'N/A';

    final rawManagerEmail = work?.manager?.email ?? profile.reportTo?.email;
    final managerEmail =
        (rawManagerEmail != null && rawManagerEmail.trim().isNotEmpty)
        ? rawManagerEmail.trim()
        : null;
    final canConnect = profile.reportTo != null
        ? profile.reportTo!.canConnect
        : (work?.managerCanConnect ?? false);

    final showConnect = canConnect && managerEmail != null;

    final isWorkEmpty =
        work == null &&
        (profile.email == null || profile.email!.isEmpty) &&
        (profile.phone == null || profile.phone!.isEmpty) &&
        (profile.jobTitle == null || profile.jobTitle!.isEmpty) &&
        profile.department.isEmpty;

    return CustomScrollView(
      key: key,
      physics: physics ?? const ClampingScrollPhysics(),
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        if (isWorkEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40.h),
                child: Text(
                  'No work information available',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFFA49D95)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.only(top: 0.h, bottom: 24.h),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                ProfileContactCard(
                  items: [
                    ProfileContactCardItem(
                      label: AppLocalizations.of(context)?.mail ?? 'Mail',
                      value: emailVal,
                      rawValue: rawEmail,
                    ),
                    ProfileContactCardItem(
                      label: AppLocalizations.of(context)?.phone ?? 'Phone',
                      value: phoneVal,
                      rawValue: rawPhone,
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                ProfileContactCard(
                  items: [
                    ProfileContactCardItem(
                      label: AppLocalizations.of(context)?.jobTitle ?? 'Job title',
                      value: jobTitleVal,
                      showCopy: false,
                    ),
                    ProfileContactCardItem(
                      label: AppLocalizations.of(context)?.jobPosition ?? 'Job position',
                      value: jobPosVal,
                      showCopy: false,
                    ),
                    ProfileContactCardItem(
                      label: AppLocalizations.of(context)?.manager ?? 'Manager',
                      value: managerVal,
                      showCopy: false,
                      showConnect: showConnect,
                      onConnectTap: managerEmail != null
                          ? () => _connectWithManager(
                              context,
                              managerEmail,
                              rawEmail,
                            )
                          : null,
                    ),
                    if (work?.contractStartDateDisplay != null &&
                        work!.contractStartDateDisplay!.isNotEmpty)
                      ProfileContactCardItem(
                        label: AppLocalizations.of(context)?.contractStartDate ?? 'Contract start date',
                        value: work.contractStartDateDisplay!,
                        showCopy: false,
                      ),
                  ],
                ),
                for (final account in _bankAccounts(work))
                  if ((account.bankName?.isNotEmpty ?? false) ||
                      (account.accountNumber?.isNotEmpty ?? false)) ...[
                    SizedBox(height: 16.h),
                    ProfileContactCard(
                      items: [
                        if (account.bankName?.isNotEmpty ?? false)
                          ProfileContactCardItem(
                            label: AppLocalizations.of(context)?.bankName ?? 'Bank name',
                            value: account.bankName!,
                            showCopy: false,
                          ),
                        if (account.accountNumber?.isNotEmpty ?? false)
                          ProfileContactCardItem(
                            label: AppLocalizations.of(context)?.accountNumber ?? 'Account number',
                            value: account.accountNumber!,
                          ),
                        if (account.ifscCode?.isNotEmpty ?? false)
                          ProfileContactCardItem(
                            label: AppLocalizations.of(context)?.ifscCode ?? 'IFSC code',
                            value: account.ifscCode!,
                          ),
                      ],
                    ),
                  ],
              ]),
            ),
          ),
      ],
    );
  }
}
