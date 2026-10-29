import 'package:flutter_test/flutter_test.dart';
import 'package:office_app/core/utils/payslip_year_grouping.dart';
import 'package:office_app/data/models/payslip_response_model.dart';

void main() {
  PayslipModel slip({
    required int id,
    int? year,
    String dateTo = '',
    String dateFrom = '',
    String distributedDate = '',
  }) {
    return PayslipModel.fromJson({
      'id': id,
      'period': 'Payslip $id',
      'year': ?year,
      'date_to': dateTo,
      'date_from': dateFrom,
      'distributed_date': distributedDate,
      'net_pay': 100.0,
      'state': 'paid',
    });
  }

  group('PayslipModel.year', () {
    test('uses the value the server sent', () {
      expect(slip(id: 1, year: 2025, dateTo: '2025-12-31').year, 2025);
    });

    test('a December payslip paid in January stays in December\'s year', () {
      final december = slip(
        id: 1,
        year: 2025,
        dateTo: '2025-12-31',
        distributedDate: '2026-01-05',
      );
      expect(december.year, 2025);
      expect(december.distributedDate, '2026-01-05');
    });

    test('falls back to date_to when the backend predates the field', () {
      expect(slip(id: 1, dateTo: '2024-06-30').year, 2024);
    });

    test('falls back to date_from when date_to is absent', () {
      expect(slip(id: 1, dateFrom: '2023-07-01').year, 2023);
    });

    test('the fallback ignores distributed_date', () {
      final payslip = slip(
        id: 1,
        dateTo: '2025-12-31',
        distributedDate: '2026-01-05',
      );
      expect(payslip.year, 2025);
    });

    test('is null when nothing can be derived', () {
      expect(slip(id: 1).year, isNull);
    });

    test('survives an unparseable date rather than throwing', () {
      expect(slip(id: 1, dateTo: 'not-a-date', dateFrom: '2022-01-01').year,
          2022);
    });
  });

  group('PayslipYearGrouping.group', () {
    test('splits into one section per year', () {
      final groups = PayslipYearGrouping.group([
        slip(id: 3, year: 2026, dateTo: '2026-03-31'),
        slip(id: 2, year: 2025, dateTo: '2025-12-31'),
        slip(id: 1, year: 2025, dateTo: '2025-11-30'),
      ]);

      expect(groups.map((g) => g.label).toList(), ['2026', '2025']);
      expect(groups[0].payslips.length, 1);
      expect(groups[1].payslips.length, 2);
    });

    test('preserves the order the API returned', () {
      final groups = PayslipYearGrouping.group([
        slip(id: 3, year: 2026, dateTo: '2026-03-31'),
        slip(id: 2, year: 2025, dateTo: '2025-12-31'),
        slip(id: 1, year: 2024, dateTo: '2024-12-31'),
      ]);

      expect(groups.map((g) => g.year).toList(), [2026, 2025, 2024]);
      expect(groups[1].payslips.single.id, 2);
    });

    test('a year never reappears once its run has closed', () {
      final groups = PayslipYearGrouping.group([
        slip(id: 4, year: 2026, dateTo: '2026-02-28'),
        slip(id: 3, year: 2025, dateTo: '2025-12-31'),
        slip(id: 2, year: 2025, dateTo: '2025-01-31'),
        slip(id: 1, year: 2024, dateTo: '2024-12-31'),
      ]);

      final labels = groups.map((g) => g.label).toList();
      expect(labels.toSet().length, labels.length);
    });

    test('keeps undated payslips instead of dropping them', () {
      final groups = PayslipYearGrouping.group([
        slip(id: 2, year: 2025, dateTo: '2025-12-31'),
        slip(id: 1),
      ]);

      final all = groups.expand((g) => g.payslips).map((p) => p.id).toList();
      expect(all, containsAll(<int>[1, 2]));
      expect(groups.last.label, PayslipYearGrouping.undatedLabel);
      expect(groups.last.year, isNull);
    });

    test('the undated section sinks below every real year', () {
      final groups = PayslipYearGrouping.group([
        slip(id: 1),
        slip(id: 2, year: 2025, dateTo: '2025-12-31'),
      ]);

      expect(groups.first.label, '2025');
      expect(groups.last.label, PayslipYearGrouping.undatedLabel);
    });

    test('an empty history produces no sections', () {
      expect(PayslipYearGrouping.group(const []), isEmpty);
    });

    test('every payslip lands in exactly one section', () {
      final payslips = [
        slip(id: 3, year: 2026, dateTo: '2026-01-31'),
        slip(id: 2, year: 2025, dateTo: '2025-06-30'),
        slip(id: 1),
      ];
      final grouped = PayslipYearGrouping.group(payslips)
          .expand((g) => g.payslips)
          .toList();

      expect(grouped.length, payslips.length);
      expect(grouped.map((p) => p.id).toSet(), {1, 2, 3});
    });
  });
}
