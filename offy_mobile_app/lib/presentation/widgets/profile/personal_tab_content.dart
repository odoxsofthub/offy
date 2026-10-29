import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../data/models/profile_response_model.dart';
import 'profile_contact_card.dart';
import 'personal_grid_info_card.dart';
import '../../../../l10n/app_localizations.dart';


class PersonalTabContent extends StatelessWidget {
  final ProfileModel profile;
  final ScrollPhysics? physics;

  const PersonalTabContent({super.key, required this.profile, this.physics});

  static bool _has(String? value) => value != null && value.trim().isNotEmpty;

  static void _addIfPresent(
    List<ProfileContactCardItem> list, {
    required String label,
    required String? value,
    bool showCopy = true,
    String Function(String)? transform,
    int? maxLines = 3,
  }) {
    if (value != null && value.trim().isNotEmpty) {
      list.add(
        ProfileContactCardItem(
          label: label,
          value: transform != null ? transform(value) : value,
          rawValue: value,
          showCopy: showCopy,
          maxLines: maxLines,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final personal = profile.personal;

    final rawPersonalEmail = personal?.personalEmail;
    final rawPhone = personal?.phone;
    final rawResAddress = personal?.residentialAddress;
    final rawEduLevel = personal?.educationLevel;
    final rawFieldOfStudy = personal?.fieldOfStudy;
    final rawDob = personal?.dateOfBirthDisplay ?? personal?.dateOfBirth;

    final contactItems = <ProfileContactCardItem>[];
    _addIfPresent(
      contactItems,
      label: AppLocalizations.of(context)?.personalMail ?? 'Personal mail',
      value: rawPersonalEmail,
      transform: (val) => val.toLowerCase(),
    );
    _addIfPresent(contactItems, label: AppLocalizations.of(context)?.phone ?? 'Phone', value: rawPhone);

    final addressItems = <ProfileContactCardItem>[];
    _addIfPresent(
      addressItems,
      label: AppLocalizations.of(context)?.residentialAddress ?? 'Residential address',
      value: rawResAddress,
      maxLines: null,
    );

    final educationItems = <ProfileContactCardItem>[];
    _addIfPresent(
      educationItems,
      label: AppLocalizations.of(context)?.educationLevel ?? 'Education level',
      value: rawEduLevel,
      showCopy: false,
    );
    _addIfPresent(
      educationItems,
      label: AppLocalizations.of(context)?.fieldOfStudy ?? 'Field of study',
      value: rawFieldOfStudy,
      showCopy: false,
    );

    final hasGridValues = [
      personal?.gender,
      rawDob,
      personal?.maritalStatus,
      personal?.nationality,
      personal?.birthPlace,
    ].any(_has);

    final cards = <Widget>[
      if (contactItems.isNotEmpty) ProfileContactCard(items: contactItems),
      if (hasGridValues)
        PersonalGridInfoCard(
          gender: personal?.gender ?? '',
          dob: rawDob ?? '',
          maritalStatus: personal?.maritalStatus ?? '',
          nationality: personal?.nationality ?? '',
          birthPlace: personal?.birthPlace ?? '',
        ),
      if (addressItems.isNotEmpty) ProfileContactCard(items: addressItems),
      if (educationItems.isNotEmpty) ProfileContactCard(items: educationItems),
    ];

    return CustomScrollView(
      key: key,
      physics: physics ?? const ClampingScrollPhysics(),
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        if (cards.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40.h),
                child: Text(
                  'No personal information available',
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
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) SizedBox(height: 16.h),
                  cards[i],
                ],
              ]),
            ),
          ),
      ],
    );
  }
}
