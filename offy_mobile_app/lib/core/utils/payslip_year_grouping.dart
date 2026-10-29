import '../../data/models/payslip_response_model.dart';

/// One year section of the payslip history.
class PayslipYearGroup {
  /// Heading text. The year as a string, or [PayslipYearGrouping.undatedLabel]
  /// for payslips the backend could not date.
  final String label;

  /// Null for the undated section, so callers can style or sink it.
  final int? year;

  final List<PayslipModel> payslips;

  const PayslipYearGroup({
    required this.label,
    required this.year,
    required this.payslips,
  });
}

abstract final class PayslipYearGrouping {
  static const String undatedLabel = 'Other Payslips';

  static List<PayslipYearGroup> group(List<PayslipModel> payslips) {
    final buckets = <String, List<PayslipModel>>{};
    final years = <String, int?>{};

    for (final payslip in payslips) {
      final year = payslip.year;
      final label = year?.toString() ?? undatedLabel;
      buckets.putIfAbsent(label, () => <PayslipModel>[]).add(payslip);
      years[label] = year;
    }

    final groups = buckets.entries
        .map(
          (entry) => PayslipYearGroup(
            label: entry.key,
            year: years[entry.key],
            payslips: entry.value,
          ),
        )
        .toList();

    final undated = groups.where((g) => g.year == null).toList();
    if (undated.isNotEmpty) {
      groups.removeWhere((g) => g.year == null);
      groups.addAll(undated);
    }
    return groups;
  }
}
