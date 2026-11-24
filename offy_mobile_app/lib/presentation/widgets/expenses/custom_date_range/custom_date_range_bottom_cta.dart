import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../common/filter/app_filter_action_bar.dart';

class CustomDateRangeBottomCta extends StatelessWidget {
  final VoidCallback onReset;
  final VoidCallback onConfirm;

  const CustomDateRangeBottomCta({
    super.key,
    required this.onReset,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AppFilterActionBar(
      onReset: onReset,
      onPrimary: onConfirm,
      primaryLabel:
          AppLocalizations.of(context)?.confirmRange ?? 'Confirm Range',
    );
  }
}
